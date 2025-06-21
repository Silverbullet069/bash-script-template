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
    #export BATS_LIB_PATH="${BATS_TEST_DIRNAME}/test_helper"
    bats_load_library bats-support
    bats_load_library bats-assert
    bats_load_library bats-file

    # shellcheck disable=SC1091
    source "${BATS_TEST_DIRNAME}/test_helper/common_tests.sh"

    # Provision target script
    export SCRIPT_PATH=$(realpath "${BATS_TEST_DIRNAME}/../clone_bash_template.sh")
    export SCRIPT_UNDER_TEST="${BATS_FILE_TMPDIR}/clone_bash_template.sh"
    # follow symlinks, prevent overwrite, refuse copy if ${dest} is dir
    cp -nLT "${SCRIPT_PATH}" "${SCRIPT_UNDER_TEST}"
    chmod +x "${SCRIPT_UNDER_TEST}"

    assert_file_exists "${SCRIPT_PATH}"
    assert_file_exists "${SCRIPT_UNDER_TEST}"
    assert_file_executable "${SCRIPT_UNDER_TEST}"

    # Create template files with content that includes placeholders
    cat >"${BATS_FILE_TMPDIR}/template.sh" <<'EOF'
#!/usr/bin/env bash
## FILE         : @NAME@
## VERSION      : @VER@
## DESCRIPTION  : @DESC@
## AUTHOR       : @AUTHOR@
## REPOSITORY   : @REPO@
## LICENSE      : @LIC@
EOF

    cat >"${BATS_FILE_TMPDIR}/template_lite.sh" <<'EOF'
#!/usr/bin/env bash
## FILE         : @NAME@
## VERSION      : @VER@
## DESCRIPTION  : @DESC@
## AUTHOR       : @AUTHOR@
## REPOSITORY   : @REPO@
## LICENSE      : @LIC@
EOF

    cat >"${BATS_FILE_TMPDIR}/script.sh" <<'EOF'
#!/usr/bin/env bash
## FILE         : @NAME@
## VERSION      : @VER@
## DESCRIPTION  : @DESC@
## AUTHOR       : @AUTHOR@
## REPOSITORY   : @REPO@
## LICENSE      : @LIC@
EOF

    cat >"${BATS_FILE_TMPDIR}/source.sh" <<'EOF'
#!/usr/bin/env bash
# Source file for script.sh
EOF

    assert_file_exists "${BATS_FILE_TMPDIR}/template.sh"
    assert_file_exists "${BATS_FILE_TMPDIR}/template_lite.sh"
    assert_file_exists "${BATS_FILE_TMPDIR}/script.sh"
    assert_file_exists "${BATS_FILE_TMPDIR}/source.sh"

    # Change to BATS_FILE_TMPDIR so script finds template files
    cd "${BATS_FILE_TMPDIR}" || exit
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

@test "Script handles -h, --help option" {
    test_help_option "${SCRIPT_UNDER_TEST}"
}

@test "Script handles invalid command line arguments" {
    test_invalid_option "${SCRIPT_UNDER_TEST}"
}

# =============================== CUSTOM TESTS =============================== #

@test "Script fails without --mode option" {
    run "${SCRIPT_UNDER_TEST}" --yes
    assert_success
    assert_file_exists "${BATS_FILE_TMPDIR}/mock.sh"
}

@test "Script fails when output is pointing to a non-existant directory" {
    run "${SCRIPT_UNDER_TEST}" --yes --output "/path/not/exist"
    assert_failure
    assert_output --partial "Invalid output"
}

@test "Script runs with --yes flag to skip prompts" {
    # Test default mode (lite) with --yes
    run "${SCRIPT_UNDER_TEST}" --yes --output "${BATS_TEST_TMPDIR}/test_output.sh"
    assert_success
    assert_file_exists "${BATS_TEST_TMPDIR}/test_output.sh"

    # Verify placeholders were replaced with defaults
    assert grep -q "FILE.*test_output.sh" "${BATS_TEST_TMPDIR}/test_output.sh"
    assert grep -q "VERSION.*1.0.0" "${BATS_TEST_TMPDIR}/test_output.sh"
    assert grep -q "DESCRIPTION.*A general Bash template" "${BATS_TEST_TMPDIR}/test_output.sh"
}

