# parser Specification

## Purpose
Specifies the SKG configuration language parser - a self-contained lexer, parser, and AST layer with zero external dependencies beyond Zig's standard library. SKG (Static Key Group) is a simple hierarchical key-value format with nested blocks, supporting string, integer, float, and boolean values. The parser also supports merging multiple config files with override semantics.
## Requirements
### Requirement: Lexical analysis
The SKG parser SHALL tokenize input into: identifiers, string literals, multiline string literals, numeric literals, boolean literals, null literals, colons, braces, comments, and newlines. Comment tokens SHALL be emitted for `#` lines instead of being discarded.

#### Scenario: Simple key-value pair
- **WHEN** input is `key: "value"`
- **THEN** lexer produces tokens: identifier("key"), colon, string("value")

#### Scenario: Nested block
- **WHEN** input is `block { inner: 1 }`
- **THEN** lexer produces tokens: identifier("block"), open_brace, identifier("inner"), colon, number(1), close_brace

#### Scenario: Null literal
- **WHEN** input is `key: null`
- **THEN** lexer produces tokens: identifier("key"), colon, null

#### Scenario: Multiline string literal
- **WHEN** input contains `"""` followed by a newline, content, and a closing `"""`
- **THEN** lexer produces a single multiline_string token containing the raw content between delimiters

#### Scenario: Comment token
- **WHEN** input contains `# this is a comment`
- **THEN** lexer produces a comment token with text `# this is a comment`

### Requirement: Parsing into AST
The SKG parser SHALL parse token streams into an AST of nodes containing key-value pairs and nested blocks. Duplicate fields within a single file SHALL be resolved with last-wins semantics - the second occurrence replaces the first in the AST. Comment tokens SHALL be collected and attached to adjacent nodes as trivia.

#### Scenario: Hierarchical config
- **WHEN** input contains nested blocks with key-value pairs
- **THEN** the AST reflects the block hierarchy with each node containing its children and properties

#### Scenario: Malformed input
- **WHEN** input has syntax errors (unclosed braces, missing colons)
- **THEN** the parser returns an error with location information

#### Scenario: Duplicate field last-wins
- **WHEN** a file contains `key: "first"` and later `key: "second"` at the same level
- **THEN** the AST contains only one field node for `key` with value `"second"`

#### Scenario: Comments attached to nodes
- **WHEN** input contains `# description` followed by `key: "value"`
- **THEN** the field node's `leading_comments` contains `# description`

### Requirement: Config file merging
The SKG parser SHALL support merging multiple parsed config files, with later values overriding earlier ones. Merge SHALL use hash-map lookup for O(n+m) performance.

#### Scenario: Override a value
- **WHEN** two configs define the same key with different values
- **THEN** the merged result contains the value from the later config

### Requirement: No external dependencies
The SKG parser SHALL depend only on Zig's standard library and its own internal modules. SKG is project-agnostic - no consuming application code may be imported.

#### Scenario: Clean import graph
- **WHEN** examining the import graph of `zig/*.zig` (excluding tests)
- **THEN** no file imports from outside `zig/` or `std`

### Requirement: Value types
The SKG parser SHALL support string, multiline string, integer, float, boolean, null, and array value types. Arrays may be nested.

#### Scenario: Boolean value
- **WHEN** input is `key: true`
- **THEN** the AST contains a boolean node with value true

#### Scenario: Quoted string with spaces
- **WHEN** input is `key: "hello world"`
- **THEN** the AST contains a string node with value "hello world"

#### Scenario: Numeric value
- **WHEN** input is `key: 1.5`
- **THEN** the AST contains a float node with value 1.5

#### Scenario: Null value
- **WHEN** input is `key: null`
- **THEN** the AST contains a null node

#### Scenario: Multiline string value
- **WHEN** input contains a field with triple-quoted value
- **THEN** the AST contains a string node with the literal content between the `"""` delimiters

#### Scenario: Nested array
- **WHEN** input is `matrix: [[1, 2], [3, 4]]`
- **THEN** the AST contains an array of arrays, each inner array containing integer values

### Requirement: Import resolver abstraction
The parser SHALL accept an optional import resolver callback that replaces the default filesystem-based import resolution. When no resolver is provided, the parser SHALL use `std.fs` as before.

#### Scenario: Custom import resolver
- **WHEN** a consumer provides an import resolver callback and parses a file with `import "./theme.skg"`
- **THEN** the parser calls the resolver with the resolved path instead of reading from disk

#### Scenario: Default filesystem resolution
- **WHEN** no import resolver is provided
- **THEN** the parser reads imports from disk via `std.fs`, identical to current behavior

### Requirement: skg_version as string
The `skg_version` declaration SHALL be a quoted string value, not a float.

#### Scenario: String skg_version
- **WHEN** input is `skg_version: "1.0"`
- **THEN** the AST records skg_version as the string `"1.0"`

#### Scenario: Float skg_version rejected
- **WHEN** input is `skg_version: 1.0` (unquoted float)
- **THEN** the parser rejects it with an error

### Requirement: File size cap
The parser SHALL reject files larger than 10MB with a clear error, preventing accidental OOM from oversized inputs.

#### Scenario: Oversized file rejected
- **WHEN** a file larger than 10MB is passed to `parse()`
- **THEN** the parser returns an error without attempting to allocate the full file contents

### Requirement: Spec examples as tests
All code examples in `docs/spec.md` tagged as valid SKG SHALL be parseable by the parser. Examples tagged as invalid SHALL be rejected. This is enforced by the test suite.

#### Scenario: Valid spec example parses
- **WHEN** a code block from the spec marked as valid SKG is fed to `parseSource`
- **THEN** parsing succeeds without error

#### Scenario: Invalid spec example rejected
- **WHEN** a code block from the spec marked as invalid SKG is fed to `parseSource`
- **THEN** parsing fails with an appropriate error

