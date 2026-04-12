## Why

SKG v0.1 parses and merges correctly but has gaps that block real-world reuse: error messages lose location context, duplicate fields are silently preserved (spec says last-wins), there's no way to emit/write SKG back from an AST, and several spec-level omissions (no null, no nested arrays, no multiline strings, `skg_version` as float). These need to be fixed before dusk and ember both depend on it, because changing AST shapes and public API after two consumers are wired up is painful.

## What Changes

- **Error reporting**: Parse errors include file path, line, column, and a human-readable message. Callers get structured error context, not just a Zig error code.
- **Duplicate field enforcement**: Within a single file, the parser enforces last-wins semantics — the second occurrence of a key replaces the first in the AST. Matches existing spec language.
- **Nested arrays**: Arrays may contain arrays. `[[1, 2], [3, 4]]` is valid. Inner arrays follow the same uniform-type rule.
- **`skg_version` as string**: Changes from float to quoted string (`skg_version: "1.0"`) to avoid `1.1 == 1.10` ambiguity. **BREAKING** for existing `.skg` files.
- **Null value type**: A new `null` keyword. Zig-idiomatic: `Value` union gains a `.null` variant. Lets consumers distinguish "field explicitly unset" from "field absent."
- **Multiline strings**: Triple-quoted strings (`"""..."""`) for clean multi-line content without `\n` chains. No interpolation, no indentation stripping — just raw content between the delimiters.
- **Write/emit API**: `skg.emit(allocator, file) -> []const u8` — serialize an AST back to canonical SKG text. Enables round-tripping, formatters, migration scripts, and editor tooling.
- **Import resolver abstraction**: `parseSource` gains an optional import resolver callback so consumers can resolve imports from memory, embedded resources, or custom paths — not just `std.fs`.
- **Performance**: Zero-copy string fast path (skip allocation when no escapes), hash-map merge for O(n+m) instead of O(n*m), file size cap on `readToEndAlloc`.
- **Spec-as-tests**: All spec doc examples are `@embedFile`'d and parsed in the test suite, so spec drift is a test failure.

## Capabilities

### New Capabilities

- `emit`: AST-to-text serialization for round-tripping and canonical formatting
- `error-reporting`: Structured parse error context with file, line, column, message

### Modified Capabilities

- `parser`: Duplicate enforcement, nested arrays, null type, multiline strings, skg_version as string, import resolver abstraction, performance improvements, spec-as-tests

## Impact

- **AST**: `Value` union gains `.null` variant, `Array` may contain nested arrays — all consumers must handle these.
- **Public API**: `parse()` return type changes to include structured error info. `parseSource()` gains optional resolver param. New `emit()` function.
- **Spec**: `skg_version` changes from float to string. New `null` keyword. New `"""` multiline syntax. Nested array support. All are language-level changes.
- **Consumers (dusk, ember)**: Must update walkers to handle null values and nested arrays. `skg_version` parsing changes from float to string. Import: dusk's `core/config/skg.zig` and ember's equivalent need to adapt to the new API.
- **Existing `.skg` files**: `skg_version: 1.0` must become `skg_version: "1.0"`. This is the only breaking syntax change.
