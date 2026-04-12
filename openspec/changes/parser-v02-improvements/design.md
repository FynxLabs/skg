## Context

SKG is a standalone Zig library consumed via `@import("skg")`. Two projects depend on it today (dusk via local path, ember planned). The parser is ~600 lines across 6 files. All memory goes through a caller-provided arena. The current public API is two functions: `parse(allocator, path)` and `parseSource(allocator, source, path)`.

## Goals / Non-Goals

**Goals:**

- Every parse error produces file path, line, column, and a clear human-readable message.
- The AST always represents last-wins semantics — no duplicate fields survive parsing.
- The library supports round-tripping: parse → modify AST → emit → get valid SKG.
- Consumers can resolve imports without touching the filesystem.
- Spec examples are enforced by the test suite.
- Performance is good by default — zero-copy strings, O(n+m) merge, bounded file reads.

**Non-Goals:**

- Backward compatibility with v0.1 AST shapes. This is pre-alpha; consumers update in lockstep.
- Conditional imports, expressions, variables, or any computational features. SKG is structured data, not a language.
- Indentation-aware multiline strings (dedent, strip-margin). Triple-quote is raw content only.
- Schema validation in the parser. That stays in the consumer.

## Decisions

**Error reporting: return a result struct with optional error detail, not just a Zig error code.**
The `ParseResult` gains an `errors: []ParseDiagnostic` field where each diagnostic has `path`, `line`, `col`, `message`. On success, `errors` is empty. On failure, the Zig error is still returned for control flow, but `ParseResult` (accessed via `errdefer`) is populated with context. Alternative considered: a separate `getLastError()` accessor — rejected because it requires the parser to be stateful between calls.

**Null: a `null` keyword that produces `Value{ .null = {} }`.**
The `Value` tagged union gains a `.null` variant with `void` payload. This is the standard Zig pattern for "intentionally nothing." In config, `field: null` means "I acknowledge this field exists and I want the default / absent behavior." Alternative considered: omitting the field entirely — rejected because the consumer can't distinguish "user removed this" from "user never set this."

**Multiline strings: `""" ... """` with raw content, no interpolation, no dedent.**
Content between the opening `"""` (followed by a newline) and the closing `"""` (on its own line) is taken literally. No indentation stripping — what you write is what you get. This avoids the complexity traps of Python/Swift/Kotlin multiline strings. If someone wants indentation stripping, they do it in their consumer. Alternative considered: backtick-delimited strings — rejected because backticks have meaning in shells and terminals, confusing in a config file.

**`skg_version` as string: parsed exactly like `schema_version`.**
Just a string field: `skg_version: "1.0"`. The parser records it verbatim. Version comparison logic (if ever needed) belongs in the consumer. This eliminates the float precision trap.

**Import resolver: an optional callback on a new `ParseOptions` struct.**
```zig
pub const ImportResolver = *const fn (allocator: Allocator, path: []const u8) anyerror![]const u8;
pub const ParseOptions = struct {
    import_resolver: ?ImportResolver = null, // null = use default filesystem resolver
};
```
`parse()` and `parseSource()` gain an optional `ParseOptions` parameter. When `import_resolver` is set, the parser calls it instead of `std.fs.cwd().openFile()`. This lets consumers resolve imports from memory, embedded resources, or virtual filesystems.

**Emit API: `skg.emit(allocator, file) -> []const u8`.**
Walks the AST and produces canonical SKG text. Canonical means: consistent indentation (2 spaces), one blank line between top-level blocks, no comments (comments are not in the AST), trailing newline. This is the single canonical form described in the spec. The formatter is just `parse → emit`.

**Zero-copy string fast path: check for backslash before allocating.**
`unescapeString` checks `std.mem.indexOfScalar(u8, inner, '\\')`. If null, return the inner slice directly — no allocation. Otherwise, fall through to the existing byte-by-byte escape loop. One branch for a massive reduction in allocations.

**Hash-map merge: replace linear scan with `StringHashMap`.**
`mergeNodes` builds a name→index map of the base nodes, then looks up each overlay node in O(1). Total cost: O(n+m) instead of O(n*m). The map is allocated from the arena so there's no cleanup.

**File size cap: 10MB.**
`readToEndAlloc` limit changes from `maxInt(usize)` to `10 * 1024 * 1024`. Config files above 10MB are a bug, not a feature.

**Spec-as-tests: embed spec examples and parse them.**
Each fenced code block in `docs/spec.md` that's tagged as `skg` (not `go` — that should change too) gets extracted and fed to `parseSource` in a test. If the spec says it's valid, the parser must accept it. If the spec says it's invalid, the parser must reject it.

## Risks / Trade-offs

- **[Risk] `skg_version` change breaks all existing `.skg` files** → Accepted. Pre-alpha, two consumers, both update in lockstep. The migration is a one-line sed.
- **[Risk] Null in the AST forces every consumer to handle a new variant** → Accepted. Exhaustive switch in Zig makes this a compile error, not a runtime surprise.
- **[Risk] Multiline strings complicate the lexer** → Mitigated by keeping the feature minimal (no dedent, no interpolation). The lexer just looks for `"""`, consumes until the next `"""`, done.
- **[Trade-off] Import resolver callback adds API surface** → Worth it for embeddability. The default (null = filesystem) means existing callers don't change.
