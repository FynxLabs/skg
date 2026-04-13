## MODIFIED Requirements

### Requirement: AST to canonical SKG text
The library SHALL provide an `emit` function that serializes an `ast.File` back to canonical SKG text, including all attached comment trivia.

#### Scenario: Round-trip a simple config
- **WHEN** a config is parsed and then emitted
- **THEN** the output is syntactically valid SKG that parses to an equivalent AST

#### Scenario: Canonical formatting
- **WHEN** an AST is emitted
- **THEN** the output uses 2-space indentation, one blank line between top-level blocks, preserved comments at correct indentation, and a trailing newline

#### Scenario: Emit preserves all value types
- **WHEN** an AST containing int, float, bool, string, null, and array values is emitted
- **THEN** each value is serialized in its canonical form (ints without leading zeros, floats with decimal point, strings with proper escaping, null as `null`, arrays with brackets)

#### Scenario: Leading comments emitted before nodes
- **WHEN** a node has `leading_comments` attached
- **THEN** each comment is emitted on its own line at the current indentation level, immediately before the node

#### Scenario: Trailing inline comments emitted after fields
- **WHEN** a field has a `trailing_comment` attached
- **THEN** the comment is emitted on the same line as the field value, separated by a space
