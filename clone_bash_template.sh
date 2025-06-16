#!/usr/bin/env bash

## FILE        : clone_bash_template.sh
## VERSION     : v2.2.0
## DESCRIPTION : Copy template.sh / template_lite.sh / source.sh + script.sh
## AUTHOR      : Silverbullet069
## REPOSITORY  : https://github.com/Silverbullet069/bash-script-template
## LICENSE     : MIT License

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
                    default_value=  # reset default value
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
            -m | --mode)
                ### Specify template mode (full|lite|source+script). @DEFAULT:lite@
                if [[ ! "${1-}" =~ ^(full|lite|source\+script)$ ]]; then
                    script_exit "Invalid template mode: ${1}. Valid values: (full|lite|src)"
                fi

                _option_mode="${1}"
                shift
                ;;
            -o | --output)
                ### Specify output directory or file path.
                ### Defaults to current working directory.

                if [[ -d "${1-}" || (-f "${1-}" && "${1-}" =~ \.(sh|bash)$) ]]; then
                    _option_output="$(realpath "${1-}")"
                    shift
                else
                    script_exit "Invalid output. Please specify a directory path or a file path with .sh or .bash extension." 1
                fi
                ;;
            # Built-in options
            # NOTE: ### comment will be displayed as short description for options in --help output
            -l | --log-level)
                ### Specify log level (DBG|INF|WRN|ERR). @DEFAULT:INF@
                ### Add DEBUG=1 to enable Bash debug mode.

                if [[ -z "${LOG_LEVELS[${1-}]}" ]]; then
                    script_exit "Invalid log level: ${1-}. Valid values: ${LOG_LEVELS[*]}" 1
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
                # internal function calling
                if declare -F "${param}" &> /dev/null && [[ -n "${DEBUG-}" ]]; then
                    "${param}" "$@"
                    exit 0
                fi
                script_exit "Invalid parameter was provided: ${param}" 1
                ;;
        esac
    done

    # option output default to current working directory
    [[ -z "${_option_output-}" ]] && _option_output="$(pwd)" || true

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

    # built-in dereference
    # shellcheck disable=SC2312

    _copy_file() {
        local src="$1"
        local dest="$2"
        # shellcheck disable=SC2154
        if [[ ! -f "${script_dir}/${src}" ]]; then
            script_exit "${src} is not existed. Check again." 1
        fi

        if cp -iv "${script_dir}/${src}" "${dest}"; then
            info "Successfully copied ${src} to ${dest}"
        else
            warn "Failed to copy ${src} to ${dest}. Skipping..." 1
        fi
    }

    case "${_option_mode}" in
        full)
            _copy_file "template.sh" "${_option_output}"
            ;;
        lite)
            _copy_file "template_lite.sh" "${_option_output}"
            ;;
        source\+script)
            _copy_file "source.sh" "${_option_output}"
            _copy_file "script.sh" "${_option_output}"
            ;;
        *)
            script_exit "Something's wrong with the validation logic of -m|--mode option. Check again" 2
            ;;
    esac
}

# ============================================================================ #
# Helper flags
# ============================================================================ #

# Enable xtrace if the DEBUG environment variable is set
if [[ -n ${DEBUG-} ]]; then
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
# shellcheck disable=SC1091,SC2312
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/source.sh"

# Invoke main with args if not sourced
# Approach via: https://stackoverflow.com/a/28776166/8787985
if ! (return 0 2> /dev/null); then
    main "$@"
fi
