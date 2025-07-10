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

# ============================================================================ #
# REGISTRATION                                                                 #
# ============================================================================ #

# option name -> "short|default|help|type|required|constraints"
declare -gA OPTIONS=()

# option name only
declare -ag ORDERS=()

# option name -> value
declare -gA VALUES=()

# DESC: Get option name in long form, given its short form
# ARGS: $1 (required): short option name
# OUTS: Option
# RETS: 0 on success, 2 on failure
function get_long_name() {
    if [[ -z "${1-}" ]]; then
        script_exit "Short option name is empty"
    fi
    local -r param="$1"

    for name in "${!OPTIONS[@]}"; do
        local metadata="${OPTIONS["${name}"]}"
        local short
        IFS="${DELIM}" read -r short _ _ _ _ _ <<<"${metadata}"
        if [[ "${param}" == "${short}" ]]; then
            echo "${name}"
            return 0
        fi
    done

    script_exit "Unknown short option: ${param}"
}

# NOTE: ASCII Unit Separator (0x1F) can't be typed from the keyboard
declare -gr DELIM=$'\x1F'

# Type validation functions mapping
declare -gA VALIDATORS=(
    ["string"]="validate_string"
    ["int"]="validate_integer"
    ["float"]="validate_float"
    ["path"]="validate_path"
    ["file"]="validate_file"
    ["dir"]="validate_directory"
    ["choice"]="validate_choice"
    ["email"]="validate_email"
    ["url"]="validate_url"
    ["bool"]="validate_boolean"
)

# ============================================================================ #

# DESC: Register a command-line option
# ARGS: $1 (required): long-form option name (with -- prefix, e.g. --log-level)
#       $2 (optional): short-form option name (with - prefix, e.g. -l)
#       $3 (optional): default value
#       $4 (optional): help text
#       $5 (optional): type (string|int|float|path|file|dir|choice|email|url|bool)
#       $6 (optional): required (true|false)
#       $7 (optional): constraints (comma-separated for choice type)
function register_option() {
    if [[ -z "${1-}" ]]; then
        script_exit "Option name is empty"
    fi

    local -r name="$1"
    local -r short="${2:-}"
    local -r default="${3:-}"
    local -r help="${4:-"This is a help string"}"
    local -r type="${5:-string}"
    local -r required="${6:-false}"
    local -r constraints="${7:-}"

    OPTIONS["${name}"]="${short}${DELIM}${default}${DELIM}${help}${DELIM}${type}${DELIM}${required}${DELIM}${constraints}"
    ORDERS+=("${name}")
    VALUES["${name}"]="${default}"

    # first validation
    validate_option "${name}"
}

# ============================================================================ #
# TYPE VALIDATION                                                              #
# ============================================================================ #

# DESC: Validate string parameter
# ARGS: $1 (required): value to validate
#       $2 (optional): constraints (not used)
# OUTS: None
# RETS: 0 always (string validation always passes unless empty and required)
function validate_string() {
    if [[ -z "${1-}" ]]; then
        script_exit "String is empty"
    fi

    local -r value="$1"
}

# DESC: Validate integer parameter
# ARGS: $1 (required): value to validate
#       $2 (optional): constraints (format: min,max)
# OUTS: Error message if failure
# RETS: 0 if success, 2 if the argument is not integer or the value doesn't satisfy the containsts
function validate_integer() {
    if [[ -z "${1-}" ]]; then
        script_exit "Integer is empty"
    fi

    local -r value="$1"
    local -r constraints="${2:-}"

    if ! [[ "${value}" =~ ^-?[0-9]+$ ]]; then
        script_exit "Not a valid integer: ${value}"
    fi

    if [[ -n "${constraints}" ]]; then
        # both can be empty, but must have a comma
        if [[ ! "${constraints}" =~ ^-?[0-9]*,?-?[0-9]*$ ]]; then
            script_exit "Invalid constraints format for integer: '${constraints}'. Expected format: min,max"
        fi
        IFS=',' read -r min max <<<"${constraints}"
        if [[ -n "${min}" && "${value}" -lt "${min}" ]]; then
            error "Value ${value} is below minimum ${min}"
            return 1
        fi
        if [[ -n "${max}" && "${value}" -gt "$max" ]]; then
            error "Value ${value} is above maximum ${max}"
            return 1
        fi
    fi
}

