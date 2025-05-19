#!/usr/bin/env bash

## FILE        : #~NAME~#
## DESCRIPTION : General Bash script template
## CREATED     : #~TIME~#
## AUTHOR      : ralish and Silverbullet069
## LICENSE     : MIT License
## CREDIT      : https://github.com/ralish/bash-script-template/blob/main/script.sh

# ============================================================================ #

# DESC: Usage help
# ARGS: None
# OUTS: None
# RETS: None
function script_usage() {
    cat << EOF

Usage: #~NAME~# [OPTIONS] ...

TODO: Add short description and examples here...

Options:
    -l, --log                   Redirect output to plaintext log file
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
# NOTE: Refrain from type checking, let the lower-level tool do it
function parse_params() {

    # initialize with default values
    _flag_log=
    _flag_no_colour=
    _flag_quiet=
    _flag_timestamp=

    # parse provided arguments
    while [[ $# -gt 0 ]]; do
        local param="${1}"
        shift
        case "${param}" in
            -l | --log)
                _flag_log=true
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
                if declare -F "$param" &>/dev/null; then
                    "$param" "$@"
                    exit 0
                fi
                script_exit "Invalid parameter was provided: $param" 1
                ;;
        esac
    done
}

# DESC: Make parameters globally readonly *after* parsing
# ARGS: None
# OUTS: Read-only variables indicating command-line parameters and options
# RETS: None
function finalize_params() {
    readonly _flag_log
    readonly _flag_no_colour
    readonly _flag_quiet
    readonly _flag_timestamp
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
    finalize_params
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
    set -o xtrace       # Trace the execution of the script (debug)
fi

# Only enable these shell behaviours if we're not being sourced
# Approach via: https://stackoverflow.com/a/28776166/8787985
if ! (return 0 2> /dev/null); then
    # A better class of script...
    set -o errexit      # Exit on most errors (see the manual)
    set -o nounset      # Disallow expansion of unset variables
    set -o pipefail     # Use last non-zero exit code in a pipeline
fi

# Enable errtrace or the error trap handler will not work as expected
set -o errtrace         # Ensure the error trap handler is inherited

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