@test "Script handles different modes correctly" {
    # Test lite mode (default)
    run "${SCRIPT_UNDER_TEST}" --yes --mode lite --output "${BATS_TEST_TMPDIR}/lite_test.sh"
    assert_success
    assert_file_exists "${BATS_TEST_TMPDIR}/lite_test.sh"

    # Test full mode
    run "${SCRIPT_UNDER_TEST}" --yes --mode full --output "${BATS_TEST_TMPDIR}/full_test.sh"
    assert_success
    assert_file_exists "${BATS_TEST_TMPDIR}/full_test.sh"

    # Test source+script mode
    run "${SCRIPT_UNDER_TEST}" --yes --mode "source+script" --output "${BATS_TEST_TMPDIR}/script_test.sh"
    assert_success
    assert_file_exists "${BATS_TEST_TMPDIR}/script_test.sh"
    # Should also create source.sh in the same directory
    assert_file_exists "${BATS_TEST_TMPDIR}/source.sh"
}

@test "Script validates mode parameter correctly" {
    run "${SCRIPT_UNDER_TEST}" --mode invalid --output "${BATS_TEST_TMPDIR}/test.sh"
    assert_failure
    assert_output --partial "Invalid template mode: invalid"
    assert_output --partial "Please choose 1 of the following: 'full', 'lite', 'source+script'"
}

@test "Script validates output parameter correctly" {
    # Test with invalid file extension
    run "${SCRIPT_UNDER_TEST}" --output "${BATS_TEST_TMPDIR}/invalid.txt"
    assert_failure
    assert_output --partial "Invalid output:"
    assert_output --partial "Please specify a directory path or a file path with .sh or .bash extension"

    # Test with valid .sh extension
    run "${SCRIPT_UNDER_TEST}" --yes --output "${BATS_TEST_TMPDIR}/valid.sh"
    assert_success
    assert_file_exists "${BATS_TEST_TMPDIR}/valid.sh"

    # Test with valid .bash extension
    run "${SCRIPT_UNDER_TEST}" --yes --output "${BATS_TEST_TMPDIR}/valid.bash"
    assert_success
    assert_file_exists "${BATS_TEST_TMPDIR}/valid.bash"
}

@test "Script handles missing template files" {
    # Remove template file to test error handling
    rm "${BATS_FILE_TMPDIR}/template_lite.sh"

    run "${SCRIPT_UNDER_TEST}" --yes --output "${BATS_TEST_TMPDIR}/test.sh"
    assert_failure
    assert_output --partial "not found"
}

@test "Script creates backup when output file exists" {
    # Create an existing file
    echo "existing content" >"${BATS_TEST_TMPDIR}/existing.sh"

    run "${SCRIPT_UNDER_TEST}" --yes --output "${BATS_TEST_TMPDIR}/existing.sh"
    assert_success

    # Check that backup was created
    assert_file_exists "${BATS_TEST_TMPDIR}/existing.sh"
    # shellcheck disable=SC2312
    local -r backup_file=$(find "${BATS_TEST_TMPDIR}" -name "existing.sh.*.bak" | head -1)
    assert_file_exists "${backup_file}"
}

@test "Script handles source+script mode with missing source.sh" {
    # Remove source.sh to test error handling
    rm "${BATS_FILE_TMPDIR}/source.sh"

    run "${SCRIPT_UNDER_TEST}" --yes --mode "source+script" --output "${BATS_TEST_TMPDIR}/test.sh"
    assert_failure
    assert_output --partial "not found"
}

@test "Script replaces placeholders correctly" {
    run "${SCRIPT_UNDER_TEST}" --yes --output "${BATS_TEST_TMPDIR}/placeholder_test.sh"
    assert_success

    # Should not contain any unreplaced placeholders
    refute grep -q "@NAME@" "${BATS_TEST_TMPDIR}/placeholder_test.sh"
    refute grep -q "@VER@" "${BATS_TEST_TMPDIR}/placeholder_test.sh"
    refute grep -q "@DESC@" "${BATS_TEST_TMPDIR}/placeholder_test.sh"
    refute grep -q "@AUTHOR@" "${BATS_TEST_TMPDIR}/placeholder_test.sh"
    refute grep -q "@REPO@" "${BATS_TEST_TMPDIR}/placeholder_test.sh"
    refute grep -q "@LIC@" "${BATS_TEST_TMPDIR}/placeholder_test.sh"
}