# DESC: Validate float parameter
# ARGS: $1 (required): value to validate
#       $2 (optional): constraints (format: min,max)
# OUTS: Error message if failure
# RETS: 0 if success, 2 if the argument is not float or the value doesn't satisfy the constraints
function validate_float() {
    if [[ -z "${1-}" ]]; then
        script_exit "Float is empty"
    fi

    local -r value="$1"
    local -r constraints="${2:-}"

    if ! [[ "${value}" =~ ^-?[0-9]*\.?[0-9]+$ ]]; then
        script_exit "Not a valid float: ${value}"
    fi

    if [[ -n "${constraints}" ]]; then
        # both can be empty, but must have a comma
        if [[ ! "${constraints}" =~ ^-?[0-9]*\.?[0-9]*,?-?[0-9]*\.?[0-9]*$ ]]; then
            script_exit "Invalid constraints format for float: '${constraints}'. Expected format: min,max"
        fi
        IFS=',' read -r min max <<<"${constraints}"

        if [[ -n "${min}" ]]; then
            check_binary "bc" "fatal"
            # shellcheck disable=SC2312
            local -r is_below_min="$(echo "$value < $min" | bc -l)"
            if [[ -n "${is_below_min}" && "${is_below_min}" -eq 1 ]]; then
                script_exit "Value ${value} is below minimum ${min}"
            fi
        fi

        if [[ -n "${max}" ]]; then
            check_binary "bc" "fatal"
            # shellcheck disable=SC2312
            local -r is_above_max="$(echo "$value > $max" | bc -l)"
            if [[ -n "${is_above_max}" && "${is_above_max}" -eq 1 ]]; then
                script_exit "Value ${value} is above maximum ${max}"
            fi
        fi
    fi
}

# DESC: Validate path parameter
# ARGS: $1 (required): value to validate
#       $2 (optional): constraints (not used)
# OUTS: Error message if failure
# RETS: 0 if success, 2 if path is empty
function validate_path() {
    if [[ -z "${1-}" ]]; then
        script_exit "Path is empty"
    fi

    # basic path validation:
    # - absolute path
    # - only alphanumeric, slash, hyphen, underscore are allowed
    # - path must not end with a slash character, except `/` (the root)`
    # ref: https://www.baeldung.com/java-regex-check-linux-path-valid
    # shellcheck disable=SC2312
    local -r value="$(realpath "${1}")"
    if [[ ! "${value}" =~ ^/|(/[_[:alnum:]]+)+$ ]]; then
        script_exit "Not a valid path: ${value}"
    fi
}

# DESC: Validate file parameter
# ARGS: $1 (required): value to validate
#       $2 (optional): constraints (format: must_exist)
# OUTS: Error message if failure
# RETS: 0 if success, 2 if file path is empty or doesn't exist when must_exist is set
function validate_file() {
    if [[ -z "${1-}" ]]; then
        script_exit "File path is empty"
    fi

    # shellcheck disable=SC2312
    local -r value="$(realpath "${1}")"
    local -r constraints="${2:-}"

    # update more constraints in the future...
    if [[ -n "${constraints}" && ! "${constraints}" =~ ^(must_exist)$ ]]; then
        script_exit "Invalid constraints format for file: '${constraints}'. Expected format: must_exist"
    fi

    if [[ "${constraints}" == "must_exist" && ! -f "${value}" ]]; then
        script_exit "File does not exist: ${value}"
    fi
}

