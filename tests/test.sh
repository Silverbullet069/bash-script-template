#!/usr/bin/env bats

setup() {
    # NOTE: do not load library in setup_file() function
    # shellcheck disable=SC2154
    export BATS_LIB_PATH="${BATS_TEST_DIRNAME}/test_helper"
    bats_load_library bats-support
    bats_load_library bats-assert
    bats_load_library bats-file

    export SCRIPT_UNDER_TEST=$(realpath "${BATS_TEST_DIRNAME}/../${SCRIPT_NAME:-script.sh}")
    assert_file_exists "${SCRIPT_UNDER_TEST}"
}

# Clean up after each test
teardown() {
    # if you accidentally forget to clean inside the test case
    :
}

# ============================ CLI Tests ============================

@test "Script runs without arguments" {
    # shellcheck disable=SC2154
    run "${SCRIPT_UNDER_TEST}"

    # Should run without errors
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

@test "Script handles -n, --no-colour option" {
    # First run with color
    run "${SCRIPT_UNDER_TEST}"
    assert_success
    local -r output_with_color="${output}"

    # Different output expected (no ANSI codes in no-colour mode)
    # This is a simple way to check if output is different - not perfect but gives an indication

    run "${SCRIPT_UNDER_TEST}" --no-colour
    assert_success
    assert_not_equal "${output_with_color}" "${output}"

    run "${SCRIPT_UNDER_TEST}" -n
    assert_success
    assert_not_equal "${output_with_color}" "${output}"
}

@test "Script handles -l. --log-level option" {

    run "${SCRIPT_UNDER_TEST}" --log-level ERR "info" "Test info message"
    assert_success
    refute_output --partial "Test info message"

    run "${SCRIPT_UNDER_TEST}" -l ERR "info" "Test info message"
    assert_success
    refute_output --partial "Test info message"
}

@test "Script handles -q, --quiet option" {
    run "${SCRIPT_UNDER_TEST}" --quiet
    assert_success
    refute_output

    run "${SCRIPT_UNDER_TEST}" -q
    assert_success
    refute_output
}

@test "Script handles -t, --timestamp option" {

    run "${SCRIPT_UNDER_TEST}" --timestamp
    assert_success
    # Timestamp format [YYYY-MM-DD HH:MM:SS +ZZZZ]
    assert_output --regexp '\[[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2} [+-][0-9]{4}\]'

    run "${SCRIPT_UNDER_TEST}" -t
    assert_success
    # Timestamp format [YYYY-MM-DD HH:MM:SS +ZZZZ]
    assert_output --regexp '\[[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2} [+-][0-9]{4}\]'
}

@test "Script fails with invalid option" {

    run "${SCRIPT_UNDER_TEST}" --invalid-option
    assert_failure
    assert_output --partial "Invalid parameter"
}

@test "Script creates and releases lock" {

    run "${SCRIPT_UNDER_TEST}"
    assert_success
    assert_dir_not_exists "/tmp/${SCRIPT_NAME:-script.sh}.${UID}.lock"
}

@test "Script fails when lock already exists" {
    # Create lock directory manually
    mkdir -p "/tmp/${SCRIPT_NAME:-script.sh}.${UID}.lock"

    run "${SCRIPT_UNDER_TEST}"
    assert_failure
    assert_output --partial "Unable to acquire script lock"

    # Manual cleanup
    rmdir "/tmp/${SCRIPT_NAME:-script.sh}.${UID}.lock"
}

@test "info() function logs info message" {
    run "${SCRIPT_UNDER_TEST}" "info" "Test info message"
    assert_success
    assert_output --partial "[INF]"
    assert_output --partial "Test info message"
}

@test "warn() function logs warning message" {
    run "${SCRIPT_UNDER_TEST}" "warn" "Test warning message"
    assert_success
    assert_output --partial "[WRN]"
    assert_output --partial "Test warning message"
}

@test "error() function logs error message and exits" {
    run "${SCRIPT_UNDER_TEST}" "error" "Test error message"
    assert_success
    assert_output --partial "[ERR]"
    assert_output --partial "Test error message"
}

@test "Script DEBUG environment variable enables trace output" {
    # Run the script with DEBUG=1
    DEBUG=1 run "${SCRIPT_UNDER_TEST}"

    # Should run without errors
    assert_success
    assert_output --partial "+"
}

@test "debug() function logs error message and exits" {
    DEBUG=1 run "${SCRIPT_UNDER_TEST}" "debug" "Test debug message"
    assert_success
    assert_output --partial "[DBG]"
    assert_output --partial "Test debug message"
}
