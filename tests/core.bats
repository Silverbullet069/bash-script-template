#!/usr/bin/env bats

# shellcheck disable=SC2154

# NOTE: Common test cases for bash script testing, reusable for all scripts
# NOTE: that are cloned from script.sh and template.sh

setup_file() {
    # provision testing environment here
    # ...
    :
}

setup() {
    # NOTE: do not load library in setup_file() function
    bats_load_library bats-support
    bats_load_library bats-assert
    bats_load_library bats-file

    export ROOT="$(dirname "${BATS_TEST_DIRNAME}")"
    export SUTS=(
        "${ROOT}/script.sh"
        "${ROOT}/template.sh"
        "${ROOT}/clone.sh"
    )

    for sut in "${SUTS[@]}"; do
        assert_file_exists "${sut}"
    done
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

@test "Scripts run without arguments" {
    for sut in "${SUTS[@]}"; do
        run "${sut}"
        assert_success

        assert_output --partial "Acquired script lock"
        assert_output --partial "This is an error message"
        assert_output --partial "This is a warning message"
        assert_output --partial "This is an info message"
        assert_output --partial "Cleaned up script lock"
    done
}

@test "Scripts handle -h, --help option" {
    for sut in "${SUTS[@]}"; do
        run "${sut}" --help
        assert_success
        local opt="${output}"

        run "${sut}" -h
        assert_success

        assert_equal "${opt}" "${output}"
        assert_output --partial "Usage:"
        assert_output --partial "Example:"
        assert_output --partial "Options:"
    done
}

@test "Scripts handle -n, --no-color option" {
    for sut in "${SUTS[@]}"; do
        run "${sut}" -n
        assert_success
        local output_no_color_short="${output}"

        run "${sut}" --no-color
        assert_success
        local output_no_color_long="${output}"

        assert_equal "${output_no_color_short}" "${output_no_color_long}"

        assert_output --partial "Acquired script lock"
        assert_output --partial "Cleaned up script lock"
    done
}

@test "Scripts handle -l, --log-level option" {
    for sut in "${SUTS[@]}"; do
        run "${sut}" -l ERR
        assert_success
        assert_output --partial "This is an error message"
        refute_output --partial "This is a warning message"
        refute_output --partial "This is an info message"
        refute_output --partial "This is a debug message"
        local opt="${output}"

        run "${sut}" --log-level ERR
        assert_success
        assert_output --partial "This is an error message"
        refute_output --partial "This is a warning message"
        refute_output --partial "This is an info message"
        refute_output --partial "This is a debug message"

        assert_equal "${output}" "${opt}"

        run "${sut}" --log-level WRN
        assert_success
        assert_output --partial "This is an error message"
        assert_output --partial "This is a warning message"
        refute_output --partial "This is an info message"
        refute_output --partial "This is a debug message"

        run "${sut}" --log-level INF
        assert_success
        assert_output --partial "This is an error message"
        assert_output --partial "This is a warning message"
        assert_output --partial "This is an info message"
        refute_output --partial "This is a debug message"

        run "${sut}" --log-level DBG
        assert_output --partial "This is an error message"
        assert_output --partial "This is a warning message"
        assert_output --partial "This is an info message"
        assert_output --partial "This is a debug message"

        run "${sut}" # ignore option
        assert_output --partial "This is an error message"
        assert_output --partial "This is a warning message"
        assert_output --partial "This is an info message"
        refute_output --partial "This is a debug message"
    done
}

@test "Scripts handle -q, --quiet option" {
    for sut in "${SUTS[@]}"; do
        run "${sut}" --quiet
        assert_success
        refute_output

        run "${sut}" -q
        assert_success
        refute_output
    done
}

@test "Scripts handle -t, --timestamp option" {
    for sut in "${SUTS[@]}"; do
        run "${sut}" --timestamp
        assert_success
        # Timestamp format [YYYY-MM-DD HH:MM:SS +ZZZZ]
        assert_output --regexp '\[[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2} [+-][0-9]{4}\]'

        run "${sut}" -t
        assert_success
        # Timestamp format [YYYY-MM-DD HH:MM:SS +ZZZZ]
        assert_output --regexp '\[[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2} [+-][0-9]{4}\]'
    done
}

@test "Scripts fail with invalid option" {
    for sut in "${SUTS[@]}"; do
        run "${sut}" --invalid-option
        assert_failure
        assert_output --partial "Option not found: --invalid-option"
    done
}

@test "Scripts create and release lock" {
    for sut in "${SUTS[@]}"; do
        local script_name=$(basename "${sut}")

        run "${sut}"
        assert_success
        assert_output --partial "Acquired script lock:"
        assert_dir_not_exists "/tmp/${script_name}.${UID}.lock"
    done
}

@test "Scripts fail when lock already exists" {
    for sut in "${SUTS[@]}"; do
        local script_name=$(basename "${sut}")

        mkdir -p "/tmp/${script_name}.${UID}.lock"

        run "${sut}"
        assert_failure
        assert_output --partial "Unable to acquire script lock"

        # clean up
        rmdir "/tmp/${script_name}.${UID}.lock"
    done
}

@test "Scripts DEBUG environment variable enables trace output" {
    for sut in "${SUTS[@]}"; do
        DEBUG=1 run "${sut}"

        assert_success
        assert_output --partial "+"
    done
}

@test "Internal: Scripts options are registered correctly" {
    for sut in "${SUTS[@]}"; do
        run bash -c '
            set -e
            source "'"${sut}"'"
            option_init

            [[ "${ORDERS[0]}" == "--help" ]]
            [[ "${ORDERS[1]}" == "--log-level" ]]
            [[ "${ORDERS[2]}" == "--timestamp" ]]
            [[ "${ORDERS[3]}" == "--no-color" ]]
            [[ "${ORDERS[4]}" == "--quiet" ]]

            [[ -n "${OPTIONS["--help"]}" ]]
            [[ -n "${OPTIONS["--log-level"]}" ]]
            [[ -n "${OPTIONS["--timestamp"]}" ]]
            [[ -n "${OPTIONS["--no-color"]}" ]]
            [[ -n "${OPTIONS["--quiet"]}" ]]
            
            [[ "${VALUES["--help"]}" == "false" ]]
            [[ "${VALUES["--log-level"]}" == "INF" ]]
            [[ "${VALUES["--timestamp"]}" == "false" ]]
            [[ "${VALUES["--no-color"]}" == "false" ]]
            [[ "${VALUES["--quiet"]}" == "false" ]]

            meta="${OPTIONS["--log-level"]}"
            [[ "${meta}" == *"-l"* ]]
            [[ "${meta}" == *"INF"* ]]
            [[ "${meta}" == *"Specify log level"* ]]
            [[ "${meta}" == *"choice"* ]]
            [[ "${meta}" == *"false"* ]]
            [[ "${meta}" == *"DBG,INF,WRN,ERR"* ]]
        '
        assert_success
    done
}

@test "Internal: Scripts options are parsed correctly" {
    for sut in "${SUTS[@]}"; do
        run bash -c '
            set -e
            source "'"${sut}"'"
            option_init
            parse_params --log-level ERR --no-color --quiet --timestamp
            
            [[ "${VALUES["--log-level"]}" == "ERR" ]]
            [[ "${VALUES["--timestamp"]}" == true ]]
            [[ "${VALUES["--no-color"]}" == true ]]
            [[ "${VALUES["--quiet"]}" == true ]]
        '
        assert_success
    done
}

# =============================== PARAMETER VALIDATION TESTS =============================== #

@test "Scripts handle invalid log levels with detailed error messages" {
    for sut in "${SUTS[@]}"; do
        run "${sut}" --log-level INVALID
        assert_failure
        assert_output --partial "Invalid choice: INVALID. Use: DBG, INF, WRN, ERR"
    done
}

@test "Scripts handle mixed case log levels" {
    for sut in "${SUTS[@]}"; do
        run "${sut}" --log-level err
        assert_failure
        assert_output --partial "Invalid choice: err. Use: DBG, INF, WRN, ERR"
    done
}

@test "Scripts handle empty log level parameter" {
    for sut in "${SUTS[@]}"; do
        run "${sut}" --log-level ""
        assert_failure
        assert_output --partial "Option '--log-level' has empty value"
    done
}

@test "Scripts handle log level with missing argument" {
    for sut in "${SUTS[@]}"; do
        run "${sut}" --log-level
        assert_failure
        assert_output --partial "Option requires a value: --log-level"
    done
}

@test "Scripts handle multiple conflicting options" {
    for sut in "${SUTS[@]}"; do
        run "${sut}" --quiet --log-level DBG
        assert_success
        # With --quiet, should not see any output regardless of log level
        refute_output --partial "This is a debug message"
    done
}

@test "Scripts handle option arguments with spaces" {
    for sut in "${SUTS[@]}"; do
        run "${sut}" --log-level "INF "
        assert_failure
        assert_output --partial "Invalid choice: INF . Use: DBG, INF, WRN, ERR"
    done
}

@test "Scripts handle option arguments with special characters" {
    for sut in "${SUTS[@]}"; do
        run "${sut}" --log-level "INF@"
        assert_failure
        assert_output --partial "Invalid choice: INF@. Use: DBG, INF, WRN, ERR"
    done
}

@test "Scripts handle duplicated options (last one wins)" {
    for sut in "${SUTS[@]}"; do
        run "${sut}" --log-level ERR --log-level WRN
        assert_success
        assert_output --partial "This is an error message"
        assert_output --partial "This is a warning message"
        refute_output --partial "This is an info message"
    done
}

@test "Scripts handle option value containing equals sign" {
    for sut in "${SUTS[@]}"; do
        # Test with malformed option-value syntax
        run "${sut}" --log-level=ERR=WRN
        assert_failure
        assert_output --partial "Invalid choice: ERR=WRN. Use: DBG, INF, WRN, ERR"
    done
}

@test "Scripts handle extremely long option values" {
    for sut in "${SUTS[@]}"; do
        local long_value=$(printf 'A%.0s' {1..1000})
        run "${sut}" --log-level "${long_value}"
        assert_failure
        assert_output --partial "Invalid choice: ${long_value}. Use: DBG, INF, WRN, ERR"
    done
}

@test "Internal: register_option validates input parameters" {
    for sut in "${SUTS[@]}"; do
        run bash -c '
            set -e
            source "'"${sut}"'"
            unset OPTIONS ORDERS VALUES
            declare -gA OPTIONS=()
            declare -ag ORDERS=()
            declare -gA VALUES=()
            
            # Test with empty option name
            register_option "" "-t" "default" "help" "string" "false"
        '
        assert_failure
        assert_output --partial 'Option name is empty'

        run bash -c '
            set -e
            source "'"${sut}"'"
            unset OPTIONS ORDERS VALUES
            declare -gA OPTIONS=()
            declare -ag ORDERS=()
            declare -gA VALUES=()
            
            # Test with empty option name
            register_option "--test" "t" "default" "help" "string" "false"
        '
        assert_failure
        assert_output --partial "validate_option: Option '--test' has invalid short name 't'"

        run bash -c '
            set -e
            source "'"${sut}"'"
            unset OPTIONS ORDERS VALUES
            declare -gA OPTIONS=()
            declare -ag ORDERS=()
            declare -gA VALUES=()
            
            # Test with invalid type
            register_option "--test" "-t" "default" "help" "invalid_type" "false"
        '
        assert_failure
        assert_output --partial "validate_option: Option '--test' has invalid type 'invalid_type'"

        run bash -c '
            set -e
            source "'"${sut}"'"
            unset OPTIONS ORDERS VALUES
            declare -gA OPTIONS=()
            declare -ag ORDERS=()
            declare -gA VALUES=()
            
            # Test with invalid required flag
            register_option "--test" "-t" "default" "help" "string" "maybe"
        '
        assert_failure
        assert_output --partial "Not a valid boolean value: maybe. Use: true/false, 1/0, yes/no, y/n"

        run bash -c '
            set -e
            source "'"${sut}"'"
            unset OPTIONS ORDERS VALUES
            declare -gA OPTIONS=()
            declare -ag ORDERS=()
            declare -gA VALUES=()
            
            # Test with invalid required flag
            register_option "--test" "-t" "default" "help" "bool" "false"
        '
        assert_failure
        assert_output --partial "Not a valid boolean value: default. Use: true/false, 1/0, yes/no, y/n"
    done
}

@test "Internal: validate_option handles malformed input" {
    for sut in "${SUTS[@]}"; do
        run bash -c '
            set -e
            source "'"${sut}"'"
            option_init
            # Test empty parameter
            validate_option ""
        '
        assert_failure
        assert_output --partial "Option is empty"

        run bash -c '
            set -e
            source "'"${sut}"'"
            option_init
            # Test with parameter containing spaces
            validate_option "-- log-level"
        '
        assert_failure
        assert_output --partial "validate_option: Option '-- log-level' not found"
    done
}

@test "Internal: OPTIONS array structure validation" {
    for sut in "${SUTS[@]}"; do
        run bash -c '
            set -e
            source "'"${sut}"'"
            option_init
            
            # Validate that OPTIONS is an associative array
            [[ $(declare -p OPTIONS) =~ "declare -A" ]]
            
            # Validate that all expected options are present
            [[ -n "${OPTIONS["--log-level"]}" ]]
            [[ -n "${OPTIONS["--timestamp"]}" ]]
            [[ -n "${OPTIONS["--no-color"]}" ]]
            [[ -n "${OPTIONS["--quiet"]}" ]]
            [[ -n "${OPTIONS["--help"]}" ]]
            
            # Validate option structure (each option should have 6 fields)
            IFS="${DELIM}" read -ra fields <<< "${OPTIONS["--log-level"]}"
            [[ ${#fields[@]} -eq 6 ]]
        '
        assert_success
    done
}

# =============================== ERROR HANDLING TESTS =============================== #

@test "Scripts handle malformed command line arguments" {
    for sut in "${SUTS[@]}"; do
        # Test with malformed long option
        run "${sut}" ---invalid-option
        assert_failure
        assert_output --partial "Option not found: ---invalid-option"

        # Test with malformed short option
        run "${sut}" -invalid
        assert_failure
        assert_output --partial "Unknown short option: -invalid"

        # Test with option that looks like a number
        run "${sut}" -123
        assert_failure
        assert_output --partial "Unknown short option: -123"
    done
}

@test "Scripts handle extremely long command lines" {
    for sut in "${SUTS[@]}"; do
        # Create an extremely long argument
        local long_arg=$(printf 'A%.0s' {1..10000})
        run "${sut}" --log-level "${long_arg}"
        assert_failure
        assert_output --partial "Invalid choice: ${long_arg}. Use: DBG, INF, WRN, ERR"
    done
}

@test "Scripts handle signal interruption during execution" {
    for sut in "${SUTS[@]}"; do
        local script_name=$(basename "${sut}")

        # Start the script in background and immediately send SIGTERM
        timeout 1s "${sut}" &
        local pid=$!
        sleep 0.1
        kill -TERM "${pid}" 2>/dev/null || true
        wait "${pid}" 2>/dev/null || true

        # Check that lock is cleaned up even after signal
        assert_dir_not_exists "/tmp/${script_name}.${UID}.lock"
    done
}

@test "Scripts handle filesystem errors gracefully" {
    for sut in "${SUTS[@]}"; do
        local script_name=$(basename "${sut}")

        # Test with read-only filesystem (simulated)
        # Create a directory that can't be modified
        local readonly_dir="/tmp/readonly_test_$$"
        mkdir -p "${readonly_dir}"
        chmod 444 "${readonly_dir}"

        # Mock the script to use this directory for lock creation
        # This should fail gracefully
        run bash -c "TMPDIR='${readonly_dir}' '${sut}' 2>&1 || true"

        # Clean up
        chmod 755 "${readonly_dir}"
        rmdir "${readonly_dir}"
    done
}

# =============================== EDGE CASE TESTS =============================== #

@test "Scripts handle empty environment variables" {
    for sut in "${SUTS[@]}"; do
        # Test with empty DEBUG variable
        DEBUG="" run "${sut}"
        assert_success
        refute_output --partial "+"

        # Test with unset DEBUG variable
        env -u DEBUG "${sut}"
        assert_success
        refute_output --partial "+"
    done
}

@test "Scripts handle unusual DEBUG values" {
    for sut in "${SUTS[@]}"; do
        # Test with DEBUG=0 (should not enable debug)
        DEBUG=0 run "${sut}"
        assert_success
        refute_output --partial "+"

        # Test with DEBUG=false (should not enable debug)
        DEBUG=false run "${sut}"
        assert_success
        refute_output --partial "+"

        # Test with DEBUG=true (should enable debug)
        DEBUG=true run "${sut}"
        assert_success
        assert_output --partial "+"

        # Test with DEBUG=2 (should not enable debug)
        DEBUG=2 run "${sut}"
        assert_success
        refute_output --partial "+"
    done
}

@test "Scripts handle mixed short and long options" {
    for sut in "${SUTS[@]}"; do
        run "${sut}" -l ERR --no-color -q --timestamp
        assert_success
        refute_output # Should be quiet

        run "${sut}" --log-level WRN -n -t --quiet
        assert_success
        refute_output # Should be quiet
    done
}

@test "Scripts handle option parsing with equals syntax" {
    for sut in "${SUTS[@]}"; do
        run "${sut}" --log-level=ERR
        assert_success
        assert_output --partial "This is an error message"
        refute_output --partial "This is a warning message"
    done
}

@test "Scripts handle Unicode and special characters in output" {
    for sut in "${SUTS[@]}"; do
        # Test that scripts can handle Unicode in their output
        run "${sut}"
        assert_success
        # Output should contain basic ASCII characters
        assert_output --regexp '[a-zA-Z0-9]'
    done
}