# DESC: Validate directory parameter
# ARGS: $1 (required): value to validate
#       $2 (optional): constraints (format: must_exist)
# OUTS: Error message if failure
# RETS: 0 if success, 2 if directory path is empty or doesn't exist when must_exist is set
function validate_directory() {
    if [[ -z "${value}" ]]; then
        script_exit "Directory path is empty"
    fi

    # shellcheck disable=SC2312
    local -r value="$(realpath "${1}")"
    local -r constraints="${2:-}"

    # update more constraints in the future...
    if [[ -n "${constraints}" && ! "${constraints}" =~ ^(must_exist)$ ]]; then
        script_exit "Invalid constraints format for directory: '${constraints}'. Expected format: must_exist"
    fi

    if [[ "${constraints}" == "must_exist" && ! -d "${value}" ]]; then
        script_exit "Directory does not exist: ${value}"
    fi

    return 0
}

# DESC: Validate choice parameter
# ARGS: $1 (required): value to validate
#       $2 (required): constraints (comma-separated)
# OUTS: Error message if failure
# RETS: 0 if success, 2 if choice is invalid or no constraints provided
function validate_choice() {
    if [[ -z "${1-}" ]]; then
        script_exit "Choice value is empty"
    fi
    if [[ -z "${2-}" ]]; then
        script_exit "Constraints is empty"
    fi

    local -r value="$1"
    local -r constraints="$2"

    IFS=',' read -ra choice_array <<<"${constraints}"
    for choice in "${choice_array[@]}"; do
        if [[ "${value}" == "${choice}" ]]; then
            return 0
        fi
    done

    script_exit "Invalid choice: ${value}. Use: ${constraints//,/, }"
}

# DESC: Validate email parameter
# ARGS: $1 (required): value to validate
#       $2 (optional): constraints (not used)
# OUTS: Error message if failure
# RETS: 0 if success, 2 if email format is invalid
function validate_email() {
    if [[ -z "${1-}" ]]; then
        script_exit "Email is empty"
    fi

    local -r value="$1"
    local -r email_regex="^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"

    if ! [[ "${value}" =~ ${email_regex} ]]; then
        script_exit "Not a valid email address: ${value}"
    fi
}

# DESC: Validate URL parameter
# ARGS: $1 (required): value to validate
#       $2 (optional): constraints (not used)
# OUTS: Error message if failure
# RETS: 0 if success, 2 if URL format is invalid
function validate_url() {
    if [[ -z "${1-}" ]]; then
        script_exit "URL is empty"
    fi

    local -r value="$1"
    local -r url_regex="^https?://[a-zA-Z0-9.-]+(\.[a-zA-Z]{2,})?(/.*)?$"

    if ! [[ "${value}" =~ ${url_regex} ]]; then
        script_exit "Not a valid URL: ${value}"
    fi
}

# DESC: Validate boolean parameter
# ARGS: $1 (required): value to validate
#       $2 (optional): constraints (not used)
# OUTS: Error message if failure
# RETS: 0 if success, 2 if boolean format is invalid
function validate_boolean() {
    if [[ -z "${1-}" ]]; then
        script_exit "Boolean is empty"
    fi

    local -r value="$1"
    case "${value,,}" in
    true | false | 1 | 0 | yes | no | y | n)
        return 0
        ;;
    *)
        script_exit "Not a valid boolean value: ${value}. Use: true/false, 1/0, yes/no, y/n"
        ;;
    esac
}

# ============================================================================ #
# OPTION PARSER                                                                #
# ============================================================================ #

