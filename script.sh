#!/usr/bin/env bash

## FILE        : #~NAME~#
## DESCRIPTION : General Bash script template
## CREATED     : #~TIME~#
## TEMVER      : v1.0.0
## TEMRELEASE  : https://github.com/Silverbullet069/bash-script-template/releases/tag/v1.0.0
## AUTHOR      : ralish (https://github.com/ralish/)
## CONTRIBUTOR : Silverbullet069 (https://github.com/Silverbullet069/)
## LICENSE     : MIT License

# ============================================================================ #

# Define all flags in a single location
# NOTE: flag naming convention is snake_case
readonly _SCRIPT_FLAGS=(
    "log_level"
    "no_colour"
    "quiet"
    "timestamp"
    # add your options here...
)

# DESC: Usage help
# ARGS: None
# OUTS: None
# RETS: None
function script_usage() {
    cat << EOF

Usage: #~NAME~# [OPTIONS] ...

Add short description and examples here...

Options:
    -l, --log-level             Specify log levels (DBG, INF, WRN, ERR).
                                Set DEBUG=1 environment variable to turn on Bash debug mode
    -n, --no-colour             Disables colour output
    -q, --quiet                 Run silently unless an error is encountered
    -t, --timestamp             Enables timestamp output
    -h, --help                  Displays this help and exit
EOF
}

# DESC: Parameter parser
# ARGS: $@ (optional): Arguments provided to the script
# OUTS: Variables indicating command-line parameters and options
# RETS: None
function parse_params() {

    # Initialize all flags with empty values
    for flag in "${_SCRIPT_FLAGS[@]}"; do
        declare -g "_flag_${flag}="
    done

    # parse provided arguments
    while [[ $# -gt 0 ]]; do
        local param="${1}"
        shift
        case "${param}" in
            # Built-in options
            -l | --log-level)
                _flag_log_level="${1}"
                shift
                if [[ -z "${LOG_LEVELS[$_flag_log_level]}" ]]; then
                    script_exit "Invalid log level: ${_flag_log_level}. Choose 1 of the following: ${LOG_LEVELS[*]}" 2
                fi
                ;;
            -n | --no-colour)
                _flag_no_colour=true
                ;;
            -q | --quiet)
                _flag_quiet=true
                ;;
            -t | --timestamp)
                _flag_timestamp=true
                ;;
            -h | --help)
                script_usage
                exit 0
                ;;
            *)
                # internal function calling
                if declare -F "${param}" &> /dev/null; then
                    "${param}" "$@"
                    exit 0
                fi
                script_exit "Invalid parameter was provided: $param" 1
                ;;
        esac
    done

    # make the flags read-only
    for flag in "${_SCRIPT_FLAGS[@]}"; do
        readonly "_flag_${flag}"
    done
}

# DESC: Main control flow
# ARGS: $@ (optional): Arguments provided to the script
# OUTS: None
# RETS: None
function main() {
    trap script_trap_err ERR
    trap script_trap_exit EXIT

    script_init "$@"
    parse_params "$@"
    quiet_init
    colour_init
    lock_init user

    # start here
}

# ============================================================================ #
# Helper flags
# ============================================================================ #

# Enable xtrace if the DEBUG environment variable is set
if [[ ${DEBUG-} =~ ^1|yes|true$ ]]; then
    set -o xtrace # Trace the execution of the script (debug)
fi

# Only enable these shell behaviours if we're not being sourced
# Approach via: https://stackoverflow.com/a/28776166/8787985
if ! (return 0 2> /dev/null); then
    # A better class of script...
    set -o errexit  # Exit on most errors (see the manual)
    set -o nounset  # Disallow expansion of unset variables
    set -o pipefail # Use last non-zero exit code in a pipeline
fi

# Enable errtrace or the error trap handler will not work as expected
set -o errtrace # Ensure the error trap handler is inherited

# Make `for f in *.txt` work when `*.txt` matches zero files
shopt -s nullglob globstar

# Set IFS to preferred implementation
# IFS=$' '

# shellcheck source=source.sh
# shellcheck disable=SC1091
source "/home/$USER/LocalRepository/bash-script-template/source.sh"

# Invoke main with args if not sourced
# Approach via: https://stackoverflow.com/a/28776166/8787985
if ! (return 0 2> /dev/null); then
    main "$@"
fi

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
