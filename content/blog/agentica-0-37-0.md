---
title: Agentica 0.37.0
description: Agentica 0.37.0 adds agentica init, unbounded channels, a reason for closing a channel, File.seek, Math functions and Ref.new.
date: 2026-11-23T20:25:36Z
draft: false
tags: [release]
---

Agentica 0.37.0 is out. There are no breaking changes. This post lists what changed; the full list is in the [changelog](https://github.com/agentica-lang/agentica/blob/0.37.0/CHANGELOG.md).

## What is new

### agentica init

`agentica init [NAME]` starts a project in the working folder. It writes an `agentica.toml` with the name and the running version, and a `main.agc` that prints a hello world. It never changes an existing manifest: in that case it stops with `PKG-MANIFEST-EXISTS`.

```sh
agentica init hello-app
agentica main.agc
```

```output
created main.agc
created agentica.toml
Hello, world!
```

See [the command line](https://www.agentica-lang.com/agentica/cli/#commands).

### Unbounded channels and a reason for closing

`Channel.new` with no capacity makes an unbounded channel, as Ruby's `Queue.new`. A send to it never waits. The channel keeps every value until it is received. Pick a capacity when the receiver may fall behind: a full channel makes the senders wait.

`Channel.close(channel, error)` closes a channel with a reason. Senders get that error in place of `error("channel: closed")`. Receivers get it once the values left are taken, so they learn why the stream ended.

Here a job source fails on the third job. The producer closes the channel with the error:

```agentica
def read_job(n: Int) -> Result[Int]
  return error("job source is down", kind: "job.source") if n == 3

  ok(n * 10)
end

def main() -> Void
  jobs: Channel[Int] = Channel.new
  for n in 1..5
    case read_job(n)
      ok(job) -> _ = jobs.send(job, 0)
      error(e) -> jobs.close(e)
    end
  end
  puts(jobs.recv(0).unwrap!)
  puts(jobs.recv(0).unwrap!)
  case jobs.recv(0)
    ok(job) -> puts(job)
    error(e) -> puts("#{e.kind}: #{e.message}")
  end
end
```

```output
10
20
job.source: job source is down
```

See [Channel.new](https://www.agentica-lang.com/agentica/library/concurrency/channel/#channelnew) and [Channel.close](https://www.agentica-lang.com/agentica/library/concurrency/channel/#channelclose).

### File.seek

`File.seek(handle, offset)` moves a read handle to a byte offset. A program can read one part of a large file and skip the rest. Only a handle opened for reading can seek. A pipe, a FIFO or a terminal cannot.

```agentica
def main() -> Void
  _ = File.write_text("letters.txt", "abcdefghij")
  f = File.open("letters.txt", "read").unwrap!
  File.seek(f, 2, 1000).unwrap!
  puts(File.read_bytes(f, 3, 1000).unwrap!.decode("utf-8").unwrap!)
  File.close(f, 1000).unwrap!
end
```

```output
cde
```

See [File.seek](https://www.agentica-lang.com/agentica/library/io-and-system/files/#fileseek).

### AN_FRESH for native modules

Native API 1.5 adds the `AN_FRESH` flag for a native function. A function marked `AN_FRESH` makes resources that own their memory. They do not point into the state of an argument. So an arena that keeps the result keeps only the result, and the arguments can be freed while the result lives.

A module built with the API 1.5 header needs agentica 0.37.0 or later. An older agentica refuses it with `RUNTIME-NATIVE-LOAD`.

In the ml package ([agentica-lang/ml#70](https://github.com/agentica-lang/ml/pull/70)), the libtorch functions are marked `AN_FRESH`. On CPU, whisper-tiny on libtorch went from an RTF of 0.67 to 0.34 on an 11 s clip, and the peak memory went from 1.48 to 0.95 GB.

See [the C side of native modules](https://www.agentica-lang.com/agentica/library/io-and-system/native/modules/#the-c-side).

## Also

- `Math.exp`, `Math.log`, `Math.log10`, `Math.sin` and `Math.cos`, as in Ruby. `log` and `log10` of a negative number stop with `RUNTIME-INVALID-NUMBER`. See [numbers](https://www.agentica-lang.com/agentica/library/text-and-data/numbers/#mathexp-mathlog-mathlog10-mathsin-and-mathcos).
- `Ref.new()` returns a token that is unique in the run and equals only itself. A `Ref` can be a `Map` key or a `Set` element, and `sort` orders Refs by when they were made. See [Ref](https://www.agentica-lang.com/agentica/library/data-structures/ref/).
- `CHECK-ARITY` lists the arities in ascending order, as in `expects 0 or 1 argument(s)`.

To install or upgrade, see [getting started](https://www.agentica-lang.com/agentica/getting-started/). The archives for Linux, macOS and Windows are on the [0.37.0 release page](https://github.com/agentica-lang/agentica/releases/tag/0.37.0).