# DESC: Parse command-line parameters using declared options and arguments
# ARGS: $@ (optional): Arguments provided to the script
# OUTS: VALUES populated with parsed parameters
# RETS: 0 on success, 2 on failure
function parse_params() {
    readonly OPTIONS ORDERS

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        local param="$1"
        shift

        case "${param}" in
        --help | -h)
            print_help_message
            exit 0
            ;;
        --*=* | -*=* | --* | -*)
            # Handle all option formats: --long=value, -short=value, --option value, -o value

            local name value
            local no_equal=false
            if [[ "${param}" == --*=* ]]; then
                name="${param%%=*}"
                value="${param#*=}"
            elif [[ "${param}" == -*=* ]]; then
                name="$(get_long_name "${param%%=*}")"
                value="${param#*=}"
            elif [[ "${param}" == --* ]]; then
                name="${param}"
                no_equal=true
            elif [[ "${param}" == -* ]]; then
                name="$(get_long_name "${param}")"
                no_equal=true
            fi

            if [[ "${no_equal}" == true ]]; then
                local metadata="${OPTIONS["${name}"]:-}"
                if [[ -z "${metadata}" ]]; then
                    script_exit "Option not found: ${name}"
                fi

                local type
                IFS="${DELIM}" read -r _ _ _ type _ _ <<<"${metadata}"

                if [[ "${type}" == "bool" ]]; then
                    value=true
                else
                    if [[ $# -eq 0 ]]; then
                        script_exit "Option requires a value: ${name}"
                    fi
                    value="${1}"
                    shift
                fi
            fi

            VALUES["${name}"]="${value}"

            # second validation
            validate_option "${name}"
            ;;
        *)
            script_exit "Invalid argument: ${param}"
            ;;
        esac
    done

    # NOTE: seal off the associative array VALUES
    readonly VALUES
}

# DESC: Check if an option has been registered and populated value correctly
# ARGS: $1 (required): Option name in long form
# OUTS: Error message on failure
# RETS: 0 on success, 2 on failure
function validate_option() {
    if [[ -z "${1-}" ]]; then
        script_exit "Option is empty"
    fi
    local -r param="${1}"

    local found=false
    local name
    for name in "${ORDERS[@]}"; do
        if [[ "${name}" == "${param}" ]]; then
            readonly found=true
            break
        fi
    done

    if [[ "${found}" == false ]]; then
        script_exit "Option '${param}' not found"
    fi

    local metadata="${OPTIONS["${name}"]:-}"
    if [[ -z "${metadata}" ]]; then
        script_exit "Option '${name}' has empty metadata"
    fi

    local value="${VALUES["${name}"]:-}"
    if [[ -z "${value}" ]]; then
        script_exit "Option '${name}' has empty value"
    fi

    local short default help type required constraints
    IFS="${DELIM}" read -r short default help type required constraints <<<"${metadata}"

    # short validation
    validate_string "${short}"
    if [[ ! "${short}" =~ ^-[[:alnum:]]$ ]]; then
        script_exit "Option '${name}' has invalid short name '${short}'"
    fi

    # default validation
    validate_string "${default}"

    # help validation
    validate_string "${help}"

    # type validation
    validate_string "${type}"
    local validator="${VALIDATORS["${type}"]:-}"
    if [[ -z "${validator}" ]]; then
        script_exit "Option '${name}' has invalid type '${type}'"
    fi

    # required valiation
    validate_boolean "${required}"

    # constraints validation
    "${validator}" "${default}" "${constraints}"
    "${validator}" "${value}" "${constraints}"
}

# ============================================================================ #
# HELP MESSAGE GENERATION                                                      #
# ============================================================================ #

