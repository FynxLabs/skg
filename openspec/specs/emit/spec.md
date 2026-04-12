# emit Specification

## Purpose
TBD - created by archiving change parser-v02-improvements. Update Purpose after archive.
## Requirements
### Requirement: AST to canonical SKG text
The library SHALL provide an `emit` function that serializes an `ast.File` back to canonical SKG text.

#### Scenario: Round-trip a simple config
- **WHEN** a config is parsed and then emitted
- **THEN** the output is syntactically valid SKG that parses to an equivalent AST

#### Scenario: Canonical formatting
- **WHEN** an AST is emitted
- **THEN** the output uses 2-space indentation, one blank line between top-level blocks, no comments, and a trailing newline

#### Scenario: Emit preserves all value types
- **WHEN** an AST containing int, float, bool, string, null, and array values is emitted
- **THEN** each value is serialized in its canonical form (ints without leading zeros, floats with decimal point, strings with proper escaping, null as `null`, arrays with brackets)

### Requirement: Emit multiline strings
The emit function SHALL serialize multiline string values using triple-quote syntax when the string contains newlines.

#### Scenario: String with newlines emits as triple-quoted
- **WHEN** a string value containing `\n` is emitted
- **THEN** the output uses `"""` delimiters with the content on separate lines

