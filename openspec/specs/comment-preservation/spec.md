# comment-preservation Specification

## Purpose
Ensure comments in `.skg` files are preserved through parse-emit round-trips, stored as trivia on AST nodes.
## Requirements
### Requirement: Comments survive parse-emit round-trips
The SKG pipeline SHALL preserve all comments through a parse→emit cycle. No comment text SHALL be lost or reordered.

#### Scenario: Leading comments preserved
- **WHEN** input contains `# header comment` followed by `block { }`
- **THEN** after parse→emit, the output contains `# header comment` immediately before `block {`

#### Scenario: Inline trailing comments preserved
- **WHEN** input contains `key: "value" # explanation`
- **THEN** after parse→emit, the output contains the field followed by `# explanation` on the same line

#### Scenario: File-level trailing comments preserved
- **WHEN** input ends with `# footer comment` after all nodes
- **THEN** after parse→emit, the output ends with `# footer comment`

#### Scenario: Block-internal trailing comments preserved
- **WHEN** a block contains `# last comment` before its closing `}`
- **THEN** after parse→emit, the comment appears before `}` at the correct indentation

### Requirement: Comments attach to adjacent nodes as trivia
Comments SHALL be stored as trivia on AST nodes, not as standalone AST nodes. Each Field, Block, and BlockArray node SHALL carry `leading_comments` (comments immediately preceding the node) and Fields SHALL carry an optional `trailing_comment` (inline comment on the same line). Blocks and BlockArrays SHALL carry `trailing_comments` (comments before the closing delimiter).

#### Scenario: Leading comments attach to next node
- **WHEN** two comment lines appear immediately before a field
- **THEN** both comments are in the field's `leading_comments` slice

#### Scenario: Blank line splits comment groups
- **WHEN** a comment block is separated from the next node by a blank line followed by another comment block
- **THEN** the second comment block attaches to the next node, not the previous one

#### Scenario: Consumers without comment interest see empty trivia
- **WHEN** existing code accesses AST nodes without reading trivia fields
- **THEN** the trivia slices default to empty and cause no breakage

