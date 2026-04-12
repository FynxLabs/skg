## 1. Error Reporting

- [ ] 1.1 Add `ParseDiagnostic` struct (path, line, col, message) and expose it on `ParseResult`
- [ ] 1.2 Capture token position context on every parser error path (UnexpectedToken, ExpectedRbrace, ExpectedRbracket, ExpectedValue, etc.)
- [ ] 1.3 Format circular import errors with the full import chain in the message
- [ ] 1.4 Add tests: verify each error type produces correct file/line/col/message

## 2. Language Additions

- [ ] 2.1 Add `null` keyword to lexer (new `Tag.null` variant)
- [ ] 2.2 Add `Value.null` variant (void payload) to AST union
- [ ] 2.3 Parse `null` as a value in fields and arrays
- [ ] 2.4 Add multiline string lexer support (`"""..."""` — raw content between delimiters, opening `"""` must be followed by newline)
- [ ] 2.5 Add `Tag.multiline_string` token type and wire through parser to produce a `Value.string`
- [ ] 2.6 Add nested array support — `parseArray` calls itself recursively when it encounters `[`
- [ ] 2.7 Change `skg_version` from float to string — parser expects a quoted string, AST field type changes to `?[]const u8`
- [ ] 2.8 Add tests: null in field, null in array, multiline string, nested arrays, string skg_version, float skg_version rejected

## 3. Bug Fixes

- [ ] 3.1 Enforce last-wins for duplicate fields within a single file — parser checks existing children before appending
- [ ] 3.2 Cap `readToEndAlloc` at 10MB in `root.zig`
- [ ] 3.3 Add tests: duplicate field last-wins, oversized file rejected

## 4. Performance

- [ ] 4.1 Zero-copy string fast path in `unescapeString` — check for `\\` before allocating
- [ ] 4.2 Replace linear scan in `mergeNodes` with `StringHashMap` name→index lookup
- [ ] 4.3 Add benchmark test or note confirming merge behavior with large node counts

## 5. Emit API

- [ ] 5.1 Create `src/emit.zig` — `pub fn emit(allocator, file) -> []const u8`
- [ ] 5.2 Emit all value types: int, float, bool, string, null, array (including nested)
- [ ] 5.3 Emit multiline strings using `"""` when content contains newlines
- [ ] 5.4 Emit canonical formatting: 2-space indent, blank line between top-level blocks, trailing newline
- [ ] 5.5 Emit `skg_version`, `schema_version`, and `import` declarations in correct order
- [ ] 5.6 Export `emit` from `root.zig` public API
- [ ] 5.7 Add round-trip tests: parse fixture → emit → parse again → assert AST equivalence

## 6. Import Resolver

- [ ] 6.1 Define `ImportResolver` function type and `ParseOptions` struct in `root.zig`
- [ ] 6.2 Thread `ParseOptions` through `parse()` and `parseSource()` — default filesystem behavior when resolver is null
- [ ] 6.3 Add test: custom resolver that returns source from a `StringHashMap` instead of disk

## 7. Spec Integrity

- [ ] 7.1 Change spec code blocks from ` ```go ` to ` ```skg ` for proper tagging
- [ ] 7.2 Update spec to document: null type, multiline strings, nested arrays, skg_version as string
- [ ] 7.3 Create `src/spec_test.zig` — extract fenced `skg` blocks from `docs/spec.md` via `@embedFile` and parse each one
- [ ] 7.4 Wire `spec_test.zig` into `build.zig` test step

## 8. Consumer Updates (dusk)

- [ ] 8.1 Update dusk's walker to handle `Value.null` (map to optional field defaults)
- [ ] 8.2 Update dusk's `skg_version` handling from float to string
- [ ] 8.3 Update dusk's `config/generate.zig` to emit `skg_version: "1.0"` instead of `skg_version: 1.0`
- [ ] 8.4 Update `tests/render/fixture.skg` and any other `.skg` fixtures to use string `skg_version`
- [ ] 8.5 Verify dusk `zig build test` passes after all changes
