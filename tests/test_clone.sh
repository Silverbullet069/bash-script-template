#!/usr/bin/env bats

setup_file() {
    # shellcheck disable=SC2154
    export BATS_LIB_PATH="${BATS_TEST_DIRNAME}/test_helper"
    bats_load_library bats-support
    bats_load_library bats-assert
    bats_load_library bats-file

    export SCRIPT_UNDER_TEST=$(realpath "${BATS_TEST_DIRNAME}/../clone_bash_template.sh")
    assert_file_exists "${SCRIPT_UNDER_TEST}"

    # Initialize isolated testing environment
    # shellcheck disable=SC2154
    cp "${SCRIPT_UNDER_TEST}" "${BATS_FILE_TMPDIR}/clone_bash_template.sh"
    assert_file_exists "${BATS_FILE_TMPDIR}/clone_bash_template.sh"

    # Create dependencies inside $BATS_FILE_TMPDIR
    touch "${BATS_FILE_TMPDIR}/source.sh"
    assert_file_exists "${BATS_FILE_TMPDIR}/source.sh"
    assert_file_not_executable "${BATS_FILE_TMPDIR}/source.sh"

    echo '#!/bin/bash' > "${BATS_FILE_TMPDIR}/template.sh"
    assert_file_exists "${BATS_FILE_TMPDIR}/template.sh"

    echo '#!/bin/bash' > "${BATS_FILE_TMPDIR}/template_lite.sh"
    assert_file_exists "${BATS_FILE_TMPDIR}/template_lite.sh"

    echo '#!/bin/bash' > "${BATS_FILE_TMPDIR}/script.sh"
    assert_file_exists "${BATS_FILE_TMPDIR}/script.sh"

    chmod +x \
        "${BATS_FILE_TMPDIR}/clone_bash_template.sh" \
        "${BATS_FILE_TMPDIR}/template.sh" \
        "${BATS_FILE_TMPDIR}/template_lite.sh" \
        "${BATS_FILE_TMPDIR}/script.sh"

    assert_file_executable "${BATS_FILE_TMPDIR}/clone_bash_template.sh"
    assert_file_executable "${BATS_FILE_TMPDIR}/template.sh"
    assert_file_executable "${BATS_FILE_TMPDIR}/template_lite.sh"
    assert_file_executable "${BATS_FILE_TMPDIR}/script.sh"

    export CLONED_SCRIPT="${BATS_FILE_TMPDIR}/clone_bash_template.sh"
}

setup() {
    # shellcheck disable=SC2154
    export BATS_LIB_PATH="${BATS_TEST_DIRNAME}/test_helper"
    bats_load_library bats-support
    bats_load_library bats-assert
    bats_load_library bats-file

    # shellcheck disable=SC2154
    cd "${BATS_TEST_TMPDIR}" || exit 1
}

teardown() {
    :
}

@test "Clone script handles -m, --mode with default -o, --output" {
    # Test default mode (lite) without arguments
    run "${CLONED_SCRIPT}"
    assert_success
    assert_file_exists "${BATS_TEST_TMPDIR}/template_lite.sh"
    assert_file_executable "${BATS_TEST_TMPDIR}/template_lite.sh"

    # Test explicit lite mode
    run "${CLONED_SCRIPT}" -m lite
    assert_success
    assert_file_exists "${BATS_TEST_TMPDIR}/template_lite.sh"
    assert_file_executable "${BATS_TEST_TMPDIR}/template_lite.sh"

    # Test full mode
    run "${CLONED_SCRIPT}" -m full
    assert_success
    assert_file_exists "${BATS_TEST_TMPDIR}/template.sh"
    assert_file_executable "${BATS_TEST_TMPDIR}/template.sh"

    # Test source+script mode
    run "${CLONED_SCRIPT}" -m "source+script"
    assert_success
    assert_file_exists "${BATS_TEST_TMPDIR}/source.sh"
    assert_file_not_executable "${BATS_TEST_TMPDIR}/source.sh"
    assert_file_exists "${BATS_TEST_TMPDIR}/script.sh"
    assert_file_executable "${BATS_TEST_TMPDIR}/script.sh"

    # Verify success messages for multiple files
    assert_output --partial "Successfully copied source.sh"
    assert_output --partial "Successfully copied script.sh"
}

@test "Clone script validates mode parameter" {
    run "${CLONED_SCRIPT}" -m invalid --output "${BATS_TEST_TMPDIR}"
    assert_failure
    assert_output --partial "Invalid template mode: invalid"
    assert_output --partial "Valid values: (full|lite|source+script)"
}

@test "Clone script handles -o, --output option correctly" {
    # Test with directory path
    run "${CLONED_SCRIPT}" --output "${BATS_TEST_TMPDIR}"
    assert_success
    assert_file_exists "${BATS_TEST_TMPDIR}/template_lite.sh"
    assert_file_executable "${BATS_TEST_TMPDIR}/template_lite.sh"

    # Test with .sh file path
    local sh_file="${BATS_TEST_TMPDIR}/custom_template.sh"
    run "${CLONED_SCRIPT}" -o "${sh_file}"
    assert_success
    assert_file_exists "${sh_file}"

    # Test with .bash file path
    local bash_file="${BATS_TEST_TMPDIR}/custom_template.bash"
    run "${CLONED_SCRIPT}" -o "${bash_file}"
    assert_success
    assert_file_exists "${bash_file}"
}

