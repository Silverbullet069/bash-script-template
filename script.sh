#!/usr/bin/env bash

## FILE        : @NAME@
## VERSION     : v1.0.0
## DESCRIPTION : General Bash script template
## AUTHOR      : Silverbullet069
## REPOSITORY  : @REPO@
## LICENSE     : MIT License

## TEMREPO     : https://github.com/Silverbullet069/bash-script-template
## TEMVER      : v2.3.1
## TEMLIC      : MIT License

# ============================================================================ #

# DESC: Parameter parser
# ARGS: $@ (optional): Arguments provided to the script
# OUTS: Variables indicating command-line parameters and options
# RETS: None
function parse_params() {

    # Extract options dynamically from parse_params function

    # shellcheck disable=SC2016,SC2312
    local script_file="${BASH_SOURCE[0]}"
    local in_case_block=false
    local -A options=()        # associative array
    declare -g help_options=() # indexed array

    while IFS= read -r line; do
        if [[ $line =~ case.*param.*in ]]; then
            in_case_block=true
            continue
        elif [[ $line =~ esac ]]; then
            in_case_block=false
            continue
        fi

        if [[ $in_case_block == true ]]; then

            if [[ $line =~ ^[[:space:]]*-([a-z])[[:space:]]\|[[:space:]]--([a-z-]+)\)$ ]]; then
                option_name="${BASH_REMATCH[2]//-/_}"
                option_help="-${BASH_REMATCH[1]}, --${BASH_REMATCH[2]}"
                options["${option_name}"]= # empty

            elif [[ $line =~ ^[[:space:]]*--([a-z-]+)\)$ ]]; then
                option_name="${BASH_REMATCH[1]//-/_}"
                option_help="    --${BASH_REMATCH[1]}"
                options["${option_name}"]= # empty

            elif [[ $line =~ ^[[:space:]]*###[[:space:]]*(.*)$ ]]; then
                local help_text="${BASH_REMATCH[1]}"

                # Extract default value using a more structured syntax: @DEFAULT:value@
                if [[ $help_text =~ @DEFAULT:([^@]+)@ ]]; then
                    local default_value="${BASH_REMATCH[1]}"
                    # add default value to help
                    option_help+="=${default_value}"
                    options["${option_name}"]="${default_value}"
                    # Remove the placeholder from help text
                    help_text="${help_text/@DEFAULT:${default_value}@/}"
                    help_text="${help_text% }" # trim trailing space
                fi

                # short and long format of the parameter name shouldn't exceeded 25 characters
                help_options+=("$(printf "    %-25s %s\n" "${option_help}" "${help_text}")")
                option_help= # reset
            fi
        fi
    done < "$script_file"

    # Check if options array is empty
    if [[ "${#options[@]}" -eq 0 ]]; then
        script_exit "No valid flags found in parse_params() function. Check the function implementation." 1
    fi

    # Initialize all flags with default value
    for option in "${!options[@]}"; do
        # NOTE: use "_option_*" as prefix
        declare -g "_option_${option}=${options[${option}]}"
    done

    # parse provided arguments
    while [[ $# -gt 0 ]]; do
        local param="${1}"
        shift
        case "${param}" in
            # Add your options here
            # ...

            # Built-in options
            # NOTE: ### comment will be displayed as short description for options in --help output
            -l | --log-level)
                ### Specify log level (DBG|INF|WRN|ERR). @DEFAULT:INF@
                ### Add DEBUG=1 to enable Bash debug mode.

                if [[ -z "${LOG_LEVELS[${1-}]}" ]]; then
                    script_exit "Invalid log level: ${1-}. Choose 1 of the following: ${LOG_LEVELS[*]}" 2
                fi
                _option_log_level="${1}"
                shift
                ;;
            -n | --no-colour)
                ### Disables colour output

                _option_no_colour=1
                ;;
            -q | --quiet)
                ### Run silently unless an error is encountered

                _option_quiet=1
                ;;
            -t | --timestamp)
                ### Enables timestamp output

                _option_timestamp=1
                ;;
            -h | --help)
                ### Displays this help and exit

                script_usage
                exit 0
                ;;
            *)
                script_exit "Invalid parameter was provided: ${param}" 1
                ;;
        esac
    done

    # Check if options array is empty
    if [[ "${#options[@]}" -eq 0 ]]; then
        script_exit "No options found in parse_params() function." 1
    fi

    # Make the options read-only
    for option in "${!options[@]}"; do
        readonly "_option_${option}"
    done
}

# DESC: Usage help
# ARGS: None
# OUTS: None
# RETS: None
function script_usage() {
    cat << EOF

Usage: @NAME@ [OPTIONS] ...

Add short description and examples here...

Options:
$(printf '%s\n' "${help_options[@]-}")
EOF
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
    # shellcheck disable=SC2154
    info "script_params: ${script_params}"
    # shellcheck disable=SC2154
    info "script_path: ${script_path}"
    # shellcheck disable=SC2154
    info "script_dir: ${script_dir}"
    # shellcheck disable=SC2154
    info "script_name: ${script_name}"

    # Logging helper functions
    error "This is an error message"
    warn "This is a warning message"
    info "This is an info message"
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
