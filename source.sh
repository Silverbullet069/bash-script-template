#!/usr/bin/env bash

## FILE        : source.sh
## DESCRIPTION : Bash script with many useful, reusable utility functions.
##               ONLY for sourcing into other scripts so it contains functions
##               which are unlikely to be modified. DRY and easy to refactor.
## USAGE       : none, only sourced
## AUTHOR      : Silverbullet069
## CREATED     : 2025-02-08 19:10:03
## VERSION     : 0.2
## LICENSE     : MIT License
## CREDIT      : https://github.com/ralish/bash-script-template/blob/main/source.sh
## HISTORY     :
## - (2024-02-14) style: change printf command in exit_script() to error()

## ToC:
## - trap_script_err()
## - trap_script_exit()
## - exit_script()
## - init_script()
## - init_color()
## - init_quiet()
## - init_lock()
## - log()
## - success(), error(), warn(), info(), debug()
## - check_superuser()
## - run_as_root()

###############################################################################

# DESC: Handler for unexpected errors
# ARGS: $1 (optional): Exit code (defaults to 1)
# OUTS: None
# RETS: None
function trap_script_err() {
    local _exit_code=1

    # Disable the error trap handler to prevent potential infinite recursion
    trap - ERR

    # Consider any further errors are non-fatal to ensure we run to completion
    set +o errexit
    set +o pipefail

    # Validate any provided exit code
    if [[ ${1-} =~ ^[0-9]+$ ]]; then
        _exit_code="$1"
    fi

    # Output debug data if in Quiet mode
    if [[ -n ${QUIET-} ]]; then
        # Restore original file output descriptors
        if [[ -n ${SCRIPT_OUTPUT-} ]]; then
            exec 1>&3 2>&4
        fi

        # Print basic debugging information
        printf '%b\n' "$TA_NONE"
        printf '***** Abnormal termination of script *****\n'
        printf 'Script Path:            %s\n' "$SCRIPT_PATH"
        printf 'Script Parameters:      %s\n' "$SCRIPT_PARAMS"
        printf 'Script Exit Code:       %s\n' "$_exit_code"

        # Print the script log if we have it. It's possible we may not if we
        # failed before we even called init_quiet(). This can happen if bad
        # parameters were passed to the script so we bailed out very early.
        if [[ -n ${SCRIPT_OUTPUT-} ]]; then
            # shellcheck disable=SC2312
            printf 'Script Output:\n\n%s' "$(cat "$SCRIPT_OUTPUT")"
        else
            printf 'Script Output:          None (failed before log init)\n'
        fi
    fi

    # Exit with failure status
    exit "$_exit_code"
}

