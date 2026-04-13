## 1. Comment Token (Zig)

- [x] 1.1 Add `comment` tag to `zig/token.zig` Tag enum
- [x] 1.2 Modify `zig/lexer.zig` to emit comment tokens instead of skipping `#` lines
- [x] 1.3 Add lexer tests for comment token emission

## 2. AST Comment Trivia (Zig)

- [x] 2.1 Add `leading_comments: [][]const u8` to Field, Block, BlockArray in `zig/ast.zig`
- [x] 2.2 Add `trailing_comment: ?[]const u8` to Field
- [x] 2.3 Add `trailing_comments: [][]const u8` to Block and BlockArray
- [x] 2.4 Add `leading_comments` and `trailing_comments` to File

## 3. Parser Comment Attachment (Zig)

- [x] 3.1 Modify `zig/parser.zig` to buffer comment tokens instead of treating them as errors
- [x] 3.2 Attach buffered comments as `leading_comments` when the next non-comment node is parsed
- [x] 3.3 Handle inline trailing comments on fields (same-line `#` after value)
- [x] 3.4 Handle block trailing comments (comments before `}`)
- [x] 3.5 Handle file-level leading and trailing comments
- [x] 3.6 Add parser tests for comment attachment

## 4. Emitter Comment Support (Zig)

- [x] 4.1 Update `zig/emit.zig` to emit `leading_comments` before each node at correct indentation
- [x] 4.2 Emit `trailing_comment` on same line as field value
- [x] 4.3 Emit block/block-array `trailing_comments` before closing delimiter
- [x] 4.4 Emit file-level leading and trailing comments
- [x] 4.5 Add round-trip tests: parse files with comments, emit, verify output matches

## 5. Comment Token (Go)

- [ ] 5.1 Add `Comment` token type to `go/lexer.go`
- [ ] 5.2 Modify Go lexer to emit comment tokens

## 6. AST Comment Trivia (Go)

- [ ] 6.1 Add comment trivia fields to Go AST types in `go/ast.go`

## 7. Parser Comment Attachment (Go)

- [ ] 7.1 Modify `go/parser.go` to buffer and attach comments
- [ ] 7.2 Add Go parser tests for comment preservation

## 8. Emitter Comment Support (Go)

- [ ] 8.1 Update `go/emit.go` to replay comment trivia
- [ ] 8.2 Add Go round-trip tests

## 9. CLI

- [x] 9.1 Create `zig/main.zig` with arg parsing for `fmt` subcommand and `--check` flag
- [x] 9.2 Implement `fmt` mode: read file, parse, emit, write back
- [x] 9.3 Implement `--check` mode: compare canonical output to file content, print non-canonical filenames, exit 1
- [x] 9.4 Handle parse errors: print error with path/line/col, skip file, non-zero exit
- [x] 9.5 Add `exe` target to `build.zig` for the `skg` binary

## 10. Integration

- [x] 10.1 Add comment round-trip conformance test cases to `testdata/valid/`
- [x] 10.2 Run `zig build test` — all tests pass
- [ ] 10.3 Run `go test ./...` — all tests pass (blocked on Go implementation)
- [x] 10.4 Verify `skg fmt --check` works on test .skg files
