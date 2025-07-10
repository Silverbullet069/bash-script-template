#!/usr/bin/env bash

# ============================================================================ #

## FILE         : build.sh
## VERSION      : v3.0.0
## DESCRIPTION  : Merge source and script into template
## AUTHOR       : silverbullet069
## REPOSITORY   : https://github.com/Silverbullet069/bash-script-template
## LICENSE      : BSD-3-Clause

## TEMREPO      : https://github.com/Silverbullet069/bash-script-template
## TEMMODE      : lite
## TEMVER       : v3.0.0
## TEMUPDATED   : 2025-06-21 19:15:03.788041997 +0700
## TEMLIC       : BSD-3-Clause

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

function build() {
    local -r source_path="${1}"
    local -r script_path="${2}"
    local -r template_path="${3}"

    if [[ ! -f "${source_path}" ]]; then
        echo "source.sh not found: ${script_path}" >&2
        exit 1
    fi

    if [[ ! -r "${source_path}" ]]; then
        echo "source.sh is unreadable: ${script_path}" >&2
        exit 1
    fi

    if [[ ! -f "${script_path}" ]]; then
        echo "script.sh not found: ${script_path}" >&2
        exit 1
    fi

    if [[ ! -r "${script_path}" ]]; then
        echo "script.sh is unreadable: ${script_path}" >&2
        exit 1
    fi

    # NOTE: Update the arbitrary values if header changes
    local -r script_header=$(head -n 18 "${script_path}")
    local -r source_body=$(tail -n +12 "${source_path}")
    local -r script_body=$(tail -n +19 "${script_path}" | grep -vE -e '^# shellcheck source=source.sh$' -e '^# shellcheck disable=SC1091$' -e '^source.*source\.sh"$')

    chmod 755 "${template_path}"
    {
        echo "${script_header}"
        echo "${source_body}"
        echo "${script_body}"
    } >"${template_path}"

    chmod 555 "${template_path}"
    echo "Build ${template_path} successfully."
}

function cleanup() {
    echo "Stopping file monitor..."
    exit 0
}

# Main control flow
function main() {
    trap script_trap_exit EXIT
    lock_init "user"

    local -r source_path="$(dirname "${BASH_SOURCE[0]}")/source.sh"
    local -r script_path="$(dirname "${BASH_SOURCE[0]}")/script.sh"
    local -r template_path="$(dirname "${BASH_SOURCE[0]}")/template.sh"

    # initial build
    build "${source_path}" "${script_path}" "${template_path}"

    # simple dev server
    if [[ "${1-}" =~ ^(--monitor|-m)$ ]]; then
        # gracefully stopping dev server
        trap cleanup SIGINT SIGTERM SIGHUP

        inotifywait \
            --monitor \
            --event "close_write" \
            "${source_path}" "${script_path}" \
            | while read -r dir event file; do
                echo "Change detected: ${event} on ${dir}${file}"
                # NOTE: add a small delay to allow accumulation of multiple changes
                sleep 1
                build "${source_path}" "${script_path}" "${template_path}"
            done
    fi
}

# Invoke main with args if not sourced
if ! (return 0 2>/dev/null); then
    main "$@"
fi
