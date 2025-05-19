#!/usr/bin/env bash

## FILE           : #~NAME~#
## DESCRIPTION    : A best practices Bash script template with many useful functions.
##                  This file combines the source.sh & script.sh files into a single
##                  script. If you want your script to be entirely self-contained then
##                  this should be what you want!
## AUTHOR         : Silverbullet069
## CREATED        : #~TIME~#
## LICENSE        : MIT License
## TEMCRE         : https://github.com/ralish/bash-script-template/blob/main/template.sh
## TEMVER         : v2.0.2

# ============================================================================ #
# Helper flags
# ============================================================================ #

# Enable xtrace if the DEBUG environment variable is set
if [[ "${DEBUG-}" =~ ^1|yes|true$ ]]; then
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

# Make `for f in *.txt` work even if *.txt matches zero files
shopt -s nullglob globstar

# Set IFS to preferred implementation
# IFS=$' '

# ============================================================================ #
# Internal function
# ============================================================================ #

# NOTE: Important to set first as we use it in _log() and exit handler
# shellcheck disable=SC2155
readonly ta_none="$(tput sgr0 2> /dev/null || true)"

# DESC: Print message with printf-like formatting and appropriate styling
# ARGS: $1 (required): The color of the message
#       $2 (required): The type of log (SUCCESS, ERROR, WARN, INFO, DEBUG)
#       $3 (required): The format string
#       $4+ (optional): Arguments for the format string
# OUTS: Message to stderr and optionally to a log file
# RETS: 0
function _log() {
    # Check minimum arguments
    if [[ $# -lt 3 ]]; then
        script_exit "_log() requires color, log type, and format string!" 2
    fi

    local color="$1"
    local -r log_type="$2"
    local -r format="$3"
    shift 3

    # If color is disabled
    if [[ -n "${_flag_no_colour-}" ]]; then
        color="${ta_none}"
    fi
    # "${BASH_SOURCE[2]}" -> where the function that called sucesss() / error() / warn() / info() / debug() is defined
    # "${BASH_SOURCE[1]}" -> where sucesss() / error() / warn() / info() / debug() are defined
    # "${BASH_SOURCE[0]}" -> where log() is defined
    # local -r script_name=${BASH_SOURCE[2]}"
    # "${BASH_LINENO[1]}" -> where sucesss() / error() / warn() / info() / debug() get called
    # "${BASH_LINENO[0]}" -> where log() get called
    local -r lineno="${BASH_LINENO[1]}"

    # Handle timestamp if enabled
    local timestamp=""
    if [[ -n "${_flag_timestamp-}" ]]; then
        timestamp="$(date +"[%Y-%m-%d %H:%M:%S %z]") "
    fi

    # Format the message with arguments
    local log_message
    if [[ $# -gt 0 ]]; then
        # shellcheck disable=SC2059
        printf -v log_message "${format}" "$@"
    else
        log_message="${format}"
    fi

    # Define the log format
    local -r log_format="%s%s[%s]: %b%-5s%b %s\n"

    # Output function
    _output() {
        printf "${log_format}" \
            "${timestamp}" "$(basename "${0}")" "${lineno}" \
            "${color}" "${log_type}" "${ta_none}" \
            "${log_message}"
    }

    # Print to stderr
    _output >&2

    # Log to file if enabled
    if [[ -n "${_flag_log-}" ]]; then
        _output >> "/tmp/$(basename "${0}").log"
    fi
}

# Logging functions with printf-like behavior
function success() { [[ -n "${init_colour-}" ]] && _log "${ta_bold}${fg_green}" "[SUC]" "$@" || _log "${ta_none}" "[SUC]" "$@"; } # SUC = success
function error()   { [[ -n "${init_colour-}" ]] && _log "${ta_bold}${fg_red}" "[ERR]" "$@" || _log "${ta_none}" "[ERR]" "$@"; } # ERR = error
function warn()    { [[ -n "${init_colour-}" ]] && _log "${ta_bold}${fg_yellow}" "[WRN]" "$@" || _log "${ta_none}" "[WRN]" "$@"; } # WRN = warning
function info()    { [[ -n "${init_colour-}" ]] && _log "${ta_bold}${fg_blue}" "[INF]" "$@" || _log "${ta_none}" "[INF]" "$@"; } # INF = info
function debug()   { [[ -n "${DEBUG-}" ]] && _log "${ta_none}" "[DBG]" "$@" || true; } # DBG = debug

# DESC: Handler for unexpected errors
# ARGS: $1 (optional): Exit code (defaults to 1)
# OUTS: None
# RETS: None
function script_trap_err() {
    local exit_code=1

    # Disable the error trap handler to prevent potential recursion
    trap - ERR

    # Consider any further errors non-fatal to ensure we run to completion
    set +o errexit
    set +o pipefail

    # Validate any provided exit code
    if [[ ${1-} =~ ^[0-9]+$ ]]; then
        exit_code="$1"
    fi

    # Output debug data if in Quiet mode
    if [[ -n ${_flag_quiet-} ]]; then
        # Restore original file output descriptors
        if [[ -n ${script_output-} ]]; then
            exec 1>&3 2>&4
        fi

        # Print basic debugging information
        error '***** Abnormal termination of script *****\n'
        error 'Script Path:            %s\n' "${script_path}"
        error 'Script Parameters:      %s\n' "${script_params}"
        error 'Script Exit Code:       %s\n' "${exit_code}"

        # Print the script log if we have it. It's possible we may not if we
        # failed before we even called quiet_init(). This can happen if bad
        # parameters were passed to the script so we bailed out very early.
        if [[ -n ${script_output-} ]]; then
            # shellcheck disable=SC2312
            error 'Script Output:\n\n%s' "$(cat "${script_output}")"
        else
            error 'Script Output:          None (failed before log init)\n'
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
    if [[ -n "${_flag_quiet-}" && -f "${script_output-}" ]]; then
        rm -v "${script_output}"
    fi

    # Remove script execution lock
    if [[ -d "${script_lock-}" ]]; then
        rmdir -v "${script_lock}"
    fi

    # Restore terminal colours
    printf '%b' "${ta_none}"
}

# DESC: Exit script with the given message
# ARGS: $1 (required): Message to print on exit
#       $2 (optional): Exit code (defaults to 0)
# OUTS: None
# RETS: None
# NOTE: The convention used in this script for exit codes is:
#       0: Normal exit
#       1: Abnormal exit due to external error
#       2: Abnormal exit due to script error
function script_exit() {
    # Check arguments
    if [[ $# -eq 0 ]]; then
        error 'Missing required argument to script_exit()!'
        exit 2
    fi

    # Handle success cases
    if [[ $# -eq 1 || ("${2-}" =~ ^[0-9]+$ && "${2}" -eq 0) ]]; then
        success "$1"
        exit 0
    fi

    # Handle error cases with numeric exit code
    if [[ "${2-}" =~ ^[0-9]+$ ]]; then
        error "${1}"
        script_trap_err "${2}"
        # script_trap_err will exit, so we shouldn't reach here
    fi

    script_exit 'Missing required argument to script_exit()!' 2
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
    readonly init_colour=true

    if [[ -z "${_flag_no_colour-}" ]]; then
        # Text attributes
        readonly ta_bold="$(tput bold 2> /dev/null || true)"
        printf '%b' "${ta_none}"
        readonly ta_uscore="$(tput smul 2> /dev/null || true)"
        printf '%b' "${ta_none}"
        readonly ta_blink="$(tput blink 2> /dev/null || true)"
        printf '%b' "${ta_none}"
        readonly ta_reverse="$(tput rev 2> /dev/null || true)"
        printf '%b' "${ta_none}"
        readonly ta_conceal="$(tput invis 2> /dev/null || true)"
        printf '%b' "${ta_none}"

        # Foreground codes
        readonly fg_black="$(tput setaf 0 2> /dev/null || true)"
        printf '%b' "${ta_none}"
        readonly fg_blue="$(tput setaf 4 2> /dev/null || true)"
        printf '%b' "${ta_none}"
        readonly fg_cyan="$(tput setaf 6 2> /dev/null || true)"
        printf '%b' "${ta_none}"
        readonly fg_green="$(tput setaf 2 2> /dev/null || true)"
        printf '%b' "${ta_none}"
        readonly fg_magenta="$(tput setaf 5 2> /dev/null || true)"
        printf '%b' "${ta_none}"
        readonly fg_red="$(tput setaf 1 2> /dev/null || true)"
        printf '%b' "${ta_none}"
        readonly fg_white="$(tput setaf 7 2> /dev/null || true)"
        printf '%b' "${ta_none}"
        readonly fg_yellow="$(tput setaf 3 2> /dev/null || true)"
        printf '%b' "${ta_none}"

        # Background codes
        readonly bg_black="$(tput setab 0 2> /dev/null || true)"
        printf '%b' "${ta_none}"
        readonly bg_blue="$(tput setab 4 2> /dev/null || true)"
        printf '%b' "${ta_none}"
        readonly bg_cyan="$(tput setab 6 2> /dev/null || true)"
        printf '%b' "${ta_none}"
        readonly bg_green="$(tput setab 2 2> /dev/null || true)"
        printf '%b' "${ta_none}"
        readonly bg_magenta="$(tput setab 5 2> /dev/null || true)"
        printf '%b' "${ta_none}"
        readonly bg_red="$(tput setab 1 2> /dev/null || true)"
        printf '%b' "${ta_none}"
        readonly bg_white="$(tput setab 7 2> /dev/null || true)"
        printf '%b' "${ta_none}"
        readonly bg_yellow="$(tput setab 3 2> /dev/null || true)"
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
    readonly orig_cwd="$PWD"
    readonly script_params="$*"
    readonly script_path="${BASH_SOURCE[0]}"
    readonly script_dir="$(dirname "$script_path")"
    readonly script_name="$(basename "$script_path")"
}

# DESC: Initialise Quiet mode
# ARGS: None
# OUTS: $script_output: Path to the file stdout & stderr was redirected to
# RETS: None
function quiet_init() {
    if [[ -n "${_flag_quiet-}" ]]; then
        # Redirect all output to a temporary file
        local -r script_output="$(mktemp --tmpdir "$script_name".XXXXX)"
        exec 3>&1 4>&2 1> "${script_output}" 2>&1
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
        script_exit 'Missing or invalid argument to lock_init()!' 2
    fi

    if mkdir "${lock_dir}" 2> /dev/null; then
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
        script_exit 'Missing required argument to build_path()!' 2
    fi

    local temp_path="${1}:"
    if [[ -n "${2-}" ]]; then
        temp_path="${temp_path}${2}:"
    fi

    local new_path=
    while [[ -n "${temp_path}" ]]; do
        path_entry="${temp_path%%:*}"
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
        script_exit 'Missing required argument to check_binary()!' 2
    fi

    if ! command -v "${1}" > /dev/null 2>&1; then
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
    local superuser
    if [[ "${EUID}" -eq 0 ]]; then
        superuser=true
    elif [[ -z "${1-}" ]]; then
        # shellcheck disable=SC2310
        if check_binary sudo; then
            info 'Sudo: Updating cached credentials ...'
            if ! sudo -v; then
                error "Sudo: Couldn't acquire credentials ..."
            else
                local -r test_euid="$(sudo -H -- "$BASH" -c 'printf "%s" "$EUID"')"
                if [[ "${test_euid}" -eq 0 ]]; then
                    superuser=true
                fi
            fi
        fi
    fi

    if [[ -z "${superuser-}" ]]; then
        error 'Unable to acquire superuser credentials.'
        return 1
    fi

    success 'Successfully acquired superuser credentials.'
    return 0
}

# DESC: Run the requested command as root (via sudo if requested)
# ARGS: $1 (optional): Set to zero to not attempt execution via sudo
#       $@ (required): Passed through for execution as root user
# OUTS: None
# RETS: None
function run_as_root() {
    if [[ $# -eq 0 ]]; then
        script_exit 'Missing required argument to run_as_root()!' 2
    fi

    if [[ "${1-}" =~ ^0$ ]]; then
        local -r skip_sudo=true
        shift
    fi

    if [[ "${EUID}" -eq 0 ]]; then
        "$@"
    elif [[ -z "${skip_sudo-}" ]]; then
        sudo -H -- "$@"
    else
        script_exit "Unable to run requested command as root: $*" 1
    fi
}

# ============================================================================ #
# User start here                                                              #
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

# Invoke main with args if not sourced
# Approach via: https://stackoverflow.com/a/28776166/8787985
if ! (return 0 2> /dev/null); then
    main "$@"
fi

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
