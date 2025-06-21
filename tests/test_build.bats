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

    # Provision target script
    export SCRIPT_PATH=$(realpath "${BATS_TEST_DIRNAME}/../build.sh")
    export SCRIPT_UNDER_TEST="${BATS_FILE_TMPDIR}/build.sh"
    cp "${SCRIPT_PATH}" "${SCRIPT_UNDER_TEST}"
    chmod +x "${SCRIPT_UNDER_TEST}"

    assert_file_exists "${SCRIPT_PATH}"
    assert_file_exists "${SCRIPT_UNDER_TEST}"
    assert_file_executable "${SCRIPT_UNDER_TEST}"

    # Provision mock script.sh
    cat >"${BATS_FILE_TMPDIR}/script.sh" <<'EOF'
#!/usr/bin/env bash
# Mock header line 1
# Mock header line 2
# Mock header line 3
# Mock header line 4
# Mock header line 5
# Mock header line 6
# Mock header line 7
# Mock header line 8
# Mock header line 9
# Mock header line 10
# Mock header line 11
# Mock header line 12
# Mock header line 13
# Mock header line 14
# Mock header line 15
# Mock header line 16
# Mock header line 17
# shellcheck source=source.sh
# shellcheck disable=SC1091
source "source.sh"
echo "Script body content"
function script_function() {
    echo "Script function"
}
main() {
    echo "Main function"
}
EOF
    assert_file_exists "${BATS_FILE_TMPDIR}/script.sh"

    # Provision mock source.sh
    cat >"${BATS_FILE_TMPDIR}/source.sh" <<'EOF'
#!/usr/bin/env bash
# Source header line 1
# Source header line 2
# Source header line 3
# Source header line 4
# Source header line 5
# Source header line 6
# Source header line 7
# Source header line 8
# Source header line 9
# Source header line 10
# Source header line 11
echo "Source body content"
function source_function() {
    echo "Source function"
}
EOF
    assert_file_exists "${BATS_FILE_TMPDIR}/source.sh"
    assert_file_not_executable "${BATS_FILE_TMPDIR}/source.sh"

    # Provision mock template.sh
    touch "${BATS_FILE_TMPDIR}/template.sh"
    chmod 555 "${BATS_FILE_TMPDIR}/template.sh"
    assert_file_exists "${BATS_FILE_TMPDIR}/template.sh"
    assert_file_permission 555 "${BATS_FILE_TMPDIR}/template.sh"
}

teardown() {
    # Clean up after each test case
    :
}

teardown_file() {
    # Clean up after last test case
    :
}

# =============================== CUSTOM TESTS =============================== #

@test "Script runs without arguments and builds template.sh" {
    run "${SCRIPT_UNDER_TEST}"
    assert_success
    assert_output --partial "Build template.sh successfully."
    assert_file_exists "${BATS_FILE_TMPDIR}/template.sh"

    # Check that template.sh contains header from script.sh
    run grep -q "Mock header line 1" "${BATS_FILE_TMPDIR}/template.sh"
    assert_success
    run grep -q "Mock header line 17" "${BATS_FILE_TMPDIR}/template.sh"
    assert_success

    # Check that template.sh contains body of source.sh
    run grep -q "Source body content" "${BATS_FILE_TMPDIR}/template.sh"
    assert_success
    run grep -q "source_function" "${BATS_FILE_TMPDIR}/template.sh"
    assert_success

    # Check that template.sh contains body of script.sh
    run grep -q "Script body content" "${BATS_FILE_TMPDIR}/template.sh"
    assert_success
    run grep -q "script_function" "${BATS_FILE_TMPDIR}/template.sh"
    assert_success

    # Check that source lines are filtered out
    run cat "${BATS_FILE_TMPDIR}/template.sh"
    refute_output --partial 'shellcheck source=source.sh'
    refute_output --partial 'shellcheck disable=SC1091'
    refute_output --partial 'source "source.sh"'

    # Check that template.sh is read-only and executable
    assert_file_permission 555 "${BATS_FILE_TMPDIR}/template.sh"
}

@test "Script handles missing source.sh" {
    # Remove source.sh to test error handling
    rm "${BATS_FILE_TMPDIR}/source.sh"

    run "${SCRIPT_UNDER_TEST}"
    assert_failure
    assert_output --partial "source.sh not found"
}

@test "Script handles missing script.sh" {
    # Remove script.sh to test error handling
    rm "${BATS_FILE_TMPDIR}/script.sh"

    run "${SCRIPT_UNDER_TEST}"
    assert_failure
    assert_output --partial "script.sh not found"
}
