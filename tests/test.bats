#!/usr/bin/env bats

# shellcheck disable=SC2154

# Common test functions for bash script testing
# This library contains reusable test functions that can be shared across multiple test files
# NOTE: Many basic assertions are already provided by bats-assert and bats-file libraries

setup_file() {
    # provision testing environment here
    # ...
    :
}

setup() {
    # load library
    # export BATS_LIB_PATH="${BATS_TEST_DIRNAME}/test_helper"
    bats_load_library bats-support
    bats_load_library bats-assert
    bats_load_library bats-file

    # shellcheck disable=SC1091
    source "${BATS_TEST_DIRNAME}/test_helper/common_tests.sh"

    # construct script under test
    export SCRIPT_UNDER_TEST=$(realpath "${BATS_TEST_DIRNAME}/../script.sh")
    export SCRIPT_UNDER_TEST_2=$(realpath "${BATS_TEST_DIRNAME}/../template.sh")
    assert_file_exists "${SCRIPT_UNDER_TEST}"
    assert_file_exists "${SCRIPT_UNDER_TEST_2}"

    # provision testing environment here
    # ...
}

teardown() {
    # Clean up after each test case
    :
}

teardown_file() {
    # Clean up after last test case
    :
}

# =============================== COMMON TESTS =============================== #

@test "Script runs without arguments" {
    test_script_runs_without_arguments "${SCRIPT_UNDER_TEST}"
}

@test "Template runs without arguments" {
    test_script_runs_without_arguments "${SCRIPT_UNDER_TEST_2}"
}

@test "Script handles -h, --help option" {
    test_help_option "${SCRIPT_UNDER_TEST}"
}

@test "Template handles -h, --help option" {
    test_help_option "${SCRIPT_UNDER_TEST_2}"
}

@test "Script handles -n, --no-colour option" {
    test_no_colour_option "${SCRIPT_UNDER_TEST}"
}

@test "Template handles -n, --no-colour option" {
    test_no_colour_option "${SCRIPT_UNDER_TEST_2}"
}

@test "Script handles -l. --log-level option" {
    test_log_level_option "${SCRIPT_UNDER_TEST}"
}

@test "Template handles -l. --log-level option" {
    test_log_level_option "${SCRIPT_UNDER_TEST_2}"
}

@test "Script handles -q, --quiet option" {
    test_quiet_option "${SCRIPT_UNDER_TEST}"
}

@test "Template handles -q, --quiet option" {
    test_quiet_option "${SCRIPT_UNDER_TEST_2}"
}

@test "Script handles -t, --timestamp option" {
    test_timestamp_option "${SCRIPT_UNDER_TEST}"
}

@test "Template handles -t, --timestamp option" {
    test_timestamp_option "${SCRIPT_UNDER_TEST_2}"
}

@test "Script fails with invalid option" {
    test_invalid_option "${SCRIPT_UNDER_TEST}"
}

@test "Template fails with invalid option" {
    test_invalid_option "${SCRIPT_UNDER_TEST_2}"
}

@test "Script creates and releases lock" {
    test_lock_functionality "${SCRIPT_UNDER_TEST}"
}

@test "Template creates and releases lock" {
    test_lock_functionality "${SCRIPT_UNDER_TEST_2}"
}

@test "Script fails when lock already exists" {
    test_lock_conflict "${SCRIPT_UNDER_TEST}"
}

@test "Template fails when lock already exists" {
    test_lock_conflict "${SCRIPT_UNDER_TEST_2}"
}

@test "Script DEBUG environment variable enables trace output" {
    test_debug_environment "${SCRIPT_UNDER_TEST}"
}

@test "Template DEBUG environment variable enables trace output" {
    test_debug_environment "${SCRIPT_UNDER_TEST_2}"
}

@test "Internal: Script _option_ variables default values are initialized" {
    test_internal_option_defaults "${SCRIPT_UNDER_TEST}"
}

@test "Internal: Template _option_ variables default values are initialized" {
    test_internal_option_defaults "${SCRIPT_UNDER_TEST_2}"
}

@test "Internal: Script _option_ variables are initialized correctly" {
    test_internal_option_initialization "${SCRIPT_UNDER_TEST}"
}

@test "Internal: Template _option_ variables are initialized correctly" {
    test_internal_option_initialization "${SCRIPT_UNDER_TEST_2}"
}

@test "Internal: Script _option_ variables are read-only" {
    test_internal_option_readonly "${SCRIPT_UNDER_TEST}"
}

@test "Internal: Template _option_ variables are read-only" {
    test_internal_option_readonly "${SCRIPT_UNDER_TEST_2}"
}

@test "Internal: Script dynamic option extraction works correctly" {
    test_internal_dynamic_option_extraction "${SCRIPT_UNDER_TEST}"
}

@test "Internal: Template dynamic option extraction works correctly" {
    test_internal_dynamic_option_extraction "${SCRIPT_UNDER_TEST_2}"
}

# =============================== CUSTOM TESTS =============================== #