# DESC: Handler for exiting script
# ARGS: None
# OUTS: None
# RETS: None
function trap_script_exit() {

    # Remove Quiet mode script log
    if [[ -n ${QUIET-} && -f ${SCRIPT_OUTPUT-} ]]; then
        rm "$SCRIPT_OUTPUT"
    fi

    # Remove script execution lock
    if [[ -d ${SCRIPT_LOCK-} ]]; then
        rmdir "$SCRIPT_LOCK"
    fi

    # Restore terminal colours
    printf '%b' "$TA_NONE"
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
function exit_script() {
    if [[ $# -eq 1 ]]; then
        printf "$s\n" "$1"
        exit 0
    fi

    if [[ ${2-} =~ ^[0-9]+$ ]]; then
        printf "%b\n" "$1"
        # If we've been provided a non-zero exit code run the error trap
        if [[ $2 -ne 0 ]]; then
            trap_script_err "$2"
        else
            exit 0
        fi
    fi

    exit_script 'Missing required argument to exit_script()!' 2
}

# DESC: Generic script initialization
# ARGS: $@ (optional): Arguments provided to the script
# OUTS: - $SCRIPT_PATH: Full path to the sourcing script
#       - $SCRIPT_DIR: Directory of the sourcing script
#       - $SCRIPT_NAME: Filename of the sourcing script
#       - $SCRIPT_PARAMS: Original script parameters
#       - $TA_NONE: ANSI reset code
#       - $TIME_FORMAT: Log timestamp format
#       - $LOG_FORMAT: Log message format
#       - $LOG_TYPES: Names of 5 common log types.
# RETS: None
# NOTE: Path variables won't resolve symlinks
# shellcheck disable=SC2034
function init_script() {
    # Useful variables
    readonly SCRIPT_PARAMS="$*"
    readonly SCRIPT_PATH="$(realpath "${BASH_SOURCE[1]}")"
    readonly SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
    readonly SCRIPT_NAME="$(basename "$SCRIPT_PATH")"

    readonly TIME_FORMAT='[%Y-%m-%d %H:%M:%S]'
    # Cre: https://stackoverflow.com/a/5412825
    readonly LOG_FORMAT='%s[%s]: %b[%s] %s%b\n'
    readonly LOG_FORMAT_NO_COLOR='%s[%s]: [%s] %s\n'
    readonly -a LOG_TYPES=('SUCCESS' 'ERROR' 'WARN' 'INFO' 'DEBUG')

    # Important to set this text attribute first since it's used in exit handler
    # shellcheck disable=SC2155
    readonly TA_NONE="$(tput sgr0 2> /dev/null || true)"
}

# DESC: Initialize colour variables
# ARGS: None
# OUTS: Read-only variables with ANSI control codes
# RETS: None
# NOTE: If --no-colour was set the variables will be empty. The output of the
#       $TA_NONE variable after each tput is redundant during normal execution,
#       but ensures the terminal output isn't mangled when running with xtrace.
# shellcheck disable=SC2034,SC2155
function init_color() {
    if [[ -z ${NO_COLOR-} ]]; then
        # Text attributes
        readonly TA_BOLD="$(tput bold 2> /dev/null || true)"
        printf '%b' "$TA_NONE"
        readonly TA_UNDERLINE="$(tput smul 2> /dev/null || true)"
        printf '%b' "$TA_NONE"
        readonly TA_BLINK="$(tput blink 2> /dev/null || true)"
        printf '%b' "$TA_NONE"
        readonly TA_REVERSE="$(tput rev 2> /dev/null || true)"
        printf '%b' "$TA_NONE"
        readonly TA_CONCEAL="$(tput invis 2> /dev/null || true)"
        printf '%b' "$TA_NONE"

        # Foreground codes
        readonly FG_BLACK="$(tput setaf 0 2> /dev/null || true)"
        printf '%b' "$TA_NONE"
        readonly FG_BLUE="$(tput setaf 4 2> /dev/null || true)"
        printf '%b' "$TA_NONE"
        readonly FG_CYAN="$(tput setaf 6 2> /dev/null || true)"
        printf '%b' "$TA_NONE"
        readonly FG_GREEN="$(tput setaf 2 2> /dev/null || true)"
        printf '%b' "$TA_NONE"
        readonly FG_MAGENTA="$(tput setaf 5 2> /dev/null || true)"
        printf '%b' "$TA_NONE"
        readonly FG_RED="$(tput setaf 1 2> /dev/null || true)"
        printf '%b' "$TA_NONE"
        readonly FG_WHITE="$(tput setaf 7 2> /dev/null || true)"
        printf '%b' "$TA_NONE"
        readonly FG_YELLOW="$(tput setaf 3 2> /dev/null || true)"
        printf '%b' "$TA_NONE"

        # Background codes
        readonly BG_BLACK="$(tput setab 0 2> /dev/null || true)"
        printf '%b' "$TA_NONE"
        readonly BG_BLUE="$(tput setab 4 2> /dev/null || true)"
        printf '%b' "$TA_NONE"
        readonly BG_CYAN="$(tput setab 6 2> /dev/null || true)"
        printf '%b' "$TA_NONE"
        readonly BG_GREEN="$(tput setab 2 2> /dev/null || true)"
        printf '%b' "$TA_NONE"
        readonly BG_MAGENTA="$(tput setab 5 2> /dev/null || true)"
        printf '%b' "$TA_NONE"
        readonly BG_RED="$(tput setab 1 2> /dev/null || true)"
        printf '%b' "$TA_NONE"
        readonly BG_WHITE="$(tput setab 7 2> /dev/null || true)"
        printf '%b' "$TA_NONE"
        readonly BG_YELLOW="$(tput setab 3 2> /dev/null || true)"
        printf '%b' "$TA_NONE"
    else
        # Text attributes
        readonly TA_BOLD=''
        readonly TA_UNDERLINE=''
        readonly TA_BLINK=''
        readonly TA_REVERSE=''
        readonly TA_CONCEAL=''

        # Foreground CODES
        readonly FG_BLACK=''
        readonly FG_BLUE=''
        readonly FG_CYAN=''
        readonly FG_GREEN=''
        readonly FG_MAGENTA=''
        readonly FG_RED=''
        readonly FG_WHITE=''
        readonly FG_YELLOW=''

        # Background codes
        readonly BG_BLACK=''
        readonly BG_BLUE=''
        readonly BG_CYAN=''
        readonly BG_GREEN=''
        readonly BG_MAGENTA=''
        readonly BG_RED=''
        readonly BG_WHITE=''
        readonly BG_YELLOW=''
    fi
}

# DESC: Initialize Quiet mode
# ARGS: None
# OUTS: $SCRIPT_OUTPUT: Path to the file stdout & stderr was redirected to
# RETS: None
function init_quiet() {
    if [[ -n ${QUIET-} ]]; then
        # Redirect all output to a temporary file
        readonly SCRIPT_OUTPUT="$(mktemp --tmpdir "$SCRIPT_NAME".XXXXX)"
        exec 3>&1 4>&2 1> "$SCRIPT_OUTPUT" 2>&1
    fi
}

# DESC: Acquire script lock
# ARGS: $1 (optional): Scope of script execution lock (system or user)
# OUTS: $SCRIPT_LOCK: Path to the directory indicating we have the script lock
# RETS: None
# NOTE: This lock implementation is extremely simple but should be reliable across all platforms. It does NOT support locking a script with symlinks or multiple hardlinks as there's no portable way of doing so. If the lock was acquired it's automatically released on script exit.
function init_lock() {

    local _lock_dir
    if [[ $1 = 'system' ]]; then
        _lock_dir="/tmp/$SCRIPT_NAME.lock"
    elif [[ $1 = 'user' ]]; then
        _lock_dir="/tmp/$SCRIPT_NAME.$UID.lock"
    else
        exit_script 'Missing or invalid argument to init_lock()!' 2
    fi

    if mkdir "$_lock_dir" 2> /dev/null; then
        readonly SCRIPT_LOCK="$_lock_dir"
        info "Acquired script lock: $SCRIPT_LOCK"
    else
        exit_script "Unable to acquire script lock: $_lock_dir" 1
    fi
}

# DESC:
#       Pretty print the provided string
# ARGS:
#       $1 (required): The color of the message
#       $2 (required): The type of log to print (SUCCESS, ERROR, WARN, INFO,
#                      DEBUG)
#       $3 (required): The message to be printed to stdout and/or a log file if
#                      quiet is on.
# OUTS:
#       stdout: The message is printed to stdout
#       quiet: The message is printed to a log file
# USAGE:
#       log [_color] [_log_type] [_message] [_lineno]
# RETS: 0
function log() {

    local _color="${1}"
    if [[ -n "${NO_COLOR-}" ]]; then
      _color="$TA_NONE"
    fi

    local -r _log_type="${2}"
    local -r _message="${3}"
    # [2] -> where the function that called sucesss() / error() / warn() / info() / debug() is defined
    # [1] -> where sucesss() / error() / warn() / info() / debug() are defined
    # [0] -> where log() is defined
    local -r _script_name=$(basename "${BASH_SOURCE[2]}")
    # [1] -> where sucesss() / error() / warn() / info() / debug() get called
    # [0] -> where log() get called
    local -r _lineno="${BASH_LINENO[1]}"

    if [[ $# -lt 3 ]]; then
        exit_script 'Missing required arguments to log()!' 2
    fi

    local -r _timestamp=$(date +"$TIME_FORMAT")
    if [[ -z "${NO_TIMESTAMP-}" ]]; then
      printf "%s " "$_timestamp"
    fi

    # NOTE: print to stderr here
    printf "$LOG_FORMAT" "$_script_name" "$_lineno" "$_color" "$_log_type" "$_message" "$TA_NONE" >&2 

    if [[ -n "${LOG_FILE-}" ]]; then
      printf "%s $LOG_FORMAT_NO_COLOR" "$_timestamp" "$_script_name" "$_lineno" "$_log_type" "$_message" >> "$LOG_FILE"
    fi
}

function success() { log "${TA_BOLD}${FG_GREEN}" "${LOG_TYPES[0]}" "$@"; }
function error()   { log "${TA_BOLD}${FG_RED}" "${LOG_TYPES[1]}" "$@"; }
function warn()    { log "${TA_BOLD}${FG_YELLOW}" "${LOG_TYPES[2]}" "$@"; }
function info()    { log "${TA_BOLD}${FG_BLUE}" "${LOG_TYPES[3]}" "$@"; }
function debug()   { [[ -n "${DEBUG-}" ]] && log "${TA_NONE}" "${LOG_TYPES[4]}" "$@" || true; }

# DESC: Check whether the script have sudo privillege (via sudo if requested)
# ARGS: $1 (optional): Set to any value to not attempt root access via sudo
# OUTS: None
# RETS: 0 (true) if _superuser credentials were acquired, otherwise 1 (false)
function check_superuser() {
    local _superuser
    if [[ $EUID -eq 0 ]]; then
        _superuser=true
    elif [[ -z ${1-} ]]; then
        # shellcheck disable=SC2310
        if check_binary sudo; then
            info 'Sudo: Updating cached credentials ...'
            if ! sudo -v; then
                error "Sudo: Couldn't acquire credentials ..."
            else
                local _test_euid
                _test_euid="$(sudo -H -- "$BASH" -c 'printf "%s" "$EUID"')"
                if [[ $_test_euid -eq 0 ]]; then
                    _superuser=true
                fi
            fi
        fi
    fi

    if [[ -z ${_superuser-} ]]; then
        error 'Unable to acquire _superuser credentials.'
        return 1
    fi

    success 'Successfully acquired _superuser credentials.'
    return 0
}

# DESC: Run the requested command as root (via sudo if requested)
# ARGS: $1 (optional): Set to zero to not attempt execution via sudo
#       $@ (required): Passed through for execution as root user
# OUTS: None
# RETS: None
function run_as_root() {
    if [[ $# -eq 0 ]]; then
        exit_script 'Missing required argument to run_as_root()!' 2
    fi

    if [[ ${1-} =~ ^0$ ]]; then
        local _skip_sudo=true
        shift
    fi

    if [[ $EUID -eq 0 ]]; then
        "$@"
    elif [[ -z ${_skip_sudo-} ]]; then
        sudo -H -- "$@"
    else
        exit_script "Unable to run requested command as root: $*" 1
    fi
}

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
