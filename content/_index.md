---
title: Agentica
description: Agentica is Ruby with static types. Ruby-like syntax, checked before running, with immutable values.
search: false
---

# Agentica: Ruby with static types

Agentica is a statically typed programming language with Ruby-like syntax. Every program is checked before it runs, and values never change in place. Tasks run in parallel on several cores, and it comes with HTTP, TLS and WebSockets, packages and C native modules, all in one binary, `agentica`.

```agentica
struct Book
  title: String
  pages: Int
end

def long?(book: Book) -> Bool = book.pages > 300

def main() -> Void
  books = [Book(title: "Dune", pages: 412), Book(title: "Emma", pages: 192)]
  books.each do |book|
    if long?(book)
      puts("#{book.title} is long")
    else
      puts("#{book.title} is short")
    end
  end

  total = books.map { |book| book.pages }.sum
  puts("#{total} pages in all")
end
```

Run it with `agentica books.agc`:

```output
Dune is long
Emma is short
604 pages in all
```

Write `pages: "412"` instead, and the program does not run:

```text
books.agc:9:39 error[CHECK-TYPE-MISMATCH]
expected Int, found String
```

## Why Agentica

- **Checked before it runs.** A wrong type is an error with a stable code and a source position, often with a hint, before the program starts.
- **Values never change in place.** A function cannot change the list or the struct you pass it.
- **Small on purpose.** There are few rules, so people and AI agents can write, read and fix programs with few surprises.
- **One binary.** `agentica` runs, checks, formats and tests programs, has HTTP, TLS, WebSockets and packages built in, and needs no other library.
- **Tasks on several cores.** How fast is it? See [a Campfire port measured against Go](/blog/campfire-faster-than-go/).

## Install

On Linux x86-64:

```sh
curl -fsSLO https://github.com/agentica-lang/agentica/releases/download/0.34.0/agentica-0.34.0-linux-x86_64.tar.gz
curl -fsSLO https://github.com/agentica-lang/agentica/releases/download/0.34.0/SHA256SUMS
sha256sum -c --ignore-missing SHA256SUMS
tar -xzf agentica-0.34.0-linux-x86_64.tar.gz
export PATH="$PWD/agentica-0.34.0-linux-x86_64/bin:$PATH"
agentica --version
```

Each release has an archive per system (Linux and macOS on x86-64 and arm64, Windows on x86-64), with `bin/agentica` inside. The [getting started guide](https://www.agentica-lang.com/agentica/getting-started/) lists the archives, has a prompt that installs Agentica with your coding agent, and runs your first program.

## Projects

- [Documentation](https://www.agentica-lang.com/agentica/): the language tour, the command line and the specification.
- [Library](https://www.agentica-lang.com/agentica/library/): every builtin module, with one example per function.
- [Bond](https://www.agentica-lang.com/bond/): a web framework for Agentica.
- [agentica-db](https://www.agentica-lang.com/agentica-db/): one API for PostgreSQL, SQLite and MySQL.
- [agentica-tui](https://www.agentica-lang.com/agentica-tui/): terminal UIs with a typed view tree and an Elm-like loop.
- [Packages](https://www.agentica-lang.com/packages/): packages you can add to a project.
- [Finn](https://www.agentica-lang.com/agc-agent/): a coding agent for the terminal, written in Agentica.
- [cchecker](https://www.agentica-lang.com/cchecker/): checks C code for the rules of a project.
- [Ecosystem](https://www.agentica-lang.com/ecosystem/): every framework, library and editor tool around Agentica.
- [GitHub](https://github.com/agentica-lang): the source of the language and every project.
