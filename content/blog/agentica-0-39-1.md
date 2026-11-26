---
title: Agentica 0.39.1
description: Agentica 0.39.1 is a patch release: a program that hands the terminal to an editor or a shell keeps the keys typed there.
date: 2026-11-26T01:14:55Z
draft: false
tags: [release]
---

Agentica 0.39.1 is out. There are no breaking changes. It is a bug fix release; the full list is in the [changelog](https://github.com/agentica-lang/agentica/blob/0.39.1/CHANGELOG.md).

## What is new

### Keys typed to a child process are kept

A terminal app can stop reading the keyboard for a moment, for example to run an editor or a shell, and then give the terminal to that program. Before 0.39.1, a read of standard input that was cancelled while it waited could still take the keys that arrived after the cancel, so the first keys typed in the editor or the shell were lost.

Now a cancelled `IO.read_bytes` or `IO.gets` on standard input leaves the bytes that arrive after the cancel where they are, for the next reader. The child process gets them. This holds on Linux and macOS.

On Windows, and when standard input cannot be polled (for example a regular file), the old behavior remains for now. It is tracked in [issue #2016](https://github.com/agentica-lang/agentica/issues/2016).