# DESC: Generate rich help text automatically
# ARGS: None
# OUTS: Help message
# RETS: 0 on success, 2 on failure
function generate_help() {

    echo "Options:"

    local -a displays=()
    local -a helps=()
    local max_width=0

    # NOTE: help message render honors append order
    for name in "${ORDERS[@]}"; do
        local display=""

        # NOTE: add a blank line to separate built-in options with custom options
        if [[ "${name}" == "--help" ]]; then
            displays+=("")
            helps+=("")
        fi

        IFS="${DELIM}" read -r short default help type required constraints <<<"${OPTIONS["${name}"]}"

        display="${name}"
        if [[ -n "${short:-}" ]]; then
            display="${short}, ${name}"
        fi

        if [[ "${type}" == "choice" && -n "${default:-}" ]]; then
            display+="=${default}"
        fi

        if [[ "${required}" == true ]]; then
            help+=" [required]"
        fi

        if [[ -n "${constraints:-}" ]]; then
            help+=" [constraints: ${constraints//,/, }]"
        fi

        displays+=("${display}")
        helps+=("${help}")

        if [[ ${#display} -gt $max_width ]]; then
            max_width=${#display}
        fi
    done

    # dynamic width formatting
    local format_width=$((max_width + 10))
    for i in "${!displays[@]}"; do
        printf "    %-${format_width}s %s\n" "${displays[$i]}" "${helps[$i]}"
    done
}

# ============================================================================ #
# LOGGING                                                                      #
# ============================================================================ #

# NOTE: Important to set first as we use it in _log() and exit handler
# shellcheck disable=SC2155
readonly ta_none="$(tput sgr0 2>/dev/null || true)"

# Log levels associative array with ascending severity
declare -rA LOG_LEVELS=(["DBG"]=0 ["INF"]=1 ["WRN"]=2 ["ERR"]=3)

# DESC: Core logging function - no dependencies, no recursion risk
# ARGS: $1 (required): Log level number (0-3)
#       $2 (required): Color code
#       $3 (required): Log type (3 chars)
#       $4+ (required): Message
# OUTS: Formatted log message to stderr
# RETS: 0
function _log() {

    # caller validation
    for func in "${FUNCNAME[@]}"; do
        case "${func}" in
        script_trap_err | script_trap_exit | script_exit)
            script_exit "log system shouldn't be used inside script_trap_err, script_trap_exit, script_exit"
            ;;
        *)
            continue
            ;;
        esac
    done

    local -r level_num="$1"
    local color="$2"
    local -r log_type="$3"
    shift 3
    local log_message="$*"
    local timestamp=""

    # skip if _log is called before parse_params
    local -r log_level="${VALUES["--log-level"]:-}"
    if [[ -n "${log_level}" ]]; then
        local -r global_level_num="${LOG_LEVELS["${log_level}"]:-}"
        if [[ -n "${global_level_num}" && "${level_num}" -lt "${global_level_num}" ]]; then
            return 0
        fi
    fi

    # skip if _log is called before parse_params
    local -r is_no_color="${VALUES["--no-color"]:-}"
    if [[ -n "${is_no_color}" && "${is_no_color}" == true ]]; then
        color="${ta_none}"
    fi

    # skip if _log is called before parse_params
    local -r is_timestamp="${VALUES["--timestamp"]:-}"
    if [[ -n "${is_timestamp}" && "${is_timestamp}" == true ]]; then
        timestamp="$(date +"[%Y-%m-%d %H:%M:%S %z]") "
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

    # Simple path colorization
    if [[ "${log_message}" =~ ^(/|\./|~/) ]]; then
        log_message="${fg_green:-$ta_none}${log_message}${ta_none}"
    fi

    # Replace $HOME with ~ (safe parameter expansion)
    log_message="${log_message//\/home\/${USER-}/\~}"

    # Log to stdout
    printf "%s%s[%d]: %b[%s]%b %s\n" \
        "${timestamp}" "${caller}" "${lineno}" \
        "${color}" "${log_type}" "${ta_none}" \
        "${log_message}"
}

# List of logging functions in different levels
function debug() { _log "${LOG_LEVELS["DBG"]}" "${ta_none}" "DBG" "$@"; }
function info() { _log "${LOG_LEVELS["INF"]}" "${ta_bold:-$ta_none}${fg_blue:-$ta_none}" "INF" "$@"; }
function warn() { _log "${LOG_LEVELS["WRN"]}" "${ta_bold:-$ta_none}${fg_yellow:-$ta_none}" "WRN" "$@"; }
function error() { _log "${LOG_LEVELS["ERR"]}" "${ta_bold:-$ta_none}${fg_red:-$ta_none}" "ERR" "$@" >&2; }
function critical() {
    printf "%b%s%b" \
        "${ta_bold-$ta_none}${bg_red-$ta_none}${fg_white-$ta_none}" \
        "CRITICAL FAILURE - $*" \
        "${ta_none}\n" >&2
}

# ============================================================================ #

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
    local -r exit_code="${1:-1}"

    # Output debug data if in Quiet mode - direct check without function calls
    if [[ "${VALUES["--quiet"]:-}" == true ]]; then
        # Restore original file output descriptors
        if [[ -n "${script_output:-}" ]]; then
            exec 1>&3 2>&4
        fi

        # Print basic debugging information using printf to avoid recursion
        critical "Abnormal termination of script"
        critical "Script Path:       ${script_path:-unknown}"
        critical "Script Parameters: ${script_params:-none}"
        critical "Script Exit Code:  ${exit_code}"

        # Print the script log if we have it
        if [[ -n "${script_output:-}" ]]; then
            critical "Script Output:"
            cat "${script_output}" >&2 || true
        else
            critical "Script Output: none (failed before log init)"
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

    # Remove Quiet mode script log - direct check without function calls
    # NOTE: default value exception
    if [[ "${VALUES["--quiet"]-}" == true && -n "${script_output-}" ]]; then
        rm "${script_output}"
        echo "Cleaned up script output: ${script_output}"
    fi

    # Remove script execution lock
    if [[ -d "${script_lock-}" ]]; then
        rmdir "${script_lock}"
        echo "Cleaned up script lock: ${script_lock}"
    fi

    # Restore terminal colors
    printf '%b' "${ta_none}"
}

# DESC: Exit script with the given message
# ARGS: $1 (required): Error message to print on exit
# OUTS: None
# RETS: None
# NOTE: The convention used in this script for exit codes is:
#       1: Abnormal exit due to external error (missing dependency, network is not accessible, target dir existed, )
#       2: Abnormal exit due to script error (empty argument, undefined options, ...)
function script_exit() {
    if [[ -z "${1-}" ]]; then
        critical "${FUNCNAME[0]}: Invalid arguments: $*"
        exit 2
    fi

    critical "${FUNCNAME[1]}: ${1}"
    script_trap_err 3
}

# DESC: Initialise color variables
# ARGS: None
# OUTS: Read-only variables with ANSI control codes
# RETS: None
# NOTE: If --no-color was set the variables will be empty. The output of the
#       $ta_none variable after each tput is redundant during normal execution,
#       but ensures the terminal output isn't mangled when running with xtrace.
# shellcheck disable=SC2034,SC2155
function color_init() {

    # NOTE: no need default value here, color_init() runs after parse_params()
    if [[ "${VALUES["--no-color"]}" == false ]]; then
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

    # NOTE: quiet_init() runs after parse_params(), there is no need for default value
    if [[ "${VALUES["--quiet"]}" == true ]]; then
        # Redirect all output to a temporary file

        # CAUTION: comparable with BusyBox mktemp inside Alpine Image
        readonly script_output="$(mktemp -p "/tmp" "${script_name}.XXXXXX")"
        exec 3>&1 4>&2 1>"${script_output}" 2>&1
    fi
}

# DESC: Acquire script lock
# ARGS: $1 (required): Scope of script execution lock (system or user)
# OUTS: $script_lock: Path to the directory indicating we have the script lock
# RETS: None
# NOTE: This lock implementation is extremely simple but should be reliable
#       across all platforms. It does *not* support locking a script with
#       symlinks or multiple hardlinks as there's no portable way of doing so.
#       If the lock was acquired it's automatically released on script exit.
function lock_init() {
    if [[ -z "${1-}" ]]; then
        script_exit "Scope is empty"
    fi
    local -r scope="${1}"
    local lock_dir
    if [[ "${scope}" = "system" ]]; then
        lock_dir="/tmp/${script_name}.lock"
    elif [[ "${scope}" = "user" ]]; then
        lock_dir="/tmp/${script_name}.${UID}.lock"
    else
        script_exit "Invalid scope: ${1}"
    fi

    if mkdir "${lock_dir}" 2>/dev/null; then
        readonly script_lock="${lock_dir}"
        echo "Acquired script lock: ${script_lock}"
    else
        script_exit "Unable to acquire script lock: ${lock_dir}"
    fi
}

# DESC: Combines two path variables and removes any duplicates
# ARGS: $1 (required): Path(s) to join with the second argument
#       $2 (optional): Path(s) to join with the first argument
# OUTS: $build_path: The constructed path
# RETS: None
# NOTE: Heavily inspired by: https://unix.stackexchange.com/a/40973
function build_path() {
    if [[ -z "${1-}" ]]; then
        script_exit "Path is empty"
    fi

    local temp_path="${1}:"
    if [[ -n "${2:-}" ]]; then
        temp_path="${temp_path}${2}:"
    fi

    local new_path=
    while [[ -n "${temp_path:-}" ]]; do
        local -r path_entry="${temp_path%%:*}"
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
    if [[ -z "${1-}" ]]; then
        script_exit "Binary is empty"
    fi
    local -r binary="${1}"
    local -r fatal="${2:-}"

    if ! command -v "${binary}" >/dev/null 2>&1; then
        if [[ -n "${fatal}" ]]; then
            script_exit "Missing dependency '${binary}'"
        else
            error "Missing dependency '${binary}'"
            return 1
        fi
    fi

    info "Found dependency '${binary}'"
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
# ARGS: $1 (optional): Set to --no-sudo or -n to not attempt execution via sudo
#       $@ (required): Passed through for execution as root user
# OUTS: None
# RETS: 0 on success, 1 on failure
function run_as_root() {
    local skip_sudo=
    if [[ "${1-}" =~ ^(--no-sudo|-n)$ ]]; then
        skip_sudo=true
        shift
    fi

    if [[ "${EUID}" -eq 0 ]]; then
        "$@"
    elif [[ -z "${skip_sudo}" ]]; then
        # shellcheck disable=SC2310
        if ! check_binary sudo; then
            script_exit "'sudo' binary is not available."
        fi
        warn "Run the following command with sudo privilege:"
        warn "$*"
        sudo -H -- "$@"
    else
        error "Cannot run command as root: not root user and sudo disabled"
        return 1
    fi
}

# DESC: Register the a set of options
# ARGS: None
# OUTS: OPTIONS, ORDERS and VALUES are populated with data
# RETS: 0
function option_init() {
    # NOTE: long-name, short-name, default, help, type, required, constraints
    # register_option ...

    # CAUTION: --help must be placed as the first option in the built-in options list
    # CAUTION: I add a blank link on top of this function inside help message
    register_option "--help" "-h" false "Display this help and exit" "bool"
    register_option "--log-level" "-l" "INF" "Specify log level" "choice" false "DBG,INF,WRN,ERR"
    register_option "--timestamp" "-t" false "Enable timestamp output" "bool"
    register_option "--no-color" "-n" false "Disable color output" "bool"
    register_option "--quiet" "-q" false "Run silently unless an error is encountered" "bool"
}

# DESC: Print help message when user declare --help, -h option
# ARGS: None
# OUTS: Help message
# RETS: 0
function print_help_message() {

    cat <<EOF

Usage: [DEBUG=1] @NAME@ [OPTIONS]

Add short description and examples here...

Example:

    Add some examples here...

EOF

    generate_help

}

# DESC: Main control flow
# ARGS: $@ (optional): Arguments provided to the script
# OUTS: None
# RETS: None
function main() {
    trap script_trap_err ERR
    trap script_trap_exit EXIT

    script_init "$@"
    option_init
    parse_params "$@"
    quiet_init
    color_init
    lock_init user

    # start here
    # shellcheck disable=SC2154
    debug "script_params: ${script_params}"
    # shellcheck disable=SC2154
    debug "script_path: ${script_path}"
    # shellcheck disable=SC2154
    debug "script_dir: ${script_dir}"
    # shellcheck disable=SC2154
    debug "script_name: ${script_name}"

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
