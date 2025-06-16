---
mode: "edit"
---

Your goal is to set up test cases for the Bash script that's also a command-line application (now refers to as "target script")

The chosen testing framework is Bash Automated Testing System or Bats, [bats-core](https://github.com/bats-core/bats-core). 

The chosen testing auxiliary libraries are:
- [bats-support](https://github.com/bats-core/bats-support/blob/master/README.md)
- [bats-assert](https://github.com/bats-core/bats-assert/blob/master/README.md)
- [bats-file](https://github.com/bats-core/bats-file/blob/master/README.md)

Requirements:

- `$BATS_SUITE_TMPDIR` is a temporary directory common to all tests of a suite. You MUST use `$BATS_SUITE_TMPDIR` to create files required by multiple tests.
- `$BATS_FILE_TMPDIR` is a temporary directory common to all tests of a test file. You MUST use `$BATS_FILE_TMPDIR` to create files required by multiple tests in the same test file.
- `$BATS_TEST_TMPDIR` is a temporary directory unique for each test. You MUST use `$BATS_TEST_TMPDIR` to create files required only for specific tests.
- You MUST clone the target script and create all mock dependencies in `$BATS_FILE_TMPDIR`, then you MUST change working directory to `$BATS_TEST_TMPDIR` inside `setup()` function then execute the target script with current working directory set to `$BATS_TEST_TMPDIR`. This is to ensure the state of the project directory remains intact after test execution.
- You MUST pay attention to not creating duplicate files and directories when provisioning in `$BATS_FILE_TMPDIR`.
- You MUST place the generated script inside `tests/` directory.
- You SHOULD NOT source the target script, unless the test case required internal function direct invocation.
- You MUST NOT use destructive operations (e.g. `mv -f`, `cp -f`, `ln -f`, ...).
- You MUST ignore backup original working directory at `setup()` function.
- 
- You MUST leave `teardown()` function blank:
    ```bash
    teardown() {
        :
    }
    ```
- You MUST avoid test case duplication (i.e. 2 test cases testing the same logic) at all cost.

Example:

```bash
#!/usr/bin/env bats

setup() {
    export BATS_LIB_PATH="${BATS_TEST_DIRNAME}/test_helper"
    bats_load_library bats-support
    bats_load_library bats-assert
    bats_load_library bats-file

    export SCRIPT_UNDER_TEST=$(realpath "${BATS_TEST_DIRNAME}/../script.sh")
    assert_file_exists "${SCRIPT_UNDER_TEST}"
}

teardown() {
    :
}

@test "Script runs without arguments" {
    run "${SCRIPT_UNDER_TEST}"
    assert_success
}

@test "Script handles -h, --help option" {
    run "${SCRIPT_UNDER_TEST}" --help
    assert_success
    assert_output --partial "Usage:"
    assert_output --partial "Options:"

    run "${SCRIPT_UNDER_TEST}" -h
    assert_success
    assert_output --partial "Usage:"
    assert_output --partial "Options:"
}
```
