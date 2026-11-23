---
title: Agentica 0.36.0
description: Agentica 0.36.0 adds a --max-steps flag to agentica test, so a run can set the step budget of each test or lift it.
date: 2026-11-23
draft: false
tags: [release]
---

Agentica 0.36.0 is out. It is a small release. This post lists what changed; the full list is in the [changelog](https://github.com/agentica-lang/agentica/blob/0.36.0/CHANGELOG.md).

## What is new

### agentica test --max-steps

Every test has a step budget, so a test that runs too long fails with `RUNTIME-STEP-LIMIT` instead of running on. The default is 1,000,000 steps. `agentica test --max-steps N` sets the budget for a run, and `--max-steps unlimited` takes the limit away.

Here is a test file with a short test and a long one:

```agentica
def test_fast_sum() -> Result[Void]
  Test.eq([1, 2, 3].sum(), 6)
end

def test_long_loop() -> Result[Void]
  n = 0
  while n < 300000
    n = n + 1
  end
  Test.eq(n, 300000)
end
```

With a budget of 5,000 steps, the long test stops:

```sh
agentica test --max-steps 5000 test/steps_test.agc
```

```output
PASS test/steps_test.agc / fast sum
FAIL test/steps_test.agc / long loop
test/steps_test.agc:8:5 [RUNTIME-STEP-LIMIT] execution step budget exhausted
  stack, innermost first:
    test_long_loop at test/steps_test.agc:8:5
    task spawned at test/steps_test.agc:5:1
1 passed, 1 failed, 0 skipped, 0 not executed, 0 file errors, seed 1786224240
```

With `unlimited`, both tests pass:

```sh
agentica test --max-steps unlimited test/steps_test.agc
```

```output
PASS test/steps_test.agc / fast sum
PASS test/steps_test.agc / long loop
2 passed, 0 failed, 0 skipped, 0 not executed, 0 file errors
```

The tests of one file share a budget: `N` times the number of tests, plus one. See [agentica test](https://www.agentica-lang.com/agentica/cli/#test).

## Also

- `agentica --max-steps N test` now sets the budget too. Before, the flag in front of `test` was ignored.
- The native modules page has a section on a native handle in generic data, so a package can hold a backend's resource through a generic type. See [native modules](https://www.agentica-lang.com/agentica/library/io-and-system/native/modules/#a-handle-in-generic-data).

To install or upgrade, see [getting started](https://www.agentica-lang.com/agentica/getting-started/). The archives for Linux, macOS and Windows are on the [0.36.0 release page](https://github.com/agentica-lang/agentica/releases/tag/0.36.0).
