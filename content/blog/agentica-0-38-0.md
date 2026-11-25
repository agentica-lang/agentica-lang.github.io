---
title: Agentica 0.38.0
description: Agentica 0.38.0 adds sized integers, UInt64 and Float32, safe navigation (&.), Task.spawn_link, BDD feature hooks and version requirements for packages.
date: 2026-11-25T08:14:27Z
draft: false
tags: [release]
---

Agentica 0.38.0 is out. There are breaking changes, all from the new number types: they are listed [below](#breaking-changes). This post lists what changed; the full list is in the [changelog](https://github.com/agentica-lang/agentica/blob/0.38.0/CHANGELOG.md).

## What is new

### Sized integers, UInt64 and Float32

Agentica has more number types now: `Int8`, `Int16`, `Int32`, `UInt8`, `UInt16`, `UInt32`, `UInt64` and `Float32`. `Int64` is another name of `Int`, and `Float64` of `Float`.

An integer literal takes the type of its place: an annotation, a parameter, a struct field or a return type. A literal outside the range is `CHECK-INT-RANGE`. A value never changes type on its own. `n.to_uint8` gives a `Result`, `n.to_uint8!` stops the program when `n` does not fit, and `x.to_i` gives the `Int` back. An operation that leaves the range stops with `RUNTIME-INTEGER-OVERFLOW`. When you want a wrap, use `wrapping_add` and its siblings.

```agentica
struct Pixel
  r: UInt8
  g: UInt8
  b: UInt8
end

def brightness(p: Pixel) -> Int
  (p.r.to_i + p.g.to_i + p.b.to_i) / 3
end

def main() -> Void
  p = Pixel(r: 255, g: 128, b: 0)
  puts(brightness(p))
  puts(p.r.wrapping_add(10))
  puts(300.to_uint8.ok?)
  top: UInt64 = 18446744073709551615
  puts(top / 10)
  puts(top > 9223372036854775807.to_uint64!)
end
```

```output
127
9
false
1844674407370955161
true
```

`UInt64` is not an `Int` at run time: its arithmetic, comparison and sort work on the unsigned value, so it holds `0` to `18446744073709551615`. It is a `Map` key and a `Set` element too.

`Float32` is an IEEE 754 binary32 number. Its arithmetic rounds to the nearest `Float32`, and `to_s` gives the fewest digits that read back as the same value.

```agentica
def main() -> Void
  x: Float32 = 0.1
  puts(x)
  puts(x.to_f)
  puts(x.to_bits)
  puts(16777217.to_float32)
end
```

```output
0.1
0.10000000149011612
1036831949
16777216.0
```

`JSON.encode`, `JSON.decode` and `JSON.schema` take all of these types. A decode checks the range, and the schema has `minimum` and `maximum`.

See [Int and Float](https://www.agentica-lang.com/agentica/library/text-and-data/numbers/#int8-int16-int32-uint8-uint16-and-uint32), [UInt64](https://www.agentica-lang.com/agentica/library/text-and-data/numbers/#uint64) and [Float32](https://www.agentica-lang.com/agentica/library/text-and-data/numbers/#float32).

### Safe navigation

`o&.name` reads a field, and `o&.name(args)` calls a method, through an Optional. It gives `some(value.name)` for `some(value)` and `none` for `none`. The arguments are not computed for `none`.

```agentica
struct Address
  city: String
end

struct User
  name: String
  address: Optional[Address]
end

def main() -> Void
  ana = User(name: "Ana", address: some(Address(city: "Lima")))
  ben = User(name: "Ben", address: none)
  puts(ana.address&.city.unwrap_or("?"))
  puts(ben.address&.city.unwrap_or("?"))
end
```

```output
Lima
?
```

A receiver that is not an Optional is `CHECK-SAFE-NAV-RECEIVER`: write `.`.

See [Optional](https://www.agentica-lang.com/agentica/library/data-structures/optional/#safe-navigation-oname).

### Task.spawn_link

`Task.spawn_link` starts a task like `Task.spawn` and links it to the caller. When one of the two crashes, the other ends with the same diagnostic. A return or a cancel does not end the other.

Here the linked reader divides by zero, so the task that started it ends with that error:

```agentica
def reader() -> Int = 10 / 0

def pair(idle: Channel[Int]) -> Result[Int]
  _reader = Task.spawn_link(&reader)
  idle.recv(60000)
end

def main() -> Void
  idle: Channel[Int] = Channel.new(1)
  task = Task.spawn(&pair, idle)
  case Task.await(task)
    ok(n) -> puts(n)
    error(e) -> puts(e.message.start_with?("task crashed: RUNTIME-DIVISION-BY-ZERO"))
  end
end
```

```output
true
```

The crash is printed once, and an await of any task it reached sees it.

See [Task.spawn_link](https://www.agentica-lang.com/agentica/library/concurrency/task/#taskspawn_link).

### Feature hooks for BDD

`BDD.run` takes `hooks:` with `before_all` and `after_all`. They run once for each feature and each `--jobs` worker, so one server can serve all the scenarios of a feature. `before_all` returns the state of the feature as JSON, such as a port, and every scenario reads it with `BDD.feature_state`.

See [Feature hooks](https://www.agentica-lang.com/agentica/library/testing/bdd/#feature-hooks).

### Version requirements for packages

`agentica add NAME URL --version REQ`, and `version = "~> 0.8"` in a manifest, take the highest git tag that matches. The requirement reads as in RubyGems: `~> 0.8` means `>= 0.8.0, < 1.0.0`. The lock keeps the tag it chose, so a build stays exact and offline. Packages that ask for the same repository meet in one tag.

```sh
agentica add jobs agentica-lang/packages --version "~> 0.1"
```

See [Packages](https://www.agentica-lang.com/agentica/tour/modules/#packages).

## Breaking changes

- **Reserved type names.** `Int8`, `Int16`, `Int32`, `Int64`, `UInt8`, `UInt16`, `UInt32`, `UInt64`, `Float32` and `Float64` are reserved. A program that used one of them as the name of its own type has to rename it.
- **Float literal range.** A float literal that rounds to infinity, such as `1e309`, is `CHECK-FLOAT-RANGE`.
- **std/binary.** It uses the sized types: `read_u16_be` gives a `UInt16`, and `write_i32_le` takes an `Int32`. The writers return `Bytes` with no `Result`, so a `try` on one is a check error. Convert a value that may be out of range first, with `try n.to_uint16`.
- **Float bits.** `Float.to_bits` returns a `UInt64`, and `Float.from_bits` takes one. `Float.to_bits32` and `Float.from_bits32` are gone: use `Float32.to_bits` and `Float32.from_bits`.

## Also

- A method call can take its `{ ... }` block in the head of an `if`, `elsif`, guard, `while`, `for` or `case`: `if xs.any? { |x| x < 0 }`. `agentica fmt` writes it so.
- `agentica COMMAND --help` (and `-h`) prints the usage of that command.
- `Bytes.incomplete_utf8_length` counts the bytes at the end that cut a UTF-8 character short. See [Bytes](https://www.agentica-lang.com/agentica/library/data-structures/bytes/#incomplete_utf8_length).
- An integer or float literal argument of a generic call takes the type that another argument gives the type variable.
- `Result.unwrap_or` types a literal default by the value of the Result.
- With the JIT, loops of `UInt64` arithmetic and comparisons are compiled.
- `agentica add NAME URL --tag NAME-X.Y.Z` with no `--subdir` fetches the tag once, so the folder and the locked commit come from the same fetch.
- The checker messages and `agentica help std/http.serve` write the `std/http` and `std/logger` types as the file imports them.

To install or upgrade, see [getting started](https://www.agentica-lang.com/agentica/getting-started/). The archives for Linux, macOS and Windows are on the [0.38.0 release page](https://github.com/agentica-lang/agentica/releases/tag/0.38.0).