@test "Clone script validates output parameter" {
    # Test with invalid file extension
    run "${CLONED_SCRIPT}" --output "${BATS_TEST_TMPDIR}/invalid.txt"
    assert_failure
    assert_output --partial "Invalid output. Please specify a directory path or a file path with .sh or .bash extension."

    # Test with non-existent directory (should fail)
    run "${CLONED_SCRIPT}" --output "/non/existent/directory"
    assert_failure
    assert_output --partial "Invalid output"
}

@test "Script handles -h, --help option" {
    run "${CLONED_SCRIPT}" --help
    assert_success
    assert_output --partial "Usage:"
    assert_output --partial "Options:"

    run "${CLONED_SCRIPT}" -h
    assert_success
    assert_output --partial "Usage:"
    assert_output --partial "Options:"
}

@test "Clone script handles built-in options" {
    # Test log-level option
    run "${CLONED_SCRIPT}" --log-level ERR --output "${BATS_TEST_TMPDIR}"
    assert_success

    # Test no-colour option
    run "${CLONED_SCRIPT}" --no-colour --output "${BATS_TEST_TMPDIR}"
    assert_success

    # Test quiet option
    run "${CLONED_SCRIPT}" --quiet --output "${BATS_TEST_TMPDIR}"
    assert_success

    # Test timestamp option
    run "${CLONED_SCRIPT}" --timestamp --output "${BATS_TEST_TMPDIR}"
    assert_success
}

@test "Clone script validates log-level parameter" {
    run "${CLONED_SCRIPT}" --log-level INVALID --output "${BATS_TEST_TMPDIR}"
    assert_failure
    assert_output --partial "LOG_LEVELS"
    assert_output --partial "unbound variable"

}

@test "Clone script fails with invalid option" {
    run "${CLONED_SCRIPT}" --invalid-option
    assert_failure
    assert_output --partial "Invalid parameter was provided: --invalid-option"
}

@test "Clone script shows success messages for file operations" {
    run "${CLONED_SCRIPT}" --output "${BATS_TEST_TMPDIR}"
    assert_success
    assert_output --partial "Successfully copied template_lite.sh"
}

@test "Internal: _option_ variables are initialized with correct defaults" {
    # shellcheck disable=SC1090
    run bash -c 'source "${SCRIPT_UNDER_TEST}"; parse_params; echo "mode=${_option_mode}"; echo "log_level=${_option_log_level}"; echo "no_colour=${_option_no_colour}"; echo "quiet=${_option_quiet}"; echo "timestamp=${_option_timestamp}"'
    assert_success
    assert_output --partial "mode=lite"
    assert_output --partial "log_level=INF"
    assert_output --partial "no_colour="
    assert_output --partial "quiet="
    assert_output --partial "timestamp="
}

@test "Internal: _option_ variables are set correctly from parameters" {
    # shellcheck disable=SC1090
    run bash -c 'source "${SCRIPT_UNDER_TEST}"; parse_params --mode full --output "/tmp" --log-level ERR --no-colour --quiet --timestamp; echo "mode=${_option_mode}"; echo "output=${_option_output}"; echo "log_level=${_option_log_level}"; echo "no_colour=${_option_no_colour}"; echo "quiet=${_option_quiet}"; echo "timestamp=${_option_timestamp}"'
    assert_success
    assert_output --partial "mode=full"
    assert_output --partial "output=/tmp"
    assert_output --partial "log_level=ERR"
    assert_output --partial "no_colour=1"
    assert_output --partial "quiet=1"
    assert_output --partial "timestamp=1"
}

@test "Internal: _option_ variables are read-only after initialization" {
    # Test that variables become read-only after parse_params
    run bash -c 'source "${SCRIPT_UNDER_TEST}"; parse_params; _option_mode="full" 2>&1'
    assert_output --partial "_option_mode: readonly variable"

    run bash -c 'source "${SCRIPT_UNDER_TEST}"; parse_params; _option_output="/tmp" 2>&1'
    assert_output --partial "_option_output: readonly variable"
}

@test "Internal: Dynamic option extraction works correctly" {
    # Test that help_options array is populated correctly
    # shellcheck disable=SC1090
    run bash -c 'source "${SCRIPT_UNDER_TEST}"; parse_params; printf "%s\n" "${help_options[@]}"'
    assert_success
    assert_output --partial "Specify template mode"
    assert_output --partial "Specify output directory"
    assert_output --partial "Specify log level"
    assert_output --partial "Disables colour output"
    assert_output --partial "Run silently"
    assert_output --partial "Enables timestamp"
    assert_output --partial "Displays this help"
}
