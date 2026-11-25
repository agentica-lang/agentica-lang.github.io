---
title: Agentica 0.39.0
description: Agentica 0.39.0 adds Terminal (tty?, raw mode, size and resize events), Term.encode and Term.decode for CBOR, agentica refs on imports and re-exports, and the LINT-NESTED-WRAPPER suggestion.
date: 2026-11-25T19:43:40Z
draft: false
tags: [release]
---

Agentica 0.39.0 is out. There are two breaking changes, both reserved type names: they are listed [below](#breaking-changes). This post lists what changed; the full list is in the [changelog](https://github.com/agentica-lang/agentica/blob/0.39.0/CHANGELOG.md).

## What is new

### Terminal

A full-screen program, such as an editor, needs a few things from the terminal. `Terminal` gives them, the same on Linux, macOS and Windows 10 or later:

- `Terminal.tty?(stream)` tells if `Terminal.Stream.Stdin`, `Stdout` or `Stderr` is a terminal.
- `Terminal.raw` puts the terminal of standard input in raw mode: what is typed is not shown, and each key comes at once, with no wait for Enter. Ctrl-C comes as the byte 3. `Terminal.raw(on: false)` gives back the old mode, and the VM also gives it back when the program ends, even after a runtime error.
- `Terminal.size` gives the rows and columns.
- `System.Signal.Winch` is the resize event. Subscribe to it with `System.subscribe`, and read the new size when a value comes.

Keys are still read with `IO.read_bytes` on standard input, as bytes. This program waits for keys, so it needs a real terminal. Here it only runs through `agentica check`, which prints `check ok`:

```agentica
def main() -> Void
  Terminal.raw().unwrap!
  resized = System.subscribe([System.Signal.Winch]).unwrap!
  size = Terminal.size().unwrap!
  puts("#{size.rows}x#{size.cols}, q quits")
  IO.flush()
  while true
    if resized.recv(0).ok?
      size = Terminal.size().unwrap!
      puts("resized to #{size.rows}x#{size.cols}")
      IO.flush()
    end

    key = IO.read_bytes(1).unwrap!
    break if key.empty? or key.to_a == [113]
  end

  Terminal.raw(on: false).unwrap!
end
```

It turns on raw mode, prints the size, and then reads one key at a time. When the window changes size it prints the new size after the next key. It stops on `q` and restores the terminal.

When the streams are not terminals, the calls return an error of kind `io.failed` instead of stopping. Here the output goes to a pipe:

```agentica
def main() -> Void
  puts(Terminal.tty?(Terminal.Stream.Stdout))
  case Terminal.size()
    ok(size) -> puts("#{size.rows}x#{size.cols}")
    error(e) -> puts(e.kind)
  end
  case Terminal.raw()
    ok(_) -> puts("raw")
    error(e) -> puts(e.kind)
  end
end
```

```output
false
io.failed
io.failed
```

On Windows, `Winch` is the one signal a program can subscribe to, and it is seen within about a quarter second. See [Terminal](https://www.agentica-lang.com/agentica/library/io-and-system/terminal/).

### Term: CBOR

`Term.encode(value)` writes a value as [CBOR](https://www.rfc-editor.org/rfc/rfc8949) bytes, and `Term.decode(bytes, Type)` reads them back into a struct or an enum. CBOR keeps what JSON bends: a `Map` with `Int` keys, the exact bits of a `Float`, `nil` and `Bytes`. The bytes are deterministic, so the same value gives the same bytes. The type you name is the schema, so nothing outside it is ever built.

```agentica
struct Entry
  version: Int
  hits: Map[Int, Int]
  score: Float
end

enum Shape
  Circle(Float)
  Empty
end

def main() -> Void
  entry = Entry(version: 1, hits: {2: 5, 1: 7}, score: 1.5)
  bytes = Term.encode(entry).unwrap!
  puts(OpenSSL.Digest.hexencode(bytes))
  puts(Term.decode(bytes, Entry).unwrap!.hits)

  shape = Term.encode(Shape.Circle(1.5)).unwrap!
  puts(Term.decode(shape, Shape).unwrap!)

  case Term.decode(shape, Entry)
    ok(_) -> puts("ok")
    error(e) -> puts(e.message)
  end
end
```

```output
a36776657273696f6e016468697473a2020501076573636f7265fb3ff8000000000000
{2: 5, 1: 7}
Shape.Circle(1.5)
$: expected struct Entry
```

The last line is the error of a wrong type: its message starts with the path of the first bad value, here the root `$`. Both functions have limits (10,000 levels, 4,000,000 values and 64 MiB), and a value past one returns an error. The bytes carry no version, so put a `version` field in the top struct from the start.

See [Term (CBOR)](https://www.agentica-lang.com/agentica/library/text-and-data/term/).

### agentica refs on imports and re-exports

`agentica refs` lists every use of a name. Now it also lists the name in an import list (kind `import`) and in a re-export (kind `export`), so a rename reaches them. With these three files:

```agentica
# models.agc
struct User
  name: String
end

def make(name: String) -> User = User(name: name)
```

```agentica
# facade.agc
import Models from "./models"

export Models.make
```

```agentica
# main.agc
import {make} from "./models"
import Facade from "./facade"

def main() -> Void
  puts(make("Ana").name)
  puts(Facade.make("Ben").name)
end
```

`agentica refs make .` prints:

```output
models.agc:5:5 definition function make(name: String) -> User
facade.agc:3:15 export
main.agc:1:9 import
main.agc:5:8 call in main
main.agc:6:15 call in main
```

See [Find references](https://www.agentica-lang.com/agentica/cli/#find-references).

### LINT-NESTED-WRAPPER

`agentica lint` now suggests one layer when a signature, a field or an alias has a `Result[Result[T]]` or an `Optional[Optional[T]]`:

```agentica
struct User
  name: String
end

def lookup(id: Int) -> Result[Result[User]]
  ok(ok(User(name: "Ana")))
end

def main() -> Void
  puts(lookup(1).ok?)
end
```

```output
wrap2.agc:5:24 LINT-NESTED-WRAPPER this type is a Result of a Result
  help: flatten it with `try` on the inner value so one Result is left, or give the inner failure an error of its own; keep both layers when the outer error and the inner error mean different things
lint: 1 suggestion in 1 of 1 file
```

A lint suggestion is not an error: the exit code is 0.

## Breaking changes

- **Reserved type names.** `Term` and `Terminal` are reserved. A program that used one of them as the name of its own struct, enum or alias has to rename it.

## Also

- `agentica --json compile` writes an unreadable file or folder, and a folder with no `main.agc`, as a JSON diagnostic. With no FILE, one unreadable folder no longer stops the others.
- `agentica --json check` of an unreadable file writes a `QUERY-USAGE` JSON diagnostic, as `compile` does:

```output
{"code":"QUERY-USAGE","message":"cannot read nope.agc","file":"nope.agc","range":{"start":{"line":1,"column":1},"end":{"line":1,"column":1}}}
```

To install or upgrade, see [getting started](https://www.agentica-lang.com/agentica/getting-started/). The archives for Linux, macOS and Windows are on the [0.39.0 release page](https://github.com/agentica-lang/agentica/releases/tag/0.39.0).
