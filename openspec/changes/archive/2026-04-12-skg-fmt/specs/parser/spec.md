## MODIFIED Requirements

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
The SKG parser SHALL parse token streams into an AST of nodes containing key-value pairs and nested blocks. Duplicate fields within a single file SHALL be resolved with last-wins semantics — the second occurrence replaces the first in the AST. Comment tokens SHALL be collected and attached to adjacent nodes as trivia.

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
