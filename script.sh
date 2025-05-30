#!/usr/bin/env bash

## FILE        : #~NAME~#
## DESCRIPTION : General Bash script template
## CREATED     : #~TIME~#
## TEMVER      : #~VERSION~#
## AUTHOR      : ralish (https://github.com/ralish/)
## CONTRIBUTOR : Silverbullet069 (https://github.com/Silverbullet069/)
## LICENSE     : MIT License

# ============================================================================ #

# DESC: Parameter parser
# ARGS: $@ (optional): Arguments provided to the script
# OUTS: Variables indicating command-line parameters and options
# RETS: None
function parse_params() {

    # Extract options dynamically from parse_params function

    # shellcheck disable=SC2016,SC2312
    local -r parse_params_content=$(declare -f parse_params | sed -En '/[[:space:]]+case "\$\{param\}" in/,/[[:space:]]+esac;/p' | sed '1d;$d')

    # debug "${parse_params_content}"

    if [[ -z "${parse_params_content-}" ]]; then
        script_exit "Can't extract content from parse_params() function. Check the regex." 1
    fi

    local flags=()
    while IFS= read -r line; do
        # NOTE: Extract long option only and convert hyphens to underscores
        if [[ $line =~ ^[[:space:]]*-([a-z])\ \|\ --([a-z-]+)\)$ ]]; then
            flags+=("${BASH_REMATCH[2]//-/_}")
        elif [[ $line =~ ^[[:space:]]*--([a-z-]+)\)$ ]]; then
            flags+=("${BASH_REMATCH[1]//-/_}")
        fi
    done <<< "${parse_params_content}"

    # Check if flags array is empty
    if [[ ${#flags[@]} -eq 0 ]]; then
        script_exit "No valid flags found in parse_params() function. Check the function implementation." 1
    fi

    # parse provided arguments
    while [[ $# -gt 0 ]]; do
        local param="${1}"
        shift
        case "${param}" in
            # Add your options here
            # ...

            # Built-in options
            # NOTE: Write the short description of your options by starting
            # NOTE: a comment with triple sharps ###
            # NOTE: You can write multiple comment lines
            -l | --log-level)
                ### Specify log level. Valid values: DBG, INF, WRN, ERR
                ### Add DEBUG=1 to turn on Bash debug mode
                _flag_log_level="${1}"
                shift
                if [[ -z "${LOG_LEVELS[$_flag_log_level]}" ]]; then
                    script_exit "Invalid log level: ${_flag_log_level}. Choose 1 of the following: ${LOG_LEVELS[*]}" 2
                fi
                ;;
            -n | --no-colour)
                ### Disables colour output
                _flag_no_colour=true
                ;;
            -q | --quiet)
                ### Run silently unless an error is encountered
                _flag_quiet=true
                ;;
            -t | --timestamp)
                ### Enables timestamp output
                _flag_timestamp=true
                ;;
            -h | --help)
                ### Displays this help and exit
                script_usage
                exit 0
                ;;
            *)
                # internal function calling
                if declare -F "${param}" &> /dev/null && [[ "${_flag_log_level:-DBG}" == "DBG" ]]; then
                    "${param}" "$@"
                    exit 0
                fi
                script_exit "Invalid parameter was provided: ${param}" 1
                ;;
        esac
    done

    # Make the flags read-only
    # Check if flags array is empty and return error
    if [[ ${#flags[@]} -eq 0 ]]; then
        script_exit "No flags found in parse_params() function." 1
    fi

    # Make the flags read-only and check for empty flags
    for flag in "${flags[@]}"; do
        # Check if flag is empty and return error
        if [[ -z "${flag}" ]]; then
            script_exit "Empty flag found in parse_params() function." 1
        fi
        readonly "_flag_${flag}"
    done
}

# DESC: Usage help
# ARGS: None
# OUTS: None
# RETS: None
function script_usage() {
    cat << EOF

Usage: #~NAME~# [OPTIONS] ...

Add short description and examples here...

Options:
EOF
    # Read the source file and extract comments
    local script_file="${BASH_SOURCE[0]}"
    local in_case_block=false
    local current_option=""

    while IFS= read -r line; do
        if [[ $line =~ case.*param.*in ]]; then
            in_case_block=true
            continue
        elif [[ $line =~ esac ]]; then
            in_case_block=false
            continue
        fi

        if [[ $in_case_block == true ]]; then
            # Match option patterns
            if [[ $line =~ ^[[:space:]]*(-[a-z])\ \|\ (--[a-z-]+)\) ]]; then
                current_option="${BASH_REMATCH[1]}, ${BASH_REMATCH[2]}"
            elif [[ $line =~ ^[[:space:]]*(--[a-z-]+)\) ]]; then
                current_option="    ${BASH_REMATCH[1]}"
            elif [[ $line =~ ^[[:space:]]*###[[:space:]](.*) ]]; then
                printf "    %-28s %s\n" "$current_option" "${BASH_REMATCH[1]}"
                current_option=""
            fi
        fi
    done < "$script_file"
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
    info "This is an info message"
    warn "This is a warning message"
    error "This is an error message"
    debug "This is a debug message"
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
source "$(dirname "${BASH_SOURCE[0]}")/source.sh"

# Invoke main with args if not sourced
# Approach via: https://stackoverflow.com/a/28776166/8787985
if ! (return 0 2> /dev/null); then
    main "$@"
fi

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
