#!/usr/bin/env bash

# ============================================================================ #

## FILE         : build.sh
## VERSION      : v0.0.1
## DESCRIPTION  : Merge source.sh and script.sh to template.sh
## AUTHOR       : silverbullet069
## REPOSITORY   : https://github.com/Silverbullet069/bash-script-template
## LICENSE      : MIT License

## TEMREPO      : https://github.com/Silverbullet069/bash-script-template
## TEMMODE      : lite
## TEMUPDATED   : 2025-06-21 19:15:03.788041997 +0700
## TEMLIC       : MIT License

# ============================================================================ #

# DESC: Acquire script lock, extracted from script.sh
# ARGS: $1 (optional): Scope of script execution lock (system or user)
# OUTS: None
# RETS: None
# NOTE: This lock implementation is extremely simple but should be reliable
#       across all platforms. It does *not* support locking a script with
#       symlinks or multiple hardlinks as there's no portable way of doing so.
#       If the lock was acquired it's automatically released on script exit.
function lock_init() {
    local lock_dir
    if [[ "${1}" = "system" ]]; then
        lock_dir="/tmp/$(basename "${BASH_SOURCE[0]}").lock"
    elif [[ "${1}" = "user" ]]; then
        lock_dir="/tmp/$(basename "${BASH_SOURCE[0]}").${UID}.lock"
    else
        echo "Missing or invalid argument to ${FUNCNAME[0]}()!" >&2
        exit 1
    fi

    if mkdir "${lock_dir}" 2>/dev/null; then
        readonly script_lock="${lock_dir}"
        echo "Acquired script lock: ${script_lock}"
    else
        echo "Unable to acquire script lock: ${lock_dir}" >&2
        exit 2
    fi
}

# DESC: Handler for exiting the script
# ARGS: None
# OUTS: None
# RETS: None
function script_trap_exit() {
    # Remove script execution lock
    if [[ -d "${script_lock-}" ]]; then
        rmdir "${script_lock}"
        echo "Clean up script lock: ${script_lock}" >&2
    fi
}

# ============================================================================ #

# Enable xtrace if the DEBUG environment variable is set
if [[ ${DEBUG-} =~ ^1|yes|true$ ]]; then
    set -o xtrace # Trace the execution of the script (debug)
fi

# A better class of script...
set -o errexit  # Exit on most errors (see the manual)
set -o errtrace # Make sure any error trap is inherited
set -o nounset  # Disallow expansion of unset variables
set -o pipefail # Use last non-zero exit code in a pipeline

# Main control flow
function main() {
    trap script_trap_exit EXIT
    lock_init "user"

    local -r script_dir="$(dirname "${BASH_SOURCE[0]}")"

    # Check if required files exist
    if [[ ! -f "${script_dir}/script.sh" ]]; then
        echo "Error: script.sh not found in ${script_dir}" >&2
        exit 1
    fi

    if [[ ! -f "${script_dir}/source.sh" ]]; then
        echo "Error: source.sh not found in ${script_dir}" >&2
        exit 1
    fi

    # Arbitrary values
    # shellcheck disable=SC2312
    local -r script_header=$(head -n 17 "${script_dir}/script.sh" || exit 1)
    # shellcheck disable=SC2312
    local -r source_body=$(tail -n +12 "${script_dir}/source.sh" || exit 1)
    # shellcheck disable=SC2312
    local -r script_body=$(tail -n +18 "${script_dir}/script.sh" | grep -vE -e '^# shellcheck source=source.sh$' -e '^# shellcheck disable=SC1091$' -e '^source.*source\.sh"$' || exit 1)

    # Combine parts in desired order and write to template.sh
    # Make template.sh temporately writeable for updating
    chmod 755 "${script_dir}/template.sh"
    {
        echo "${script_header}"
        echo "${source_body}"
        echo "${script_body}"
    } >"${script_dir}/template.sh"

    # Make template.sh executable and read-only
    # Any changes to template.sh must go through source.sh and script.sh
    chmod 555 "${script_dir}/template.sh"

    echo "Build template.sh successfully."
}

# Template, assemble
main "$@"
