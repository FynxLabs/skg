# parser Specification

## Purpose
Specifies the SKG configuration language parser — a self-contained lexer, parser, and AST layer with zero external dependencies beyond Zig's standard library. SKG (Static Key Graph) is a simple hierarchical key-value format with nested blocks, supporting string, integer, float, and boolean values. The parser also supports merging multiple config files with override semantics.

## Requirements

### Requirement: Lexical analysis
The SKG parser SHALL tokenize input into: identifiers, string literals, numeric literals, boolean literals, colons, braces, comments, and newlines.

#### Scenario: Simple key-value pair
- **WHEN** input is `key: "value"`
- **THEN** lexer produces tokens: identifier("key"), colon, string("value")

#### Scenario: Nested block
- **WHEN** input is `block { inner: 1 }`
- **THEN** lexer produces tokens: identifier("block"), open_brace, identifier("inner"), colon, number(1), close_brace

### Requirement: Parsing into AST
The SKG parser SHALL parse token streams into an AST of nodes containing key-value pairs and nested blocks.

#### Scenario: Hierarchical config
- **WHEN** input contains nested blocks with key-value pairs
- **THEN** the AST reflects the block hierarchy with each node containing its children and properties

#### Scenario: Malformed input
- **WHEN** input has syntax errors (unclosed braces, missing colons)
- **THEN** the parser returns an error with location information

### Requirement: Config file merging
The SKG parser SHALL support merging multiple parsed config files, with later values overriding earlier ones.

#### Scenario: Override a value
- **WHEN** two configs define the same key with different values
- **THEN** the merged result contains the value from the later config

### Requirement: No external dependencies
The SKG parser SHALL depend only on Zig's standard library and its own internal modules. SKG is project-agnostic — no consuming application code may be imported.

#### Scenario: Clean import graph
- **WHEN** examining the import graph of `src/*.zig` (excluding tests)
- **THEN** no file imports from outside `src/` or `std`

### Requirement: Value types
The SKG parser SHALL support string, integer, float, and boolean value types.

#### Scenario: Boolean value
- **WHEN** input is `key: true`
- **THEN** the AST contains a boolean node with value true

#### Scenario: Quoted string with spaces
- **WHEN** input is `key: "hello world"`
- **THEN** the AST contains a string node with value "hello world"

#### Scenario: Numeric value
- **WHEN** input is `key: 1.5`
- **THEN** the AST contains a float node with value 1.5
