#!/usr/bin/env bash

## FILE        : clone_bash_template.sh
## VERSION     : v2.1.4
## DESCRIPTION : Clone the template.sh or source.sh + script.sh
## AUTHOR      : Silverbullet069
## REPOSITORY  : https://github.com/Silverbullet069/bash-script-template
## LICENSE     : MIT License

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

    local target_file="$(realpath "$1")"

    # Resolve symlink if this script is executed as one
    local script_path="${BASH_SOURCE[0]}"
    if [[ -L "${script_path}" ]]; then
        script_path="$(readlink -f "${script_path}")"
    fi
    local template_path="$(dirname "${script_path}")/template.sh"

    # Verify template exists
    if [[ ! -f "${template_path}" ]]; then
        echo "Error: Template file not found at ${template_path}" >&2
        return 1
    fi

    # Check file extension
    if [[ "${target_file}" == *.* ]] && [[ "${target_file}" != *.sh ]] && [[ "${target_file}" != *.bash ]]; then
        echo 'Error: Extension not supported. Please use ".sh" or ".bash" extension.' >&2
        return 1
    fi
    # Extensionless is perfectly fine

    # Copy template, if existed prompt to override
    cp -i "${template_path}" "${target_file}"

    # Make the file executable
    chmod +x "${target_file}"

    # Get filename (without path)
    local name=$(basename "${target_file}")
    local time=$(date +"%F %T %Z")

    # Replace placeholders in a single pass
    sed -i \
        -e "s|@NAME@|${name}|g" \
        -e "s|@TIME@|${time}|g" \
        "${target_file}"

    echo "Script generated successfully at ${target_file}" >&2
}

main "$@"
