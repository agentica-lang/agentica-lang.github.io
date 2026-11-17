---
title: Agentica 0.34.0
description: Agentica 0.34.0 adds an interactive REPL, prebuilt native modules, and better control of HTTP connections and timeouts.
date: 2026-11-17
draft: false
tags: [release]
---

Agentica 0.34.0 is out. This post lists what changed; the full list is in the [changelog](https://github.com/agentica-lang/agentica/blob/0.34.0/CHANGELOG.md).

## What is new

### agentica repl

`agentica repl` runs entries one at a time over a live session. The names an entry binds, the functions and structs it declares, and the tasks it starts stay for the next entries. An entry that ends with an expression prints its value and type:

```sh
$ agentica repl
agc> xs = [1, 2, 3]
agc> def total(items: List[Int]) -> Int = items.sum()
agc> total(xs) * 10
=> 60 : Int
```

`:type EXPR`, `:load FILE`, `:reset` and `:quit` are commands. With `--json`, the REPL prints one object per entry, with `ok`, the `value` and `type`, the names it bound, or a `diagnostic`. An agent can drive a session that way and read each answer. See [REPL](https://www.agentica-lang.com/agentica/cli/#repl).

### Prebuilt native modules

A package with a native module can now name prebuilt files, one per platform, in a `prebuilt` table beside `build` in `[native.NAME]`. `agentica install` downloads the file for the host and checks its SHA-256. A run then uses that file, so it needs no C compiler. Otherwise the module builds from source, as before.

A project chooses per module with `[native_policy]`:

```toml
[native_policy]
build = ["stats"]
```

`build` names modules that always build from source; `prebuilt_only` names modules that never build. The `--native-build` and `--native-prebuilt-only` flags do the same for one run. See [native modules](https://www.agentica-lang.com/agentica/library/io-and-system/native/modules/).

[agentica-db](https://www.agentica-lang.com/agentica-db/) will be the first package with prebuilt files: the `prebuilt` row of its `db_sqlite` module lands in an upcoming agentica-db release.

### HTTP: connect_to and new timeouts

`HTTP.ClientOptions` has three new fields:

- `connect_to` sends every connection to a given IP address instead of the URL's host. `Host`, the TLS server name and the certificate check keep the URL's host. Use it with your own resolver, a DNS cache, or a check that refuses private addresses.
- `connect_timeout_ms` (10 s) bounds the connect: DNS, TCP, TLS and a proxy `CONNECT`.
- `read_timeout_ms` (300 s) bounds each wait for body bytes. `0` means no limit, for a stream that may stay quiet.

```agentica
options = HTTP.ClientOptions(connect_to: "203.0.113.7", read_timeout_ms: 0)
response = HTTP.get_response("https://api.example.com/events", options)
```

See [HTTP.client](https://www.agentica-lang.com/agentica/library/io-and-system/network/#httpclient).

### bytes.scrub

`bytes.scrub` reads UTF-8 that may hold bad bytes, such as a log or the output of a child process. It never fails: each bad sequence becomes U+FFFD, or the text you pass.

```agentica
data = Bytes.from_list([104, 226, 130, 105, 255]).unwrap!
puts(data.scrub)       # h�i�
puts(data.scrub("?"))  # h?i?
```

Every lossy UTF-8 decode now follows the same rule as Python: one replacement per invalid sequence, not one per byte. See [scrub](https://www.agentica-lang.com/agentica/library/data-structures/bytes/#scrub).

## Breaking changes

- **HTTP read timeouts.** `timeout_ms` no longer bounds each read of `HTTP.open`, `start` and `upload`. If you relied on it, set `read_timeout_ms` to the same value. A connect now ends after `connect_timeout_ms` (10 s); raise it if a server needs longer to accept.
- **gunzip reads every member.** `Zlib.gunzip` and `lazy.gunzip` decode every member of a gzip file, as Python's `gzip.decompress` does, and `Archive.extract_tar` reads a multi-member `.tar.gz` as one stream. Before, a second member was an error. If your code split members itself or expected that error, remove that code. See [Zlib](https://www.agentica-lang.com/agentica/library/text-and-data/zlib/).

## Also

- A parameter or field default may be the bytes of a string literal: `body: Bytes = "".bytes`.
- The `std/http` client accepts HTTP/1.0 responses, and HTTP/1.0 proxies for `CONNECT`.
- `agentica install` replaces a `deps/NAME` folder whose manifest is not the locked one, so a lock bump of only a manifest no longer ends in `PKG-SOURCE-CONFLICT`.
- `CHECK-UNUSED-VARIABLE` no longer fires on `count = try step(count)` or `count = step(count).unwrap!` in a loop.
- The documentation moved to [agentica-lang.com/agentica](https://www.agentica-lang.com/agentica/); old links redirect.

Also on the blog: [A Campfire port in Agentica, measured against Go](https://www.agentica-lang.com/blog/campfire-faster-than-go/).

To install or upgrade, see [getting started](https://www.agentica-lang.com/agentica/getting-started/). The archives for Linux, macOS and Windows are on the [0.34.0 release page](https://github.com/agentica-lang/agentica/releases/tag/0.34.0).
