#!/usr/bin/env bash

# ============================================================================ #

## FILE         : @NAME@
## VERSION      : @VER@
## DESCRIPTION  : @DESC@
## AUTHOR       : @AUTHOR@
## REPOSITORY   : @REPO@
## LICENSE      : @LIC@

## TEMREPO      : https://github.com/Silverbullet069/bash-script-template
## TEMMODE      : @MODE@
## TEMVER       : @TAG@
## TEMUPDATED   : @UPDATED@
## TEMLIC       : BSD 3-Clause License

# ============================================================================ #

# NOTE: Important to set first as we use it in _log() and exit handler
# shellcheck disable=SC2155
readonly ta_none="$(tput sgr0 2>/dev/null || true)"

# Log levels associative array with ascending severity
declare -rA LOG_LEVELS=(["DBG"]=0 ["INF"]=1 ["WRN"]=2 ["ERR"]=3)

# DESC: Print message with printf-like formatting and appropriate styling
# ARGS: $1 (required): The color of the message
#       $2 (required): The type of log
#       $3+ (required): The message string(s)
# OUTS: Message to stderr and optionally to a log file
# RETS: 0
function _log() {

    # validation
    if [[ $# -lt 3 ]]; then
        script_exit "${FUNCNAME[0]}() requires color, log type, and at least one message string!" 2
    fi

    local color="$1"
    local -r log_type="$2"
    shift 2
    local log_message="$*"

    # Check current log level against configured level
    # NOTE: _log might be called before parse_params(), _option_log_level might not exist yet
    if [[ ${LOG_LEVELS["${log_type}"]} -lt ${LOG_LEVELS["${_option_log_level:-DBG}"]} ]]; then
        return 0
    fi

    # Check whether color is disabled
    # NOTE: _log might be called before parse_params(), _option_log_level might not exist yet
    if [[ -n "${_option_no_colour-}" ]]; then
        color="${ta_none}"
    fi
    # "${BASH_SOURCE[2]}" -> abs path to script that defined the function that called error() / warn() / info() / debug() functions
    # "${BASH_SOURCE[1]}" -> abs path to script that defined error() / warn() / info() / debug() functions
    # "${BASH_SOURCE[0]}" -> abs path to script that defined _log() function
    local caller=$(basename "${BASH_SOURCE[2]}")
    # "${BASH_LINENO[1]}" -> where sucesss() / error() / warn() / info() / debug() get called
    # "${BASH_LINENO[0]}" -> where log() get called
    local lineno="${BASH_LINENO[1]}"

    # check whether main() call script_exit() and script_exit() called error() / warn() / info() / debug()
    if [[ "${FUNCNAME[2]}" == "script_exit" ]]; then
        caller="$(basename "${BASH_SOURCE[3]}")"
        lineno="${BASH_LINENO[2]}"
    fi

    # Handle timestamp if enabled
    local timestamp=""
    if [[ -n "${_option_timestamp-}" ]]; then
        timestamp="$(date +"[%Y-%m-%d %H:%M:%S %z]") "
    fi

    # Colorize path-like patterns (starting with / or ./ or ../ or ~/)
    log_message=$(echo "${log_message}" | sed -E "s#(\./|\.\.\/|~/|/)([^[:space:]]*)#${fg_green-}&${ta_none}#g")

    # Replace $HOME with ~
    log_message="${log_message//\/home\/${USER-}/\~}"

    printf "%s%s[%s]: %b[%-3s]%b %s\n" \
        "${timestamp}" "${caller}" "${lineno}" \
        "${color}" "${log_type}" "${ta_none}" \
        "${log_message}"
}

# shellcheck disable=SC2015,SC2310
function debug() { _log "${ta_none}" "DBG" "$@"; }
function info() { _log "${ta_bold-}${fg_blue-}" "INF" "$@"; }
function warn() { _log "${ta_bold-}${fg_yellow-}" "WRN" "$@"; }
function error() { _log "${ta_bold-}${fg_red-}" "ERR" "$@"; }

# DESC: Handler for unexpected errors
# ARGS: $1 (optional): Exit code (defaults to 1)
# OUTS: None
# RETS: None
function script_trap_err() {

    # Disable the error trap handler to prevent potential recursion
    trap - ERR

    # Consider any further errors non-fatal to ensure we run to completion
    set +o errexit
    set +o pipefail

    # Validate exit code
    if [[ ${1-} -lt 0 || ${1-} -gt 255 ]]; then
        script_exit "Invalid arguments: $*. ${FUNCNAME[0]} must receive ONE integer exit status code ranging from 1 to 255" 2
    fi
    local -r exit_code="${1-1}"

    # Output debug data if in Quiet mode
    if [[ -n "${_option_quiet-}" ]]; then
        # Restore original file output descriptors
        if [[ -n "${script_output-}" ]]; then
            exec 1>&3 2>&4
        fi

        # Print basic debugging information
        error "Abnormal termination of script"
        error "Script Path:       ${script_path}"
        error "Script Parameters: ${script_params}"
        error "Script Exit Code:  ${exit_code}"

        # Print the script log if we have it. It's possible we may not if we
        # failed before we even called quiet_init(). This can happen if bad
        # parameters were passed to the script so we bailed out very early.
        if [[ -n "${script_output-}" ]]; then
            error "Script Output:"
            cat "${script_output}" >&2 || true
        else
            error "Script Output: none (failed before log init)"
        fi
    fi

    # Exit with failure status
    exit "${exit_code}"
}

# DESC: Handler for exiting the script
# ARGS: None
# OUTS: None
# RETS: None
function script_trap_exit() {
    cd "${orig_cwd}"

    # Remove Quiet mode script log
    if [[ -n "${_option_quiet-}" && -n "${script_output-}" ]]; then
        rm "${script_output}"
        info "Clean up script output: ${script_output}"
    fi

    # Remove script execution lock
    if [[ -d "${script_lock-}" ]]; then
        rmdir "${script_lock}"
        info "Clean up script lock: ${script_lock}"
    fi

    # Restore terminal colours
    printf '%b' "${ta_none}"
}

# DESC: Exit script with the given message
# ARGS: $1 (required): Error message to print on exit
#       $2 (required): Exit status code
# OUTS: None
# RETS: None
# NOTE: The convention used in this script for exit codes is:
#       1: Abnormal exit due to external error (missing dependency, network is not accessible, target dir existed, )
#       2: Abnormal exit due to script error (empty argument, undefined options, ...)
function script_exit() {

    if [[ $# -eq 2 && "${2}" =~ ^[0-9]+$ && "${2}" -gt 0 && "${2}" -lt 256 ]]; then
        error "${1}"
        script_trap_err "${2}"
    fi

    script_exit "Invalid arguments: $*. ${FUNCNAME[0]}() must receive ONE string message and ONE integer exit status code ranging from 1 to 255" 2
}

# DESC: Initialise colour variables
# ARGS: None
# OUTS: Read-only variables with ANSI control codes
# RETS: None
# NOTE: If --no-colour was set the variables will be empty. The output of the
#       $ta_none variable after each tput is redundant during normal execution,
#       but ensures the terminal output isn't mangled when running with xtrace.
# shellcheck disable=SC2034,SC2155
function colour_init() {

    if [[ -z "${_option_no_colour-}" ]]; then
        # Text attributes
        readonly ta_bold="$(tput bold 2>/dev/null || true)"
        readonly ta_uscore="$(tput smul 2>/dev/null || true)"
        readonly ta_blink="$(tput blink 2>/dev/null || true)"
        readonly ta_reverse="$(tput rev 2>/dev/null || true)"
        readonly ta_conceal="$(tput invis 2>/dev/null || true)"

        # Foreground codes
        readonly fg_black="$(tput setaf 0 2>/dev/null || true)"
        readonly fg_blue="$(tput setaf 4 2>/dev/null || true)"
        readonly fg_cyan="$(tput setaf 6 2>/dev/null || true)"
        readonly fg_green="$(tput setaf 2 2>/dev/null || true)"
        readonly fg_magenta="$(tput setaf 5 2>/dev/null || true)"
        readonly fg_red="$(tput setaf 1 2>/dev/null || true)"
        readonly fg_white="$(tput setaf 7 2>/dev/null || true)"
        readonly fg_yellow="$(tput setaf 3 2>/dev/null || true)"

        # Background codes
        readonly bg_black="$(tput setab 0 2>/dev/null || true)"
        readonly bg_blue="$(tput setab 4 2>/dev/null || true)"
        readonly bg_cyan="$(tput setab 6 2>/dev/null || true)"
        readonly bg_green="$(tput setab 2 2>/dev/null || true)"
        readonly bg_magenta="$(tput setab 5 2>/dev/null || true)"
        readonly bg_red="$(tput setab 1 2>/dev/null || true)"
        readonly bg_white="$(tput setab 7 2>/dev/null || true)"
        readonly bg_yellow="$(tput setab 3 2>/dev/null || true)"

        # Reset terminal once at the end
        printf '%b' "${ta_none}"
    else
        # Text attributes
        readonly ta_bold=''
        readonly ta_uscore=''
        readonly ta_blink=''
        readonly ta_reverse=''
        readonly ta_conceal=''

        # Foreground codes
        readonly fg_black=''
        readonly fg_blue=''
        readonly fg_cyan=''
        readonly fg_green=''
        readonly fg_magenta=''
        readonly fg_red=''
        readonly fg_white=''
        readonly fg_yellow=''

        # Background codes
        readonly bg_black=''
        readonly bg_blue=''
        readonly bg_cyan=''
        readonly bg_green=''
        readonly bg_magenta=''
        readonly bg_red=''
        readonly bg_white=''
        readonly bg_yellow=''
    fi
}

# DESC: Generic script initialisation
# ARGS: $@ (optional): Arguments provided to the script
# OUTS: $orig_cwd:      The current working directory when the script was run
#       $script_path:   The full path to the script
#       $script_dir:    The directory path of the script
#       $script_name:   The file name of the script
#       $script_params: The original parameters provided to the script
# RETS: None
# NOTE: $script_path only contains the path that was used to call the script
#       and will not resolve any symlinks which may be present in the path.
#       You can use a tool like realpath to obtain the "true" path. The same
#       caveat applies to both the $script_dir and $script_name variables.
# shellcheck disable=SC2034
function script_init() {
    # Useful variables
    readonly orig_cwd="${PWD}"
    readonly script_params="$*"
    readonly script_path="$(realpath "$0")"
    readonly script_dir="$(dirname "${script_path}")"
    readonly script_name="$(basename "${script_path}")"
}

# DESC: Initialise Quiet mode
# ARGS: None
# OUTS: $script_output: Path to the file stdout & stderr was redirected to
# RETS: None
function quiet_init() {
    if [[ -n "${_option_quiet-}" ]]; then
        # Redirect all output to a temporary file
        # shellcheck disable=SC2312
        # NOTE: comparable with BusyBox mktemp inside Alpine Image
        readonly script_output="$(mktemp -p "/tmp" "${script_name}.XXXXXX")"
        exec 3>&1 4>&2 1>"${script_output}" 2>&1
    fi
}

# DESC: Acquire script lock
# ARGS: $1 (optional): Scope of script execution lock (system or user)
# OUTS: $script_lock: Path to the directory indicating we have the script lock
# RETS: None
# NOTE: This lock implementation is extremely simple but should be reliable
#       across all platforms. It does *not* support locking a script with
#       symlinks or multiple hardlinks as there's no portable way of doing so.
#       If the lock was acquired it's automatically released on script exit.
function lock_init() {
    local lock_dir
    if [[ "${1}" = "system" ]]; then
        lock_dir="/tmp/${script_name}.lock"
    elif [[ "${1}" = "user" ]]; then
        lock_dir="/tmp/${script_name}.${UID}.lock"
    else
        script_exit "Missing or invalid arguments to ${FUNCNAME[0]}()!" 2
    fi

    if mkdir "${lock_dir}" 2>/dev/null; then
        readonly script_lock="${lock_dir}"
        info "Acquired script lock: ${script_lock}"
    else
        script_exit "Unable to acquire script lock: ${lock_dir}" 1
    fi
}

# DESC: Combines two path variables and removes any duplicates
# ARGS: $1 (required): Path(s) to join with the second argument
#       $2 (optional): Path(s) to join with the first argument
# OUTS: $build_path: The constructed path
# RETS: None
# NOTE: Heavily inspired by: https://unix.stackexchange.com/a/40973
function build_path() {
    if [[ $# -lt 1 ]]; then
        script_exit "Missing required arguments to ${FUNCNAME[0]}()!" 2
    fi

    local temp_path="${1}:"
    if [[ -n "${2-}" ]]; then
        temp_path="${temp_path}${2}:"
    fi

    local new_path=
    while [[ -n "${temp_path}" ]]; do
        local path_entry="${temp_path%%:*}"
        case "${new_path}:" in
            *:"${path_entry}":*) ;;
            *)
                new_path="${new_path}:${path_entry}"
                ;;
        esac
        temp_path="${temp_path#*:}"
    done

    # shellcheck disable=SC2034
    readonly build_path="${new_path#:}"
}

# DESC: Check a binary exists in the search path
# ARGS: $1 (required): Name of the binary to test for existence
#       $2 (optional): Set to any value to treat failure as a fatal error
# OUTS: None
# RETS: 0 (true) if dependency was found, otherwise 1 (false) if failure is not
#       being treated as a fatal error.
function check_binary() {
    if [[ $# -lt 1 ]]; then
        script_exit "Missing required arguments to ${FUNCNAME[0]}()!" 2
    fi

    if ! command -v "${1}" >/dev/null 2>&1; then
        if [[ -n "${2-}" ]]; then
            script_exit "Missing dependency: Couldn't locate ${1}." 1
        else
            error "Missing dependency: ${1}"
            return 1
        fi
    fi

    info "Found dependency: ${1}"
    return 0
}

# DESC: Validate we have superuser access as root (via sudo if requested)
# ARGS: $1 (optional): Set to any value to not attempt root access via sudo
# OUTS: None
# RETS: 0 (true) if superuser credentials were acquired, otherwise 1 (false)
function check_superuser() {
    local superuser=
    if [[ "${EUID}" -eq 0 ]]; then
        superuser=true
    elif [[ -z "${1-}" ]]; then
        # shellcheck disable=SC2310
        if check_binary sudo; then
            info "Sudo: Updating cached credentials ..."
            if ! sudo -v; then
                error "Sudo: Could not acquire credentials ..."
            else
                # shellcheck disable=SC2312
                local -r test_euid="$(sudo -H -- "$BASH" -c 'printf "%s" "$EUID"')"
                if [[ "${test_euid}" -eq 0 ]]; then
                    superuser=true
                fi
            fi
        fi
    fi

    if [[ -z "${superuser-}" ]]; then
        error "Unable to acquire superuser credentials."
        return 1
    fi

    info "Successfully acquired superuser credentials."
    return 0
}

# DESC: Run the requested command as root (via sudo if requested)
# ARGS: $1 (optional): Set to any value to not attempt execution via sudo
#       $@ (required): Passed through for execution as root user
# OUTS: None
# RETS: 0 on success, 1 on failure
function run_as_root() {
    if [[ $# -eq 0 ]]; then
        script_exit "Missing required arguments to ${FUNCNAME[0]}()!" 2
    fi

    local skip_sudo=
    if [[ "${1-}" == "--no-sudo" ]]; then
        skip_sudo=true
        shift
    fi

    if [[ "${EUID}" -eq 0 ]]; then
        "$@"
    elif [[ -z "${skip_sudo}" ]]; then
        # shellcheck disable=SC2310
        if ! check_binary sudo; then
            script_exit "'sudo' binary is not available." 1
        fi
        warn "Run the following command with sudo privilege:"
        warn "$*"
        sudo -H -- "$@"
    else
        error "Cannot run command as root: not root user and sudo disabled"
        return 1
    fi
}

# DESC: Parameter parser
# ARGS: $@ (optional): Arguments provided to the script
# OUTS: $_option_*    : variables indicating command-line parameters and options
#       $options      : a variable holding underscore-separated options name
#       $help_options : an indexed array, each line contains a line of help message
# RETS: None
function parse_params() {

    # Extract options dynamically from parse_params function

    # shellcheck disable=SC2016,SC2312
    local script_file="${BASH_SOURCE[0]}"
    declare -gA options=()     # associative array
    declare -g help_options=() # indexed array

    local in_case_block=
    while IFS= read -r line; do
        if [[ $line =~ case.*param.*in ]]; then
            in_case_block=true
            continue
        elif [[ $line =~ esac ]]; then
            # reset
            in_case_block=
            continue
        fi

        if [[ -n "${in_case_block-}" ]]; then

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
    done <"$script_file"

    # Check if options array is empty
    if [[ "${#options[@]}" -eq 0 ]]; then
        script_exit "No valid flags found in ${FUNCNAME[0]}() function." 2
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
                ### Add DEBUG=true to enable Bash debug mode.

                if [[ -z "${LOG_LEVELS[${1}]}" ]]; then
                    script_exit "Invalid log level: ${1}. Valid constraints: ${LOG_LEVELS[*]}" 2
                fi
                _option_log_level="${1}"
                shift
                ;;
            -n | --no-colour)
                ### Disables colour output

                _option_no_colour=true
                ;;
            -q | --quiet)
                ### Run silently unless an error is encountered

                _option_quiet=true
                ;;
            -t | --timestamp)
                ### Enables timestamp output

                _option_timestamp=true
                ;;
            -h | --help)
                ### Displays this help and exit

                print_help_message
                exit 0
                ;;
            *)
                script_exit "${FUNCNAME[0]}() receives invalid arguments: ${param}" 2
                ;;
        esac
    done

    # Check if options array is empty
    if [[ "${#options[@]}" -eq 0 ]]; then
        script_exit "No options found in ${FUNCNAME[0]}() function." 2
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
function print_help_message() {
    cat <<EOF

Usage: @NAME@ [OPTIONS] ...

Add short description and examples here...

Options:
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
if ! (return 0 2>/dev/null); then
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

# Invoke main with args if not sourced
# Approach via: https://stackoverflow.com/a/28776166/8787985
if ! (return 0 2>/dev/null); then
    main "$@"
fi
