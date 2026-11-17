---
title: Agentica 0.33.0
description: Agentica 0.33.0 adds Bytes.build, Actor.send and Actor.await, pseudo-terminals and Native.arena, and makes network servers, text work and cached starts faster.
date: 2026-11-16
draft: false
tags: [release, performance]
---

Agentica 0.33.0 is out. This post lists what changed; the full list is in the [changelog](https://github.com/agentica-lang/agentica/blob/master/CHANGELOG.md).

## What is new

- `Bytes.build do |out| ... end` builds one `Bytes` from many parts with no copy in between.
- `Actor.send` and `Actor.await` split `Actor.call` in two, so a caller can ask several actors first and await each answer later.
- `Process.spawn` with `pty: true` runs a program on a pseudo-terminal, and `Process.resize` sets its size (Linux and macOS).
- `Native.arena do ... end` closes, when its block ends, the native resources and buffers the block opened, except those its value holds.
- The errors of file and network builtins carry `details`: `"path"` for file calls, `"host"` for network calls.
- `agentica compile` with no `-o` fills the bytecode cache ahead for every `main.agc` under the working folder.

## Faster

- With several schedulers, TCP and TLS reads and sends run on the task's scheduler: faster streams and HTTP(S) servers.
- `ATS.get`, `has_key?` and the read of `push` take no lock, so readers scale with the schedulers.
- `agentica FILE.agc` starts a cached program without loading the compiler: about 16 ms in place of 48 ms on Linux.
- A `compute def` or dirty native call right after another costs about 3 µs in place of 15 to 25 µs.
- The interpreter runs programs 4 to 6% faster; text work, `JSON.parse` and `Float` to text are faster too.

## agc-redis-s on 0.33.0

[agc-redis-s](https://github.com/agentica-lang/agc-redis-s) is a Redis-compatible server written in Agentica. We ran the same code on 0.32.0 and on 0.33.0 with redis-benchmark 8.0.2 and 4 schedulers. GET, LPUSH and MGET with a pipeline of 16 run 18 to 27% faster. With 1 scheduler the difference is within noise.

With `Bytes.build` building the replies, LRANGE_100 runs 3 to 4 times as fast. The numbers and the method are in [agc-redis-s pull request 69](https://github.com/agentica-lang/agc-redis-s/pull/69); `tools/bench.py` in that repository reruns them.

## Fixed

- `String#downcase` picks the final sigma as Python does.
- Loops that parse large JSON arrays or build large lists are much less likely to hit `--max-heap` on macOS arm64 and Windows.
- `JSON.decode` and codecs give a field's default for a missing key.

To install or upgrade, see [getting started](https://www.agentica-lang.com/agentica/getting-started/).

The latest patch release is 0.33.2; see the [releases](https://github.com/agentica-lang/agentica/releases).
