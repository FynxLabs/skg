## Context

SKG has a working parser and emitter, but comments are discarded at lex time. A formatter that drops comments is useless for real config files. The goal is comment-preserving `skg fmt` — same UX as `zig fmt` or `gofmt`.

## Goals / Non-Goals

**Goals:**

- Preserve all comments through parse→emit round-trips
- Canonical formatting: 2-space indent, consistent spacing, trailing newline
- Standalone CLI binary for `skg fmt` and `skg fmt --check`
- Both Zig and Go implementations get comment preservation

**Non-Goals:**

- No comment reformatting (comments are preserved verbatim, not reflowed)
- No config-aware validation (the formatter doesn't know what keys mean)
- No Go CLI (the binary is Zig-only; Go gets the library changes for consumers like dusk's config writer)

## Decisions

### Comment token

Add a `comment` tag to `token.zig`/`Tag`. The lexer emits comment tokens instead of skipping `#` lines. The token text includes the `#` prefix and everything up to (not including) the newline.

**Rationale:** Comments must survive lexing to be available for the parser. The simplest approach is making them first-class tokens.

### Comment attachment model

Comments attach to AST nodes as trivia slices. Each node type (Field, Block, BlockArray) gains a `leading_comments: [][]const u8` field — an array of comment text lines that appeared immediately before the node (no blank line separating them from the node).

File-level gets `leading_comments` (comments before the first node) and `trailing_comments` (comments after the last node).

Inline trailing comments (e.g., `key: "value" # explanation`) attach as `trailing_comment: ?[]const u8` on Field.

**Rationale:** This is the simplest model that handles real-world SKG files. The theme files in design-guidelines use comments as section headers (leading) and field explanations (trailing inline). Block-level trailing comments (comments at the end of a block before `}`) attach as leading comments on the closing brace — handled by adding `trailing_comments: [][]const u8` to Block and BlockArray.

**Alternative considered:** Storing comments as standalone AST nodes interleaved with content nodes. Rejected — makes the emitter more complex and every AST consumer has to handle comment nodes. Trivia attachment keeps comments out of the way for consumers that don't care.

### Parser changes

The parser collects comment tokens into a temporary buffer. When it encounters a non-comment token, it attaches the buffered comments as `leading_comments` on the next node. For inline trailing comments, after parsing a field value the parser checks if the next token on the same line is a comment.

Blank lines between comment groups start a new group — a blank line followed by comments attaches to the next node, not the previous one.

### Emitter changes

Before emitting each node, emit its `leading_comments` (each on its own line, indented to the current depth). After emitting a Field, if it has a `trailing_comment`, emit ` # text` on the same line before the newline. Before closing braces, emit `trailing_comments` for the block.

### CLI design

Single binary: `skg fmt <files...>` reformats in-place. `skg fmt --check <files...>` exits 0 if already canonical, exits 1 and prints filenames if not (same behavior as `zig fmt --check`).

The CLI reads each file, parses it, emits canonical output, and either writes it back or compares. No stdin/stdout mode needed initially.

Build target: `build.zig` adds an `exe` step for `skg` that builds `zig/main.zig`.

### Go implementation scope

Go gets the same comment preservation changes (lexer, AST, parser, emitter) but no CLI binary. Go consumers (like dusk's config writer) benefit from comment-preserving emit.

## Risks / Trade-offs

- **[Low] Comment attachment ambiguity** — When a blank line separates two comment blocks, the split point determines which node owns which comments. The rule (comments attach to the next node) matches the convention in Go, Rust, and most languages. Edge case: a comment at the very end of a file with no following node goes to `File.trailing_comments`.
- **[Low] Performance** — Comment tokens add to the token stream size. For SKG files (typically under 200 lines), this is negligible.
- **[None] Backward compatibility** — Existing AST consumers see zero-length trivia slices by default. No breaking changes to the parse or emit public interface signatures.
