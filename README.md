# Bash Script Template

[![Tests](https://github.com/Silverbullet069/bash-script-template/actions/workflows/test.yml/badge.svg?branch=main)](https://github.com/Silverbullet069/bash-script-template/actions/workflows/test.yml)
[![Release](https://img.shields.io/github/v/release/Silverbullet069/bash-script-template?include_prereleases&label=version)](https://github.com/Silverbullet069/bash-script-template/releases/latest)
[![License: MIT](https://img.shields.io/github/license/Silverbullet069/bash-script-template)](https://opensource.org/licenses/MIT)

A production-ready Bash scripting template with best practices, robust error handling, and useful utilities built-in.

## Table of Contents

- [Features](#features)
- [Quick Start](#quick-start)
  - [Option 1: Self-contained template](#option-1-self-contained-template)
  - [Option 2: Modular approach](#option-2-modular-approach)
- [Architecture](#architecture)
- [Usage](#usage)
  - [Adding Custom Options](#adding-custom-options)
  - [Built-in Functions](#built-in-functions)
  - [Example Script](#example-script)
- [Design Decisions](#design-decisions)
  - [errexit (set -e)](#errexit-set--e)
  - [nounset (set -u)](#nounset-set--u)
- [License](#license)

## Features

- **Robust error handling** with comprehensive trap handlers
- **Automatic parameter parsing** with help generation
- **Colored logging** with configurable levels (DBG/INF/WRN/ERR)
- **Script locking** to prevent concurrent execution
- **Quiet mode** for silent operation
- **Built-in utilities** for common operations

## Quick Start

### Option 1: Self-contained template

Clone and use the standalone `template.sh`:

```bash
git clone --depth=1 https://github.com/Silverbullet069/bash-script-template.git
cd bash-script-template

# Make cloner executable and symlink it
chmod +x clone_bash_template.sh
ln -s "$(pwd)/clone_bash_template.sh" ~/.local/bin/clone-bash-template

# Create a new script
clone-bash-template path/to/your/script.sh
```

### Option 2: Modular approach

Copy `source.sh` and `script.sh` for customizable projects:

```bash
cp source.sh script.sh /path/to/your/project/
chmod +x /path/to/your/project/script.sh
```

> **Note:** Ensure version compatibility between `source.sh` and `script.sh` when updating.

## Architecture

| File | Purpose |
|------|---------|
| `template.sh` | Self-contained script combining all functionality |
| `source.sh` | Reusable library functions (rarely modified) |
| `script.sh` | Main script template (customize this) |
| `build.sh` | Merges `source.sh` + `script.sh` → `template.sh` |
| `clone_bash_template.sh` | Helper to clone template with placeholder replacement |

## Usage

### Adding Custom Options

Add options to the `parse_params()` function using this pattern:

```bash
function parse_params() {
    # ...
    case "${param}" in
        -m | --mock)
            ### Description for mock option. @DEFAULT:default_value@
            _option_mock="${1}"
            shift
            # Add validation logic here...
            ;;
        # ...
    esac
}
```

**Rules:**
- Lines starting with `###` become help text
- Use `@DEFAULT:value@` to set default values (removed from help)
- For boolean flags, omit the value assignment and shift

### Built-in Functions

```bash
# Logging
info "Information message"
warn "Warning message" 
error "Error message"
debug "Debug message"

# Utilities
check_binary "command" fatal    # Check if command exists
check_superuser                 # Validate sudo access
script_exit "message" 0         # Exit with message
```

### Example Script

```bash
#!/usr/bin/env bash
source source.sh

function parse_params() {
    # Add your custom options here
    case "${param}" in
        -f | --file)
            ### Input file path. @DEFAULT:input.txt@
            _option_file="${1}"
            shift
            ;;
        # ...built-in options...
    esac
}

function main() {
    script_init "$@"
    parse_params "$@"
    
    info "Processing file: ${_option_file}"
    # Your logic here
}

main "$@"
```

## Design Decisions

### errexit (_set -e_)

`set -e` modifies Bash to exit immediately when encountering a non-zero exit code. While controversial due to its complexity and cases where non-zero exits are expected, this template enables it because:

- Scripts compatible with `errexit` work without it, but not vice versa
- Benefits outweigh disadvantages for production scripts
- Can be disabled if needed without breaking functionality

### nounset (_set -u_)

`set -u` exits when expanding unset variables, useful for detecting typos and premature variable usage. Enabled for the same rationale as `errexit` - better to be compatible and allow disabling if needed.

## License

Licensed under [The MIT License](LICENSE).
