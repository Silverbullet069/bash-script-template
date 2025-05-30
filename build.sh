#!/usr/bin/env bash

## FILE        : #~NAME~#
## DESCRIPTION : Build script that merge source.sh and script.sh into one
## CREATED     : #~TIME~#
## TEMVER      : #~VERSION~#
## AUTHOR      : ralish (https://github.com/ralish/)
## CONTRIBUTOR : Silverbullet069 (https://github.com/Silverbullet069/)
## LICENSE     : MIT License

# ============================================================================ #

# Assembles the all-in-one template script by combining source.sh & script.sh

# Enable xtrace if the DEBUG environment variable is set
if [[ ${DEBUG-} =~ ^1|yes|true$ ]]; then
    set -o xtrace       # Trace the execution of the script (debug)
fi

# A better class of script...
set -o errexit          # Exit on most errors (see the manual)
set -o errtrace         # Make sure any error trap is inherited
set -o nounset          # Disallow expansion of unset variables
set -o pipefail         # Use last non-zero exit code in a pipeline

# Main control flow
function main() {

    source_content_no_header=$(tail -n +14 source.sh)
    script_header=$(head -n 13 script.sh)
    script_content_no_header=$(tail -n +14 script.sh)
    # Remove shellcheck source lines
    script_content_no_header=$(echo "${script_content_no_header}" | grep -v "# shellcheck source=source.sh" | grep -v "# shellcheck disable=SC1091" | grep -v '^source.*source\.sh"')

    # Combine parts in desired order and write to template.sh
    {
        echo "${script_header}"
        echo "${source_content_no_header}"
        echo "${script_content_no_header}"
    } > template.sh

    # Make template.sh executable
    chmod +x template.sh
    echo "Build template.sh successfully"
}

# Template, assemble
main

# vim: syntax=sh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
