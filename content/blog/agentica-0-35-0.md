---
title: Agentica 0.35.0
description: Agentica 0.35.0 adds HTTP downloads with no size limit, dates and times as checked values, and equality for JSON values.
date: 2026-11-19
draft: false
tags: [release]
---

Agentica 0.35.0 is out. This post lists what changed; the full list is in the [changelog](https://github.com/agentica-lang/agentica/blob/0.35.0/CHANGELOG.md).

## What is new

### HTTP downloads with no size limit

`HTTP.download`, `HTTP.read_body` and `HTTP.open` no longer stop a body at 256 MiB. `HTTP.download` streams the body to a hidden `.agc-part` file beside the target and renames it over the target only after a clean end, so the target is always the old file or the whole new one. `DownloadOptions` takes an optional `sha256`: a body with another digest is an `error` and leaves the target alone.

Here a download from a local server, with the right digest and then a wrong one:

```agentica
import HTTP from "std/http"

def main() -> Void
  client = HTTP.client().unwrap!
  url = "http://127.0.0.1:18350/asset.bin"
  good = "16e7bfe7e88ab63c69b0cccdb9e65ca9ba55fdce5e4e605dec9fa418b05dc790"
  bad = "00000000000000000000000000000000000000000000000000000000000000ff"
  for digest in [good, bad]
    case HTTP.download(client, url, "asset.bin", HTTP.DownloadOptions(sha256: some(digest)))
      ok(saved) -> puts("ok, #{saved.bytes_written} bytes")
      error(e) -> puts(e.message)
    end
  end
  puts(Dir.list(".").unwrap!)
  HTTP.close_client(client)
end
```

```output
ok, 29 bytes
http: the body does not match the sha256 digest
["asset.bin"]
```

`timeout_ms` and `max_total_bytes` are `Optional[Int]` and `none` by default; set one with `some(...)`. See [HTTP.download](https://www.agentica-lang.com/agentica/library/io-and-system/network/#httpdownload).

The rename step is also yours: `Path.replace(from, to)` renames a file over another in one step, and a reader of `to` sees the old file or the new one, never neither.

```agentica
def main() -> Void
  _ = File.write_text("settings.json", "{\"v\": 1}")
  _ = File.write_text("settings.json.new", "{\"v\": 2}")
  puts(Path.replace("settings.json.new", "settings.json").ok?)
  puts(File.read_text("settings.json").unwrap!)
end
```

```output
true
{"v": 2}
```

See [Path.replace](https://www.agentica-lang.com/agentica/library/io-and-system/files/#pathreplace).

### Dates and times

`Time.Date`, `Time.TimeOfDay`, `Time.NaiveDateTime` and `Time.DateTime` (at a fixed UTC offset) are checked builtin records. A value that is not a real date cannot be built. They read and write ISO 8601, take Unix time, add days or microseconds, and print with `strftime`.

```agentica
def main() -> Void
  day = Time.Date.iso8601("2026-01-31").unwrap!
  puts(day.add_days(30).unwrap!.iso8601)
  puts(day.cwday)
  puts(Time.Date.days_in_month(2028, 2).unwrap!)
  stamp = Time.at(1_800_000_000).unwrap!
  puts(stamp.iso8601)
  puts(stamp.strftime("%a %d %b %Y, %H:%M"))
end
```

```output
2026-03-02
6
29
2027-01-15T08:00:00.000000Z
Fri 15 Jan 2027, 08:00
```

`std/utc` is deprecated, and it will be removed in a later release: use `Time`. See [dates and times](https://www.agentica-lang.com/agentica/library/io-and-system/time/).

### JSON keeps key order, and values compare with ==

A JSON object now keeps its keys in the order you gave them, and `JSON.parse` keeps the order of the text. Two `JSON.Value`s compare with `==` and `!=`: object keys in any order, arrays in order, and numbers by value, so `1 == 1.0`.

```agentica
def main() -> Void
  a = JSON.parse("{\"b\": 1, \"a\": [1, 2]}").unwrap!
  b = JSON.parse("{\"a\": [1.0, 2], \"b\": 1.0}").unwrap!
  puts(JSON.encode(a))
  puts(a == b)
  puts(a == JSON.parse("{\"a\": [2, 1], \"b\": 1}").unwrap!)
end
```

```output
{"b":1,"a":[1,2]}
true
false
```

A list, map or struct that holds a `JSON.Value` has equality too, and `Test.eq` compares the same way. See [JSON](https://www.agentica-lang.com/agentica/library/text-and-data/json/).

### Processes and the program name

`Process.pid(p)` gives the operating system's process id of a child, and `System.program_name()` gives the path of the main program as it was given, the `.agc` or the `.agcb` file.

```agentica
def main() -> Void
  puts(System.program_name())
  child = Process.spawn("sleep", ["1"]).unwrap!
  puts(Process.pid(child).unwrap! > 0)
  _ = Process.wait(child, 5000)
end
```

See [Process.pid](https://www.agentica-lang.com/agentica/library/io-and-system/process/#processpid).

## Breaking changes

- **JSON key order.** `JSON.from`, `JSON.object`, `JSON.parse`, a decoded `Map` and `JSON.node` no longer sort keys, and a struct writes its fields in declaration order. `JSON.encode(JSON.parse(x))` keeps the order of `x`, so it is not a canonical form and no longer compares two texts regardless of key order. Compare the parsed values with `==`. Code or goldens that expected sorted keys change.
- **`--json` key order.** The diagnostics and reports of `--json` list their keys in field order. A tool that matched them as text sees a new order.
- **No body limit.** `HTTP.download`, `HTTP.read_body` and `HTTP.open` no longer end a body at 256 MiB. If a program relied on that cap, set `max_total_bytes` on a download, or count the bytes in the read loop. `DownloadOptions.timeout_ms` and `max_total_bytes` are now `Optional[Int]`: write `some(30000)` where you wrote `30000`.
- **Bytecode.** A 0.34 VM rejects a `.agcb` built by 0.35, because nearly every one holds the new `case` trap (below). Run a 0.35 `.agcb` on a 0.35 VM.
- **Log times.** They have six fraction digits: `2026-10-12T10:15:02.345000Z`, where it was `.345Z`.

## Also

- A `case` that matches no arm now stops with `RUNTIME-CASE-NO-MATCH` at the case, instead of going on with a stale value. Only a checker bug allows such a `case`.
- A program whose standard output or error loses its reader (`prog | head`) ends quietly with status 141, instead of a `RUNTIME-INTERNAL` error.
- `agentica add NAME OWNER/REPO` takes a GitHub repository, and a tag `NAME-X.Y.Z` with no `--subdir` takes the folder `NAME` when the package is there. A source that is neither an `https://` URL nor `OWNER/REPO` is `PKG-SOURCE-INVALID` with exit 1, no longer a usage error with exit 2.
- A dependency can be a whole workspace repository under one name: `finn = { git, tag, workspace = true }`, or `agentica add NAME URL --tag TAG --workspace`. The members are imported as `pkg/finn/MEMBER/MODULE`.
- `agentica install` fetches the packages of one repository, pin and commit with one `git fetch`.
- Getting started has a Nix flake that fetches the release archives.

To install or upgrade, see [getting started](https://www.agentica-lang.com/agentica/getting-started/). The archives for Linux, macOS and Windows are on the [0.35.0 release page](https://github.com/agentica-lang/agentica/releases/tag/0.35.0).
