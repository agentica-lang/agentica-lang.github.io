---
title: Agentica 0.40.0 beta 1 and 2
description: Agentica 0.40.0 beta 1 and 2 bring file permissions and symbolic links, enum introspection, temporary files, file copying, host names, and packed Float32 lists.
date: 2026-11-26T00:00:00Z
draft: false
tags: [release]
---

Agentica 0.40.0 beta 1 and beta 2 are out. Together, these previews add file and archive operations, enum introspection, and more efficient Float32 lists. Beta 1 also includes a breaking change to file error kinds. The full lists are in the [changelog](https://github.com/agentica-lang/agentica/blob/0.40.0-beta.2/CHANGELOG.md).

## File operations

You can now set file and directory permission bits with `File.chmod`, create and read symbolic links with `File.symlink` and `File.readlink`, and copy a file with `File.copy`. `File.copy` preserves permission bits. Systems that do not support symbolic links return `io.unsupported`.

`Archive.Options(keep_mode: true)` preserves permission bits when extracting TAR files. Beta 2 adds temporary files: open a path with `File.open(path, "temp")`, and the file is removed when the handle closes unless you move it first. The runtime also cleans it up if its task is cancelled or the run ends.

## Enum introspection

`Color.values` lists the values of an enum without payloads, and `Color.parse(text)` parses one from text. The `value.name` property returns the name of any enum value.

## Float32 lists

`List[Float32]` now uses packed storage, taking 4 bytes per item instead of 16. Native modules can also read a `List[Float32]` directly as C floats and create one from a C array, without allocating a term for each item. This is available through `an_float32_run`, `an_float32s`, and C API 1.6.

## Breaking change

File errors caused by `ENOTSUP` or `EOPNOTSUPP` now have kind `io.unsupported` instead of `io.failed`. Update code that checks these errors to handle the new kind.

Beta 2 also adds `System.hostname()` to get the machine's host name.
