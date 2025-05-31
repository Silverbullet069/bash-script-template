---
mode: "agent"
---

Your goal is to generate test cases for the Bash script that's also a command-line application (now called "target script") using bash Automated Testing System or Bats, [bats-core](https://bats-core.readthedocs.io/en/stable/) as the testing framework.

The target script sourced another Bash script called `source.sh` to utilize its reusable functions.

Test cases requirements:

-   The name of generated script is `test.sh`. If there is an existing "tests" directory, put `test.sh` inside it. Otherwise put it in the same directory as the target script.
-   Sourcing the target script is strictly forbidden. Invoke it as a command-line application.
-   During test, creating files and directory inside workspace is strictly forbidden. Create them in `${BATS_TEST_TMPDIR}`.
-   Leave `teardown()` blank:
    ```
    teardown() {
        :
    }
    ```
-   Prefer using functions from 2 helper libraries:
    -   [bats-assert](https://github.com/bats-core/bats-assert/blob/master/README.md)
    -   [bats-file](https://github.com/bats-core/bats-file/blob/master/README.md)
-   Ignore log types (i.e. "[DBG]", "[INF]", "[WRN]", "[ERR]") when verifying outputs.
-   Ignore backup original working directory at `setup()`
-   Ignore restore original working directory at `teardown()`.
-   Ignore clear lock file at `teardown()`.
