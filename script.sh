#!/usr/bin/env bash

## FILE        : #~NAME~#
## DESCRIPTION : General Bash script template
## AUTHOR      : Silverbullet069
## CREATED     : #~TIME~#
## VERSION     : 0.1
## LICENSE     : MIT License
## CREDIT      : https://github.com/ralish/bash-script-template/blob/main/script.sh
## HISTORY
## - v0.1 (#~DATE~#): Added MVP

## ToC:
## - usage()
## - simple_parse_options()
## - main()

# ============================================================================ #

# DESC: Usage help
# ARGS: None
# OUTS: None
# RETS: None
function usage() {
    cat << EOF

#~NAME~# [-c] [-nc] [-nt]

Usage:
    -h|--help                 Displays this help
    -q|--quiet                Run silently unless we encounter an error
    -c|--no-color             Disables color output
    -t|--no-timestamp         Disables timestamp output
    -s|--save-log             Save terminal output to log file
EOF
}

# DESC: Parameter parser
# ARGS: $@ (optional): Arguments provided to the script
# OUTS: Variables indicating command-line parameters and options
# RETS: None
function simple_parse_options() {

    while [[ $# -gt 0 ]]; do
        local _param="$1"
        shift
        case $_param in
            -h | --help)
                usage
                exit 0
                ;;
            -q | --quiet)
                readonly QUIET=1
                ;;
            -c | --no-color)
                readonly NO_COLOR=1
                ;;
            -t | --no-timestamp)
                readonly NO_TIMESTAMP=1
                ;;
            -s | --save-log)
                readonly LOG_FILE="${SCRIPT_DIR}/logs/$(basename "${0%.*}").log"
                if [[ ! -d "$(dirname "$LOG_FILE")" ]]; then
                  local -r _mkdir_log=$(mktemp)
                  mkdir -pv "$(dirname "$LOG_FILE")" | tee "$_mkdir_log"
                  cat "$_mkdir_log" >> "$LOG_FILE"
                  rm "$_mkdir_log"
                fi
                ;;
            *)
                exit_script "Invalid parameter was provided: $_param" 1
                ;;
        esac
    done
}

# DESC: Main control flow
# ARGS: $@ (optional): Arguments provided to the script
# OUTS: None
# RETS: None
function main() {
    trap trap_script_err ERR
    trap trap_script_exit EXIT

    init_script "$@"
    simple_parse_options "$@"
    init_color
    init_quiet
    init_lock user

    # Start Here
}

# ======================================================== #
# Initialize Safety Flags And Run The Main Script          #
# ======================================================== #

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
source "/home/$USER/LocalRepository/bash-script-template/source.sh"

# Invoke main with args if not sourced
# Approach via: https://stackoverflow.com/a/28776166/8787985
if ! (return 0 2> /dev/null); then
    main "$@"
fi

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
