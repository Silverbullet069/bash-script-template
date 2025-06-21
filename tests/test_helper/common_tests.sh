#!/usr/bin/env bash

# shellcheck disable=SC2154

# Common test functions for bash script testing
# This library contains reusable test functions that can be shared across multiple test files
# NOTE: Many basic assertions are already provided by bats-assert and bats-file libraries

# Test basic script execution without arguments
test_script_runs_without_arguments() {
    local -r script_path="$1"
    run "${script_path}"
    assert_success
}

# Test help option functionality
test_help_option() {
    local -r script_path="$1"
    shift

    run "${script_path}" --help
    assert_success
    assert_output --partial "Usage:"
    assert_output --partial "Options:"

    run "${script_path}" -h
    assert_success
    assert_output --partial "Usage:"
    assert_output --partial "Options:"
}

# Test no-colour option functionality
test_no_colour_option() {
    local -r script_path="$1"
    shift

    # First run with color
    run "${script_path}"
    assert_success
    local output_with_color="${output}"

    # Different output expected (no ANSI codes in no-colour mode)
    run "${script_path}" --no-colour
    assert_success
    assert_not_equal "${output_with_color}" "${output}"

    run "${script_path}" -n
    assert_success
    assert_not_equal "${output_with_color}" "${output}"
}

# Test log level option functionality
test_log_level_option() {
    local -r script_path="$1"

    run "${script_path}" --log-level ERR
    assert_success
    assert_output --partial "This is an error message"
    refute_output --partial "This is a warning message"
    refute_output --partial "This is an info message"
    refute_output --partial "This is a debug message"

    run "${script_path}" --log-level WRN
    assert_success
    assert_output --partial "This is an error message"
    assert_output --partial "This is a warning message"
    refute_output --partial "This is an info message"
    refute_output --partial "This is a debug message"

    run "${script_path}" --log-level INF
    assert_success
    assert_output --partial "This is an error message"
    assert_output --partial "This is a warning message"
    assert_output --partial "This is an info message"
    refute_output --partial "This is a debug message"

    run "${script_path}" --log-level DBG
    assert_output --partial "This is an error message"
    assert_output --partial "This is a warning message"
    assert_output --partial "This is an info message"
    assert_output --partial "This is a debug message"

    run "${script_path}" # ignore option
    assert_output --partial "This is an error message"
    assert_output --partial "This is a warning message"
    assert_output --partial "This is an info message"
    refute_output --partial "This is a debug message"

    run "${script_path}" -l ERR
    assert_success
    assert_output --partial "This is an error message"
    refute_output --partial "This is a warning message"
    refute_output --partial "This is an info message"
    refute_output --partial "This is a debug message"
}

# Test quiet option functionality
test_quiet_option() {
    local -r script_path="$1"

    run "${script_path}" --quiet
    assert_success
    refute_output

    run "${script_path}" -q
    assert_success
    refute_output
}

# Test timestamp option functionality
test_timestamp_option() {
    local -r script_path="$1"

    run "${script_path}" --timestamp
    assert_success
    # Timestamp format [YYYY-MM-DD HH:MM:SS +ZZZZ]
    assert_output --regexp '\[[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2} [+-][0-9]{4}\]'

    run "${script_path}" -t
    assert_success
    # Timestamp format [YYYY-MM-DD HH:MM:SS +ZZZZ]
    assert_output --regexp '\[[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2} [+-][0-9]{4}\]'
}

# Test invalid option handling
test_invalid_option() {
    local -r script_path="$1"

    run "${script_path}" --invalid-option
    assert_failure
    assert_output --partial "receives invalid arguments: --invalid-option"
}

# Test lock creation and release
test_lock_functionality() {
    local -r script_path="$1"
    local -r script_name="$(basename "$1")"

    run "${script_path}"
    assert_success
    assert_output --partial "Acquired script lock:"
    assert_dir_not_exists "/tmp/${script_name}.${UID}.lock"
}

# Test lock conflict handling
test_lock_conflict() {
    local -r script_path="$1"
    local -r script_name="$(basename "$1")"

    # Create lock directory manually
    mkdir -p "/tmp/${script_name}.${UID}.lock"

    run "${script_path}"
    assert_failure
    assert_output --partial "Unable to acquire script lock"

    # Manual cleanup
    rmdir "/tmp/${script_name}.${UID}.lock"
}

# Test DEBUG environment variable
test_debug_environment() {
    local -r script_path="$1"

    # Run the script with DEBUG=1
    DEBUG=1 run "${script_path}"

    # Should run without errors
    assert_success
    assert_output --partial "+"
}

# Test internal option variables default values
test_internal_option_defaults() {
    local -r script_path="$1"

    # Source the script to access internal functions
    # shellcheck disable=SC1090
    source "${script_path}"

    # Test that parse_params initializes variables
    parse_params

    # Check that variables are set
    # shellcheck disable=SC2154
    assert_equal "${_option_log_level}" "INF"
    # shellcheck disable=SC2154
    assert_equal "${_option_no_colour}" ""
    # shellcheck disable=SC2154
    assert_equal "${_option_quiet}" ""
    # shellcheck disable=SC2154
    assert_equal "${_option_timestamp}" ""
}

# Test internal option variables initialization
test_internal_option_initialization() {
    local -r script_path="$1"

    # Source the script to access internal functions
    # shellcheck disable=SC1090
    source "${script_path}"

    # Test that parse_params initializes variables
    parse_params --log-level ERR --no-colour --quiet --timestamp

    # Check that variables are set
    assert_equal "${_option_log_level}" "ERR"
    assert_equal "${_option_no_colour}" "true"
    assert_equal "${_option_quiet}" "true"
    assert_equal "${_option_timestamp}" "true"
}

# Test internal option variables are read-only
test_internal_option_readonly() {
    local -r script_path="$1"

    # Try to modify read-only variables and capture stderr
    run bash -c "source \"${script_path}\"; parse_params; _option_log_level=\"ERR\" 2>&1"
    assert_output --partial "_option_log_level: readonly variable"

    run bash -c "source \"${script_path}\"; parse_params; _option_no_colour=1 2>&1"
    assert_output --partial "_option_no_colour: readonly variable"

    run bash -c "source \"${script_path}\"; parse_params; _option_quiet=1 2>&1"
    assert_output --partial "_option_quiet: readonly variable"

    run bash -c "source \"${script_path}\"; parse_params; _option_timestamp=1 2>&1"
    assert_output --partial "_option_timestamp: readonly variable"
}

test_internal_dynamic_option_extraction() {
    # Test that help_options array is populated correctly
    # shellcheck disable=SC1090
    run bash -c 'source "${SCRIPT_UNDER_TEST}"; parse_params; printf "%s\n" "${help_options[@]}"'
    assert_success
    assert_output --partial "Specify log level"
    assert_output --partial "Disables colour output"
    assert_output --partial "Run silently"
    assert_output --partial "Enables timestamp"
    assert_output --partial "Displays this help"
}
