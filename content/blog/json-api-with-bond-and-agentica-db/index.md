---
title: Build a JSON API in Agentica with Bond and agentica-db
description: Build a todo list JSON API in Agentica with Bond and agentica-db on SQLite, with routes, an API key filter, validation, curl calls and a test.
date: 2026-11-16
draft: false
cover_alt: "A todo list sends GET /todos to an Agentica JSON API backed by SQLite"
build:
  publishResources: false
tags: [tutorial, bond, agentica-db, web]
---

This tutorial builds a small JSON API in [Agentica](https://www.agentica-lang.com/agentica/), from an empty folder to a server that you can call with `curl`. The API manages a todo list: list, get, create, update and delete. It uses [Bond](https://www.agentica-lang.com/bond/), a small web framework, and [agentica-db](https://www.agentica-lang.com/agentica-db/), a database package, with SQLite.

You will see JSON in and out, routes with path params, a filter that checks an API key, validation that answers `422`, and a test. The whole program is one file of about 110 lines. The code comes in pieces, in the order of the file, so pasting the pieces one after another gives the file. The last section has it in one block, ready to copy and run.

Everything here ran on Agentica 0.33.0, Bond 0.14.0 and agentica-db 0.13.0. You need Agentica on your `PATH`, the `libsqlite3` library (the package `libsqlite3-0` on Debian and Ubuntu) and a C compiler. The compiler builds the native SQLite driver the first time the program runs. Without one, agentica-db prints a warning and uses a slower driver.

## 1. The project

Make a folder with an `agentica.toml`. The manifest has the name of the project and one style setting, which asks for a blank line after each `end`, as in the code below.

```sh
mkdir todos && cd todos
```

```toml
name = "todos"

[style]
blank_line_after_end = true
```

Add the two packages. Each command writes the dependency in `agentica.toml`, writes `agentica.lock`, and puts the files in `deps/`:

```sh
agentica add bond https://github.com/agentica-lang/bond --tag 0.14.0
agentica add db https://github.com/agentica-lang/agentica-db --tag 0.13.0
```

```text
added bond@0.14.0
added db@0.13.0
added pool@pool-0.1.3 (folder pool)
```

The third line is a package that agentica-db needs for its connection pool. Now the manifest has the dependencies:

```toml
name = "todos"

[style]
blank_line_after_end = true

[dependencies]
bond = { git = "https://github.com/agentica-lang/bond", tag = "0.14.0" }
db = { git = "https://github.com/agentica-lang/agentica-db", tag = "0.13.0" }
```

If you write the dependencies by hand instead, run `agentica update` to write `agentica.lock` and fetch the files. `agentica install` puts the files of an existing lock in `deps/`, for example on a fresh checkout.

## 2. Imports and constants

Put the program in a file called `todos.agc`. It starts with the imports and three constants:

```agentica
import Bond from "pkg/bond/bond"
import Db from "pkg/db/db"
import DbPool from "pkg/db/db_pool"
import Orm from "pkg/db/orm"
import Sqlite from "pkg/db/sqlite"

API_KEY = "secret"
MAX_TITLE = 80
CREATE_TODOS = (
  "create table if not exists todos " +
  "(id integer primary key, title text not null, done integer not null default 0)"
)
```

`pkg/bond/bond` is Bond. `pkg/db/db`, `pkg/db/db_pool`, `pkg/db/orm` and `pkg/db/sqlite` are four modules of agentica-db: `Db` runs SQL, `DbPool` shares connections, `Orm` reads rows into structs, and `Sqlite` is the driver.

## 3. The struct and JSON

```agentica
struct Todo
  id: Int = 0
  title: String
  done: Bool = false
end

def todos() -> Orm.Schema[Todo] = Orm.schema("todos", Todo.codec)
```

A `struct` is a record with typed fields. Every struct has a `.codec` that turns it into JSON and back. The same struct is the row of the table: `Orm.schema("todos", Todo.codec)` ties it to the `todos` table, with the columns named like the fields.

`id` and `done` have defaults, so a client can send `{"title": "buy milk"}` and the database gives the `id`.

## 4. The database

```agentica
def open_pool(url: String) -> Result[DbPool.Pool]
  pool = try DbPool.start(DbPool.Options(url: url, drivers: [Sqlite.driver()]))
  try DbPool.with(pool) do |db| Db.execute(db, CREATE_TODOS, []) end

  ok(pool)
end
```

This opens the database and makes the table. Why a pool? Bond runs each request in its own task, and a database connection belongs to the task that opened it. `DbPool.start` opens connections in tasks of its own, and `DbPool.with` lends one to a block of code. The handlers below get the pool and borrow a connection for each request.

`Db.execute` takes the connection, the SQL and a list of parameters. Each call returns a `Result`, and `try` passes an error up to the caller. `create table if not exists` lets the server start again on an existing file.

## 5. The routes

```agentica
def build(pool: DbPool.Pool) -> Bond.App
  (
    Bond.app()
    |> Bond.before(&Bond.log_request)
    |> Bond.before(&require_key)
    |> Bond.get("/todos", ->(conn) { list(pool, conn) })
    |> Bond.get("/todos/:id", ->(conn) { show(pool, conn) })
    |> Bond.post("/todos", ->(conn) { create(pool, conn) })
    |> Bond.put("/todos/:id", ->(conn) { update(pool, conn) })
    |> Bond.delete("/todos/:id", ->(conn) { remove(pool, conn) })
  )
end

def main() -> Void
  pool = open_pool("sqlite:todos.db").unwrap!
  Bond.run(build(pool), "127.0.0.1", 4567).unwrap!
end
```

Each `Bond.get`, `Bond.post`, `Bond.put` and `Bond.delete` takes the app, a path pattern and a handler, and returns a new app. The `|>` pipe passes the app to each call, so the routes read as one list. A segment that starts with a colon, such as `:id`, matches one segment of the path.

A handler is a function from a `Bond.Conn`, which holds the request and the answer, to `Result[Bond.Conn]`. The app does not hold your state, so each route is a small lambda, `->(conn) { list(pool, conn) }`, that has the pool in reach. A function that needs only the `conn` is passed by name, as `&require_key` is. `Bond.before` adds a filter, which is explained in step 6.

`Bond.run` starts the server and returns when it closes. `open_pool` and `Bond.run` both return a `Result`. In `main` they use `unwrap!`, which stops the program with the error if the database cannot be opened or the port is taken.

The handlers are defined below. `build`, `open_pool` and `main` come first because they are the public part of the file: the test in step 10 imports `build` and `open_pool`.

## 6. A filter: the API key

On its own line, `private` ends the public part: the functions after it are used only in this file. The first two are the filter and a helper for errors.

```agentica
private

def require_key(conn: Bond.Conn) -> Result[Bond.Conn]
  return ok(conn) if Bond.request_header(conn, "x-api-key").unwrap_or("") == API_KEY

  ok(failure(conn, 401, "missing or wrong X-Api-Key"))
end

def failure(conn: Bond.Conn, status: Int, message: String) -> Bond.Conn
  Bond.json(conn, status, JSON.from({"error": message})).with(halted: true)
end
```

A filter is a handler that runs before (or after) the route, and filters run in the order they were added. `build` adds two: `Bond.log_request`, which Bond provides and which writes `METHOD /path` of each request to the server's stderr, and our own `require_key`.

`require_key` reads the `x-api-key` header. If it is right, the filter returns the `conn` unchanged and the request goes on. If not, it answers `401`, and `halted: true` tells Bond to stop: the route does not run.

`failure` is the helper for the errors of our code, which are JSON in the form `{"error": "..."}`. The errors that Bond answers by itself are plain text: a `404` for a path with no route, a `405` for a wrong method, and a `400` for a body that is not valid. `Bond.not_found` and `Bond.on_error` change the `404` and the `500` if you want JSON there too.

The key is a constant here to keep the example short. A real service reads it from the environment.

## 7. Reading todos

```agentica
def list(pool: DbPool.Pool, conn: Bond.Conn) -> Result[Bond.Conn]
  rows = try DbPool.with(pool) do |db| Orm.query(db, todos(), "select id, title, done from todos order by id", []) end
  ok(Bond.json(conn, 200, JSON.from(rows)))
end

def show(pool: DbPool.Pool, conn: Bond.Conn) -> Result[Bond.Conn]
  id = try Bond.param_int(conn, "id")
  found = try DbPool.with(pool) do |db| Orm.find(db, todos(), Db.Value.Int(id)) end
  case found
    some(todo) -> ok(Bond.json_as(conn, 200, Todo.codec, todo))
    none -> ok(failure(conn, 404, "no todo #{id}"))
  end
end
```

`Orm.query` runs a select and reads each row into a `Todo`. `Bond.json` answers with a `JSON.Value`, and `JSON.from` makes one from the list.

`Bond.param_int(conn, "id")` reads the `:id` of the route as an `Int`. A text that is not a number is a `400`. `Orm.find` returns an `Optional`: `some(todo)` or `none`. A `case` handles both, and a missing todo is a `404` with a JSON error. `Bond.json_as` encodes a struct with its codec.

If the database fails, the `try` passes the error up, and Bond answers a plain `500` with the text `Internal Server Error`. The message goes to the server's stderr, never to the client.

## 8. Creating, updating, deleting and validating

```agentica
def create(pool: DbPool.Pool, conn: Bond.Conn) -> Result[Bond.Conn]
  input = try Bond.json_body(conn, Todo.codec)
  case valid(input)
    error(e) -> ok(failure(conn, 422, e.message))
    ok(todo) ->
      saved = try DbPool.with(pool) do |db| Orm.insert(db, todos(), todo) end
      ok(Bond.json_as(conn, 201, Todo.codec, saved))
  end
end

def update(pool: DbPool.Pool, conn: Bond.Conn) -> Result[Bond.Conn]
  id = try Bond.param_int(conn, "id")
  input = try Bond.json_body(conn, Todo.codec)
  case valid(input)
    error(e) -> ok(failure(conn, 422, e.message))
    ok(checked) ->
      todo = checked.with(id: id)
      changed = try DbPool.with(pool) do |db| Orm.update(db, todos(), todo) end
      return ok(failure(conn, 404, "no todo #{id}")) if changed == 0

      ok(Bond.json_as(conn, 200, Todo.codec, todo))
  end
end

def remove(pool: DbPool.Pool, conn: Bond.Conn) -> Result[Bond.Conn]
  id = try Bond.param_int(conn, "id")
  removed = try DbPool.with(pool) do |db| Orm.delete(db, todos(), Db.Value.Int(id)) end
  return ok(failure(conn, 404, "no todo #{id}")) if removed == 0

  ok(Bond.text(conn, 204, ""))
end
```

`Bond.json_body(conn, Todo.codec)` decodes the body into a `Todo`. If the body is not JSON, does not fit the struct, or comes without the header `content-type: application/json`, the `try` makes the request a `400` with a message, and the handler needs no more code. `Orm.insert` writes the row and returns it with its new `id`, and the handler answers `201`.

`update` takes the `id` from the path, not from the body: `checked.with(id: id)` makes a copy of the todo with that id. Structs never change, so `with` always makes a new value. `Orm.update` returns how many rows it changed, and `0` means no such todo, a `404`. `Orm.delete` returns the number of removed rows too, and on success the answer is `204` with no body.

The last piece is the validation that `create` and `update` call:

```agentica
def valid(todo: Todo) -> Result[Todo]
  title = todo.title.strip
  return error("title must not be empty") if title.empty?
  return error("title must have at most #{MAX_TITLE} characters") if title.size > MAX_TITLE

  ok(todo.with(title: title))
end
```

`valid` returns a `Result[Todo]`: the todo with its title trimmed, or an error with a message. A `case` in `create` and `update` turns an error into a `422`, and the message goes into the JSON.

Two kinds of mistakes have two statuses. A body that is not JSON, or has no `title`, is a `400`: Bond refuses it before your code runs. A body that fits the struct but breaks a rule of yours, such as a blank title or one over 80 characters, is a `422`.

## 9. Run it

Start the server. The first run builds the SQLite driver, so it takes a few seconds. It creates `todos.db` in the folder.

```sh
agentica todos.agc
```

In another terminal, define a small function so each call is short. It sends the API key and the JSON header, and prints the status after the body:

```sh
api() { curl -s -w ' [%{http_code}]\n' -H 'x-api-key: secret' -H 'content-type: application/json' "$@"; }
```

These are the calls and what the server answered:

```text
$ curl -s -w ' [%{http_code}]\n' http://127.0.0.1:4567/todos
{"error":"missing or wrong X-Api-Key"} [401]
$ api http://127.0.0.1:4567/todos
[] [200]
$ api -d '{"title": "buy milk"}' http://127.0.0.1:4567/todos
{"id":1,"title":"buy milk","done":false} [201]
$ api -d '{"title": "write a post", "done": true}' http://127.0.0.1:4567/todos
{"id":2,"title":"write a post","done":true} [201]
$ api http://127.0.0.1:4567/todos
[{"done":false,"id":1,"title":"buy milk"},{"done":true,"id":2,"title":"write a post"}] [200]
$ api http://127.0.0.1:4567/todos/1
{"id":1,"title":"buy milk","done":false} [200]
$ api http://127.0.0.1:4567/todos/99
{"error":"no todo 99"} [404]
$ api -X PUT -d '{"title": "buy oat milk", "done": true}' http://127.0.0.1:4567/todos/1
{"id":1,"title":"buy oat milk","done":true} [200]
$ api -d '{"title": "   "}' http://127.0.0.1:4567/todos
{"error":"title must not be empty"} [422]
$ api -d '{"done": true}' http://127.0.0.1:4567/todos
invalid body: title: expected required field [400]
$ api -X DELETE http://127.0.0.1:4567/todos/2
 [204]
$ api -X DELETE http://127.0.0.1:4567/todos/2
{"error":"no todo 2"} [404]
$ api http://127.0.0.1:4567/todos
[{"done":true,"id":1,"title":"buy oat milk"}] [200]
```

The first call has no key, so the filter answers `401`. A new todo is `201` with its `id`. The `GET` of a todo that does not exist is a `404`, and so is the second `DELETE` of the same id. A blank title is a `422` with our message, and a body with no `title` at all is a `400` from Bond. The server's terminal shows one line per request, such as `GET /todos/99`, from the log filter.

In the list, the keys are in alphabetical order. A JSON object has no order, and `JSON.from` writes them sorted, while `Bond.json_as` keeps the order of the struct.

## 10. A test (optional)

You can stop here. If you want a test, put this in `test/todos_test.agc`. It is a second file, and `agentica test` finds it in the `test/` folder.

```agentica
import Todos from "../todos"
import Bond from "pkg/bond/bond"
import Testing from "pkg/bond/testing"
import DbPool from "pkg/db/db_pool"
import HTTP from "std/http"

MILK = "{\"id\":1,\"title\":\"buy milk\",\"done\":false}"

def with_app(body: Fn[Bond.App, Result[Void]]) -> Result[Void]
  pool = try Todos.open_pool("sqlite::memory:")
  result = body.call(Todos.build(pool))
  DbPool.close(pool, 1000)
  result
end

def call(app: Bond.App, method: String, path: String, body: String = "") -> Result[String]
  headers = [
    HTTP.Header(name: "x-api-key", value: "secret"),
    HTTP.Header(name: "content-type", value: "application/json"),
  ]

  response = Testing.request(app, method, path, headers, body)
  text = try Testing.text(response)
  ok("#{response.status} #{text}")
end

def test_creates_and_reads_a_todo() -> Result[Void]
  with_app do |app|
    try Test.eq(call(app, "POST", "/todos", "{\"title\": \"buy milk\"}"), ok("201 #{MILK}"))
    Test.eq(call(app, "GET", "/todos/1"), ok("200 #{MILK}"))
  end
end

def test_refuses_an_empty_title() -> Result[Void]
  with_app do |app|
    Test.eq(call(app, "POST", "/todos", "{\"title\": \" \"}"), ok("422 {\"error\":\"title must not be empty\"}"))
  end
end
```

`Testing.request` runs the app in the same process, through the same filters and routes as the server, with no socket. The test imports `build` and `open_pool` from `../todos`, and gives the app a pool on `sqlite::memory:`: a private database that lives as long as the pool, so each test starts with an empty table. `with_app` opens the pool, runs the test body and closes the pool. Without the close, `agentica test` reports tasks that are still running.

A function named `test_...` in a `*_test.agc` file is a test. `Test.eq` compares two values and returns a `Result`, so the last one is the result of the test. The first test creates a todo and reads it back. The second checks the `422`.

```sh
agentica test
```

```text
PASS test/todos_test.agc / creates and reads a todo
PASS test/todos_test.agc / refuses an empty title
2 passed, 0 failed, 0 skipped, 0 not executed, 0 file errors
```

The project also passes `agentica check`, `agentica lint` and `agentica fmt --check`.

## The whole file

This is `todos.agc` in one piece. Save it, run `agentica todos.agc`, and call it with the `curl` commands above.

```agentica
import Bond from "pkg/bond/bond"
import Db from "pkg/db/db"
import DbPool from "pkg/db/db_pool"
import Orm from "pkg/db/orm"
import Sqlite from "pkg/db/sqlite"

API_KEY = "secret"
MAX_TITLE = 80
CREATE_TODOS = (
  "create table if not exists todos " +
  "(id integer primary key, title text not null, done integer not null default 0)"
)

struct Todo
  id: Int = 0
  title: String
  done: Bool = false
end

def todos() -> Orm.Schema[Todo] = Orm.schema("todos", Todo.codec)

def open_pool(url: String) -> Result[DbPool.Pool]
  pool = try DbPool.start(DbPool.Options(url: url, drivers: [Sqlite.driver()]))
  try DbPool.with(pool) do |db| Db.execute(db, CREATE_TODOS, []) end

  ok(pool)
end

def build(pool: DbPool.Pool) -> Bond.App
  (
    Bond.app()
    |> Bond.before(&Bond.log_request)
    |> Bond.before(&require_key)
    |> Bond.get("/todos", ->(conn) { list(pool, conn) })
    |> Bond.get("/todos/:id", ->(conn) { show(pool, conn) })
    |> Bond.post("/todos", ->(conn) { create(pool, conn) })
    |> Bond.put("/todos/:id", ->(conn) { update(pool, conn) })
    |> Bond.delete("/todos/:id", ->(conn) { remove(pool, conn) })
  )
end

def main() -> Void
  pool = open_pool("sqlite:todos.db").unwrap!
  Bond.run(build(pool), "127.0.0.1", 4567).unwrap!
end

private

def require_key(conn: Bond.Conn) -> Result[Bond.Conn]
  return ok(conn) if Bond.request_header(conn, "x-api-key").unwrap_or("") == API_KEY

  ok(failure(conn, 401, "missing or wrong X-Api-Key"))
end

def failure(conn: Bond.Conn, status: Int, message: String) -> Bond.Conn
  Bond.json(conn, status, JSON.from({"error": message})).with(halted: true)
end

def list(pool: DbPool.Pool, conn: Bond.Conn) -> Result[Bond.Conn]
  rows = try DbPool.with(pool) do |db| Orm.query(db, todos(), "select id, title, done from todos order by id", []) end
  ok(Bond.json(conn, 200, JSON.from(rows)))
end

def show(pool: DbPool.Pool, conn: Bond.Conn) -> Result[Bond.Conn]
  id = try Bond.param_int(conn, "id")
  found = try DbPool.with(pool) do |db| Orm.find(db, todos(), Db.Value.Int(id)) end
  case found
    some(todo) -> ok(Bond.json_as(conn, 200, Todo.codec, todo))
    none -> ok(failure(conn, 404, "no todo #{id}"))
  end
end

def create(pool: DbPool.Pool, conn: Bond.Conn) -> Result[Bond.Conn]
  input = try Bond.json_body(conn, Todo.codec)
  case valid(input)
    error(e) -> ok(failure(conn, 422, e.message))
    ok(todo) ->
      saved = try DbPool.with(pool) do |db| Orm.insert(db, todos(), todo) end
      ok(Bond.json_as(conn, 201, Todo.codec, saved))
  end
end

def update(pool: DbPool.Pool, conn: Bond.Conn) -> Result[Bond.Conn]
  id = try Bond.param_int(conn, "id")
  input = try Bond.json_body(conn, Todo.codec)
  case valid(input)
    error(e) -> ok(failure(conn, 422, e.message))
    ok(checked) ->
      todo = checked.with(id: id)
      changed = try DbPool.with(pool) do |db| Orm.update(db, todos(), todo) end
      return ok(failure(conn, 404, "no todo #{id}")) if changed == 0

      ok(Bond.json_as(conn, 200, Todo.codec, todo))
  end
end

def remove(pool: DbPool.Pool, conn: Bond.Conn) -> Result[Bond.Conn]
  id = try Bond.param_int(conn, "id")
  removed = try DbPool.with(pool) do |db| Orm.delete(db, todos(), Db.Value.Int(id)) end
  return ok(failure(conn, 404, "no todo #{id}")) if removed == 0

  ok(Bond.text(conn, 204, ""))
end

def valid(todo: Todo) -> Result[Todo]
  title = todo.title.strip
  return error("title must not be empty") if title.empty?
  return error("title must have at most #{MAX_TITLE} characters") if title.size > MAX_TITLE

  ok(todo.with(title: title))
end
```

## Where to go next

- Bond has more than this post used: cookies, signed sessions, forms and uploads, static files, streaming and WebSockets. Read the [Bond docs](https://www.agentica-lang.com/bond/).
- agentica-db has a query builder, transactions, migrations, and PostgreSQL and MySQL drivers next to SQLite. Read the [agentica-db docs](https://www.agentica-lang.com/agentica-db/).
- The [language docs](https://www.agentica-lang.com/agentica/) explain the syntax, types, `Result` and `case` used here.
- The [Ecosystem page](https://www.agentica-lang.com/ecosystem/) lists the packages and projects around Agentica.
