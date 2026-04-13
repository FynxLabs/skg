## Why

SKG files have no canonical formatting tool. Comments are discarded at lex time, so parse→emit round-trips destroy them. Without a formatter, there's no way to enforce consistent style in CI (like `zig fmt --check`) or auto-format on save in editors.

## What Changes

- Add a `comment` token to the lexer so `#` lines are preserved through the pipeline
- Attach comment trivia to AST nodes (leading comments before a node, trailing inline comments)
- Update the emitter to replay comments at the correct positions
- Add a standalone `skg` CLI binary with `fmt` and `fmt --check` subcommands
- Both Zig and Go implementations get comment preservation; CLI is Zig-only

## Capabilities

### New Capabilities

- `comment-preservation`: Lexer emits comment tokens, AST carries comment trivia on nodes, emitter replays them
- `skg-cli`: Standalone CLI binary (`skg fmt <files>`, `skg fmt --check <files>`) for formatting SKG files

### Modified Capabilities

- `parser`: Lexer gains a `comment` token tag; parser attaches comments to adjacent AST nodes as trivia
- `emit`: Emitter serializes attached comment trivia alongside nodes

## Impact

- `zig/token.zig` - new `comment` tag
- `zig/lexer.zig` - emit comment tokens instead of discarding them
- `zig/ast.zig` - comment trivia fields on Field, Block, BlockArray, File
- `zig/parser.zig` - collect and attach comments to nodes
- `zig/emit.zig` - replay comment trivia during serialization
- `zig/main.zig` - new file, CLI entry point
- `go/lexer.go` - same comment token changes
- `go/ast.go` - same trivia fields
- `go/parser.go` - same attachment logic
- `go/emit.go` - same replay logic
- `build.zig` - add CLI executable target
- Existing tests - update to account for comment round-tripping
