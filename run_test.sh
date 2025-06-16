#!/usr/bin/env bash

## FILE        : run_dev.sh
## VERSION     : v2.2.0
## DESCRIPTION : Execute runtime inside an isolated containerized environment
## AUTHOR      : Silverbullet069
## REPOSITORY  : https://github.com/Silverbullet069/bash-script-template
## LICENSE     : MIT License

# ============================================================================ #

# Enable xtrace if the DEBUG environment variable is set
if [[ ${DEBUG-} =~ ^1|yes|true$ ]]; then
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
#IFS=$' '

function main() {

    docker run \
        --name="bash-script-template-test" \
        --init \
        --rm \
        --user="$(id -u):$(id -g)" \
        --network none \
        --security-opt=no-new-privileges:true \
        --volume="$(pwd):/app" \
        --workdir="/app" \
        --env="SCRIPT_NAME=${SCRIPT_NAME:-script.sh}" \
        node:lts-bookworm-slim \
        "$@"
}

# Invoke main with args if not sourced
if ! (return 0 2> /dev/null); then
    main "$@"
fi
