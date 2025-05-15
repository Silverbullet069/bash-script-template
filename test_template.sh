#!/usr/bin/env bats

# Test suite for ${SCRIPT_NAME}

setup() {
    # Save the original working directory
    export ORIGINAL_DIR="${PWD}"
    
    # Save the name of the script that's being tested
    export SCRIPT_NAME="template.sh"

    # Temporary log file path
    export LOG_FILE="/tmp/${SCRIPT_NAME}.log"
}

# Clean up after each test
teardown() {
    # if you accidentally forget to clean inside the test case
    rm -f "${LOG_FILE}"
}

# ============================ CLI Tests ============================

@test "Script runs without arguments" {
    run "${BATS_TEST_DIRNAME}/${SCRIPT_NAME}"
    
    # Should run without errors
    [ "$status" -eq 0 ]
}

@test "Script handles --help option" {
    run "${BATS_TEST_DIRNAME}/${SCRIPT_NAME}" --help
    
    # Should run without errors
    [ "$status" -eq 0 ]
    # Should display usage information
    [[ "$output" == *"Usage:"* ]]
    [[ "$output" == *"Options:"* ]]
}

@test "Script handles -h option (short for --help option)" {
    run "${BATS_TEST_DIRNAME}/${SCRIPT_NAME}" --help
    
    # Should run without errors
    [ "$status" -eq 0 ]
    # Should display usage information
    [[ "$output" == *"Usage:"* ]]
    [[ "$output" == *"Options:"* ]]
}

@test "Script handles --no-colour option" {
    # First run with color to get baseline
    run "${BATS_TEST_DIRNAME}/${SCRIPT_NAME}"
    local -r with_color="$output"
    
    # Then run with --no-colour
    run "${BATS_TEST_DIRNAME}/${SCRIPT_NAME}" --no-colour
    local -r without_color="$output"
    
    # Should run without errors
    [ "$status" -eq 0 ]
    
    # Different output expected (no ANSI codes in no-colour mode)
    # This is a simple way to check if output is different - not perfect but gives an indication
    [ "$with_color" != "$without_color" ]
}

@test "Script handles -n option (short for --no-colour)" {
    run "${BATS_TEST_DIRNAME}/${SCRIPT_NAME}" -n
    
    # Should run without errors
    [ "$status" -eq 0 ]
}

@test "Script handles --log option" {
    # Run the script with --log
    run "${BATS_TEST_DIRNAME}/${SCRIPT_NAME}" --log
    
    # Should run without errors
    [ "$status" -eq 0 ]
    
    # Check that log file was created
    [ -f "${LOG_FILE}" ]
    
    # Clean up
    rm -f "${LOG_FILE}"
}

@test "Script handles -l option (short for --log)" {
    # Run the script with -l
    run "${BATS_TEST_DIRNAME}/${SCRIPT_NAME}" -l
    
    # Should run without errors
    [ "$status" -eq 0 ]
    
    # Log file should be created and not empty
    [ -f "${LOG_FILE}" ]
    [ -s "${LOG_FILE}" ]
    
    # Clean up
    rm -f "${LOG_FILE}"
}

@test "Script handles --quiet option" {
    # Run the script with --quiet
    run "${BATS_TEST_DIRNAME}/${SCRIPT_NAME}" --quiet
    
    # Should run without errors and have no output
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "Script handles -q option (short for --quiet)" {
    # Run the script with -q
    run "${BATS_TEST_DIRNAME}/${SCRIPT_NAME}" -q
    
    # Should run without errors and have no output
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "Script handles --timestamp option" {
    # Run the script with --timestamp
    run "${BATS_TEST_DIRNAME}/${SCRIPT_NAME}" --timestamp
    
    # Should run without errors
    [ "$status" -eq 0 ]
    
    # Should have output with timestamp format [YYYY-MM-DD HH:MM:SS +ZZZZ]
    [[ "$output" =~ \[[0-9]{4}-[0-9]{2}-[0-9]{2}\ [0-9]{2}:[0-9]{2}:[0-9]{2}\ [+-][0-9]{4}\] ]]
}

@test "Script handles -t option (short for --timestamp)" {
    # Run the script with -t
    run "${BATS_TEST_DIRNAME}/${SCRIPT_NAME}" -t
    
    # Should run without errors
    [ "$status" -eq 0 ]
    
    # Should have output with timestamp format
    [[ "$output" =~ \[[0-9]{4}-[0-9]{2}-[0-9]{2}\ [0-9]{2}:[0-9]{2}:[0-9]{2}\ [+-][0-9]{4}\] ]]
}

@test "Script fails with invalid option" {
    # Run the script with an invalid option
    run "${BATS_TEST_DIRNAME}/${SCRIPT_NAME}" --invalid-option
    
    # Should exit with an error
    [ "$status" -eq 1 ]
    
    # Should show an error message
    [[ "$output" == *"Invalid parameter"* ]]
}

@test "Script handles both --timestamp and --log options" {
    # Run the script with multiple options
    run "${BATS_TEST_DIRNAME}/${SCRIPT_NAME}" --timestamp --log
    
    # Should run without errors
    [ "$status" -eq 0 ]
    
    # Should have timestamp in output
    [[ "$output" =~ \[[0-9]{4}-[0-9]{2}-[0-9]{2}\ [0-9]{2}:[0-9]{2}:[0-9]{2}\ [+-][0-9]{4}\] ]]
    
    # Check that log file was created
    [ -f "${LOG_FILE}" ]
    
    # Clean up
    rm -f "${LOG_FILE}"
}

@test "Script handles both --quiet and --log options" {
    # Run with both quiet and log options
    run "${BATS_TEST_DIRNAME}/${SCRIPT_NAME}" --quiet --log
    
    # Should run without errors
    [ "$status" -eq 0 ]
    
    # Should have no output
    [ -z "$output" ]
    
    # But should still create a non-empty log file
    [ -f "${LOG_FILE}" ]
    [ -s "${LOG_FILE}" ]

    # Clean up
    rm -f "${LOG_FILE}"
}

@test "Script creates and releases lock" {
    # Run the script
    run "${BATS_TEST_DIRNAME}/${SCRIPT_NAME}"
    
    # Should run without errors
    [ "$status" -eq 0 ]
    
    # Check that lock directory doesn't exist after script completion
    [ ! -d "/tmp/${SCRIPT_NAME}.${UID}.lock" ]
}

@test "Script fails when lock already exists" {
    # Create lock directory manually
    mkdir -p "/tmp/${SCRIPT_NAME}.${UID}.lock"
    
    # Run the script
    run "${BATS_TEST_DIRNAME}/${SCRIPT_NAME}"
    
    # Should exit with an error
    [ "$status" -eq 1 ]
    
    # Should show an error message about lock
    [[ "$output" == *"Unable to acquire script lock"* ]]
    
    # Clean up
    rmdir "/tmp/${SCRIPT_NAME}.${UID}.lock"
}

@test "Script DEBUG environment variable enables trace output" {
    # Run the script with DEBUG=1
    DEBUG=1 run "${BATS_TEST_DIRNAME}/${SCRIPT_NAME}"
    
    # Should run without errors
    [ "$status" -eq 0 ]
    
    # Output should contain trace information (bash commands with +)
    [[ "$output" == *"+"* ]]
}