# skg-cli Specification

## Purpose
Define the `skg` CLI binary - a formatting tool for `.skg` files, designed for editor integration and CI pipelines.
## Requirements
### Requirement: skg fmt reformats files to canonical style
The `skg fmt` command SHALL read one or more `.skg` files, parse them, and write canonical formatting back to the same files. Canonical formatting uses 2-space indentation, consistent spacing around colons and braces, one blank line between top-level blocks, and a trailing newline.

#### Scenario: Format a single file
- **WHEN** `skg fmt config.skg` is run
- **THEN** `config.skg` is overwritten with canonically formatted content
- **AND** all comments are preserved

#### Scenario: Format multiple files
- **WHEN** `skg fmt a.skg b.skg c.skg` is run
- **THEN** all three files are reformatted independently

#### Scenario: Already canonical file is unchanged
- **WHEN** `skg fmt` is run on a file that is already canonically formatted
- **THEN** the file content does not change

### Requirement: skg fmt --check validates formatting without modifying files
The `skg fmt --check` command SHALL compare each file's current content against its canonical form. It SHALL exit 0 if all files are canonical, exit 1 if any file differs, and print the names of non-canonical files to stdout.

#### Scenario: All files canonical
- **WHEN** `skg fmt --check a.skg b.skg` is run and both files are canonical
- **THEN** exit code is 0 and no output is printed

#### Scenario: Non-canonical file detected
- **WHEN** `skg fmt --check messy.skg` is run and `messy.skg` is not canonical
- **THEN** exit code is 1 and `messy.skg` is printed to stdout

#### Scenario: Mix of canonical and non-canonical
- **WHEN** `skg fmt --check good.skg bad.skg` is run
- **THEN** exit code is 1 and only `bad.skg` is printed to stdout

### Requirement: skg fmt exits with error on parse failure
The `skg fmt` command SHALL NOT silently ignore files with syntax errors. If a file fails to parse, the command SHALL print the parse error with file path and location, skip that file, and exit with a non-zero code.

#### Scenario: Malformed file
- **WHEN** `skg fmt broken.skg` is run and `broken.skg` has a syntax error
- **THEN** the error message includes the file path, line, and column
- **AND** `broken.skg` is not modified
- **AND** the exit code is non-zero

### Requirement: skg fmt --stdin reads from stdin and writes to stdout
The `skg fmt --stdin` flag SHALL read SKG source from stdin, format it, and write the canonical output to stdout. Combined with `--check`, it SHALL exit 1 if stdin content is not canonical (without printing output).

#### Scenario: Pipe through stdin
- **WHEN** `echo 'name: "x"' | skg fmt --stdin` is run
- **THEN** canonically formatted output is printed to stdout

#### Scenario: Stdin check mode
- **WHEN** non-canonical content is piped to `skg fmt --stdin --check`
- **THEN** exit code is 1 and `<stdin>: not formatted` is printed to stderr

