#!/usr/bin/env bash

## FILE        : build.sh
## VERSION     : v2.3.0
## DESCRIPTION : Merge source.sh and script.sh to template.sh
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

    local -r source_body=$(sed -n '/# =\+/,$p' source.sh | tail -n +2) || true

    # NOTE: leave the comment divider
    local -r script_header=$(sed -n '1,/# =\+/p' script.sh) || true

    # Extract + remove shellcheck source lines
    local -r script_body=$(sed -n '/# =\+/,$p' script.sh | tail -n +2 | grep -v -e "# shellcheck source=source.sh" -e "# shellcheck disable=SC1091" -e '^source.*source\.sh"') || true

    # Combine parts in desired order and write to template.sh
    {
        echo "${script_header}"
        echo "${source_body}"
        echo "${script_body}"
    } > template.sh

    # Make template.sh executable
    chmod +x template.sh

    echo "Build template.sh successfully"
}

# Template, assemble
main "$@"
