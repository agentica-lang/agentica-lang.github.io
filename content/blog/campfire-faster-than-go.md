---
title: A Campfire port in Agentica, measured against Go
description: agentica-campfire, a port of ONCE Campfire to Agentica, served four chat pages 17 to 44% faster than the Go port in the Campfire verification benchmark. This post shows the numbers, how they were measured, why, and where Go is still ahead.
date: 2026-11-17
draft: false
tags: [performance, benchmark, bond, agentica-db, web]
---

[agentica-campfire](https://github.com/agentica-lang/agentica-campfire) is a port of 37signals' [ONCE Campfire](https://github.com/basecamp/once-campfire), the group chat, to Agentica. It is built on [Bond](https://www.agentica-lang.com/bond/), EAG templates and [agentica-db](https://www.agentica-lang.com/agentica-db/) on SQLite. It uses the database schema of Rails Campfire, so a database that Rails made opens as it is.

The project is independent. It is not affiliated with or endorsed by 37signals. Campfire is MIT licensed (copyright 37signals, LLC), and so is the port.

Campfire has a shared benchmark, [once-campfire-verification](https://github.com/basecamp/once-campfire-verification), with ports in Go, Rust, Elixir and other languages. We ran it on the Agentica port and on the [Go port](https://github.com/basecamp/once-campfire-go). On the four chat pages it measures, the Agentica port answered more requests per second than Go. This post shows the numbers, how we got them, why the port is fast, and where the comparison has limits.

## The benchmark

`bin/benchmark` starts each app in Docker on a copy of the same seeded database. It signs in as one person and asks for each route with 16 clients for 8 seconds, after a warm-up. The client asks for gzip. Every response is checked against the contract of its route: the status, the content type, and the messages the page must show, in order, with their text. One bad response fails the run. There are 3 rounds, and the order of the apps alternates. The tables show the median of the rounds.

The run in this post:

- Run `20261117-180015-7`, on 2026-11-17, harness revision `ec02deb`, and run `20261117-180912-7` right after it, which measured three routes again (below).
- One laptop: an AMD Ryzen 5 3550H (4 cores, 8 threads). The server ran on CPUs 4-7 and the client on CPUs 0-3, so each had 2 cores (4 threads).
- Agentica port at `bc8f983`: Agentica 0.34.0, Bond 0.13.0, agentica-db 0.11.0.
- Go port at `c4ab53d`.

The harness has no Agentica entry upstream. A small local patch adds one (the image name and the app's checkout); it does not change the load or the checks.

## The numbers

Requests per second, higher is better. The p99 is the range of the 99th percentile latency over the 3 rounds.

| Route | Go | Agentica | Agentica / Go | p99 Go | p99 Agentica |
|---|---:|---:|---:|---:|---:|
| room_show | 6978.9 | 10064.5 | 144% | 6.8–8.0 ms | 3.0–3.2 ms |
| messages_page | 7398.3 | 10185.2 | 138% | 6.6–7.3 ms | 3.1–3.4 ms |
| sidebar | 8068.0 | 10426.4 | 129% | 6.5–7.1 ms | 3.5–3.7 ms |
| search | 8187.4 | 9552.0 | 117% | 6.6–6.8 ms | 3.4–3.8 ms |

Across the 3 rounds, Go's requests per second moved by up to 8% (room_show: 6584 to 7134), and the port's by up to 3%.

`room_show` is the page of a room with its last messages, `messages_page` the older messages, `sidebar` the list of rooms, and `search` a search for one word. No response failed its check.

For scale: Rails Campfire, run by the same harness on the same machine on 2026-11-05, served these pages at 834 to 990 requests per second.

## Where Go is ahead

Go still serves files faster. In the first run, Go's numbers on these two routes were low and spread wide (avatar: 18212 to 21248), so we ran them again right after, with `post_message`. The second run is the one below; Go was back at the level of earlier runs.

- `avatar`, a person's picture: Go 21404.6, Agentica 7963.5 (37% of Go). In the first run: 18423.1 and 7789.9 (42%).
- `static_css`, a stylesheet: Go 25526.0, Agentica 18948.8 (74% of Go). In the first run: 20601.5 and 18464.2 (90%). The two apps send different files: the port's stylesheet is 3.6 KB gzipped, Go's is 0.7 KB.

The port is ahead on the two other routes of the run:

- `up`, the health check: Go 14130.5, Agentica 22411.4 (159% of Go).
- `post_message`, posting a message: Go 1024.0, Agentica 1255.4 (123% of Go), with a p99 of 51–56 ms for Go and 19–22 ms for the port. Every post was checked in the database afterwards. In the first run Go posted only 634.4 (565 to 696, p99 up to 104 ms) and the port 1160.3, so we count the second run. Writes on this laptop depend on the disk, and on 2026-11-08 they stalled for seconds, so take the write numbers with more care than the pages. Go was ahead on writes before: in the run of 2026-11-07, on Agentica 0.26.1, Go posted 1135.3 messages per second and the port 906.6 (80% of Go).

## Why the pages are fast

Rails Campfire keeps whole pages in a cache, for the person and the request, and drops them when `PRAGMA data_version` changes. That is a counter of SQLite that moves when any connection commits. The Go port does the same, and so does the Agentica port. The routes above write nothing, so when nothing was written, a request for one of these pages is a hit, and the benchmark mostly measures the path of a hit. On that path, the two ports do different amounts of work.

**One read of the version, with no hand-off.** The port reads `data_version` on one read-only SQLite connection, opened once, with the statement prepared once. A read is three plain calls into SQLite: step, read the column, reset. There is no task switch and no thread hop. Readers on different schedulers take turns with a token in a channel of one place, so a reader that waits is a parked task, not a parked thread. Before this change, the read went through a pool of one connection, and the whole app topped out near 3,500 cached pages per second.

**No query for the session on a hit.** The person of a session is kept in memory for one version of the database. A sign-out, a ban or a rename is a commit, so it gives a new version and the next request looks the session up again. The signed cookie is still checked on every request. So a hit reads the version once and runs no SQL query. In the Go code, a request for a cached page checks the session with two SQL queries and reads the version twice. We read that code; we did not profile the Go port, so we do not know how much of the gap this explains.

**The page is kept as bytes.** The cached page is sent as `Bytes`, with no step through text. Before, it was cut out of a string, which walked every character of a page that has a non-ASCII character: about 140 µs per request.

**The VM does the HTTP work in C.** Each connection is one task. The VM runs one scheduler thread per CPU it may use, and since Agentica 0.33.0 a connection's reads and writes run on the scheduler of its task. It parses the request head in C (picohttpparser behind a strict adapter), and it checks and writes the response head in C. The page cache is a shared table of the VM, which tasks on every scheduler read.

**A larger first heap.** The image starts the garbage collector with a 32 MB heap. With the default heap it collected every few requests.

**A smaller page.** The port has its own markup. Its room page is 25 KB. Go's room page is 374 KB before gzip and 21 KB after, close to the 415 KB of Rails. On a hit Go sends gzip bytes from its cache, so it does not compress again, but it is not the same page. The port does not gzip its pages, so on the wire they are about the same size (room page: 25 KB against 21 KB; older messages: 20 KB against 13 KB).

EAG templates and the native SQLite driver of agentica-db work on a miss. An EAG template is checked and compiled to bytecode with the file that holds it, so a page is built by the VM with no template engine at run time. The native driver is a C module with a cache of prepared statements; a one-row query costs about a tenth of the older FFI driver's. On a hit neither runs, so they are not the main reason for the numbers above.

## How it got here

On 2026-11-06 the same four pages were at 44 to 50% of Go. By 2026-11-08 (Agentica 0.27.0, app at `8a7616e`) they were at 107 to 134%. In between came the version read above, the native SQLite driver, the page body as bytes with the larger heap, and Agentica 0.27.0, among other changes to the app. From there to this run (Agentica 0.34.0, app at `bc8f983`), the port's pages rose by 6 to 11% while Go's moved by 2% or less: 9500.9 to 10064.5 on room_show, 9536.0 to 10185.2 on messages_page, 9357.9 to 10426.4 on sidebar, 8953.4 to 9552.0 on search. The app changed too in that time, so the gain is not Agentica alone. Some of the pull requests measured their change with a local load test, but the benchmark ran only every few changes, so we cannot give each change its share. The steps are in the [pull requests](https://github.com/agentica-lang/agentica-campfire/pulls?q=is%3Apr+is%3Amerged) and the history of the README.

## Limits

- One machine, a laptop, with 2 cores for the server. More cores could change the order.
- SQLite only, one person, one room, one search word, 16 clients.
- Writes are one route, on one laptop disk, and the two runs of this day gave Go 634.4 and 1024.0 posts per second. Go was ahead on writes in the run of 2026-11-07.
- The pages are not byte for byte the same. The harness checks the messages in each page, not the markup.
- On a hit, the port does not refresh the time of the session's last activity; it does so only when it looks the session up. Go checks it on every request.
- The port is not at parity with Campfire yet. The missing parts are in [docs/plan.md](https://github.com/agentica-lang/agentica-campfire/blob/main/docs/plan.md).
- We compared with Go only. The harness has other ports that we did not run.

## Run it yourself

You need Docker and a machine with nothing else running. In a checkout of agentica-campfire:

```sh
bench/run.sh --setup
cd ~/apps/bench/once-campfire-agentica
git fetch origin && git checkout --detach bc8f983
docker build --build-arg CAMPFIRE_REVISION="$(git rev-parse HEAD)" -t once-campfire-agentica:app .
cd -
bench/run.sh --apps go,agentica
```

`bench/run.sh` clones the harness at `ec02deb` into `~/apps/bench`, clones the port next to it, applies the local patch, builds the load generator and seeds the database. Then it runs `bin/benchmark` with the server on CPUs 4-7 and the client on CPUs 0-3. The image carries the revision it was built from, and `bench/run.sh` refuses to run an image whose revision is not the one of the clone that the harness records. The Go port needs its own image (`once-campfire-go:app`) and a checkout of it next to the harness. The method is in [docs/benchmarks.md](https://github.com/agentica-lang/agentica-campfire/blob/main/docs/benchmarks.md) and the steps in [bench/README.md](https://github.com/agentica-lang/agentica-campfire/blob/main/bench/README.md).

## Links

- [agentica-campfire](https://github.com/agentica-lang/agentica-campfire), the port
- [once-campfire-verification](https://github.com/basecamp/once-campfire-verification), the benchmark
- [once-campfire-go](https://github.com/basecamp/once-campfire-go), the Go port
- [once-campfire](https://github.com/basecamp/once-campfire), Campfire
- [Bond](https://www.agentica-lang.com/bond/) and [agentica-db](https://www.agentica-lang.com/agentica-db/)
- [Agentica](https://www.agentica-lang.com/agentica/)
