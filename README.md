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
- **Automatic parameters parsing** with help generation
- **Colored logging** with configurable levels (DBG/INF/WRN/ERR)
- **Script locking** to prevent concurrent execution
- **Quiet mode** for silent operation
- **Built-in utilities** for common operations
- **Flexible modes** given 3 scripting strategy: full template, lite template and 1 source - N scripts.

## Quick Start

Clone the repository:

```sh
git clone --depth=1 https://github.com/Silverbullet069/bash-script-template.git
cd bash-script-template
```

By default, downloaded script files aren't executable. Change file permission:

```sh
chmod +x script.sh template.sh template_lite.sh clone_bash_template.sh
```

Create a symlink out of `clone_bash_template.sh`:

> [!IMPORTANT]
>
> Make sure `~/.local/bin` is inside your `PATH` environment variable.

```sh
ln -s "$(PWD)/clone_bash_template.sh" ~/.local/bin/clone-bash-template
```

Choose your preferred approach:

**Option 1: Self-contained template:** for simple, standalone scripts

```sh
# Full-featured template (recommended for most cases)
clone-bash-template -o path/to/your/script.sh

# Lightweight template (minimal features)
clone-bash-template -m lite -o path/to/your/script.sh
```

**Option 2: Modular approach:** for projects with multiple scripts sharing common utilities

```sh
# Creates both source.sh (library) and script.sh (template)
clone-bash-template -m source+script -o path/to/your/project/
```

> [!TIP]
> Use `.bash` extension if preferred - both `.sh` and `.bash` are supported.

> [!WARNING]
>
> Ensure version compatibility between old/new `source.sh` and old/new `script.sh` when updating.

## Architecture

| File | Purpose |
|------|---------|
| `template.sh` | Self-contained script combining all functionality |
| `template_lite.sh` | A small, simple yet reliable template script |
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

            # Add validation logic here
            # ...

            # variable naming convention: _option_<option-name>
            _option_mock="${1-}"
            shift
            ;;
        # ...
    esac
}
```

### Auto parsing rules

- Lines starting with `###` become help text displayed when specified `-h|--help` option
- Use `@DEFAULT:value@` to set default values. It's automatically removed from help text.
- For boolean flags, omit the value assignment and shift.

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
