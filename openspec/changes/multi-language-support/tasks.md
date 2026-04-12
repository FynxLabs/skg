## 1. Conformance Test Fixtures

- [x] 1.1 Create `testdata/valid/` and `testdata/invalid/` directories
- [x] 1.2 Add valid fixtures: simple fields (string, int, float, bool), null, arrays, nested arrays, multiline strings, blocks, nested blocks, imports, skg_version, schema_version, comments
- [x] 1.3 Add invalid fixtures: unterminated string, bad escape, missing colon, unclosed block, mixed array types, duplicate skg_version, duplicate schema_version, unterminated array, bad import syntax
- [x] 1.4 Define `.expected.json` format and document it in `testdata/README.md`

## 2. Go Module Setup

- [x] 2.1 Create `go/go.mod` with module path `github.com/fynxlabs/skg/go`
- [x] 2.2 Create package structure: `skg.go`, `ast.go`, `lexer.go`, `parser.go`, `merge.go`, `emit.go`, `unmarshal.go`, `marshal.go`
- [x] 2.3 Define Go AST types: File, Node, Field, Block, Value (with typed variants)

## 3. Go Lexer

- [x] 3.1 Implement tokenizer: identifiers, strings, multiline strings, numbers (int/float), bools, null, punctuation, comments
- [x] 3.2 Implement error reporting with line/col tracking
- [x] 3.3 Add lexer unit tests

## 4. Go Parser

- [x] 4.1 Implement parser: file-level (skg_version, schema_version, imports, nodes), blocks, fields, values, arrays
- [x] 4.2 Implement duplicate field last-wins dedup
- [x] 4.3 Implement structured parse errors with file/line/col/message
- [x] 4.4 Add parser unit tests

## 5. Go Merge

- [x] 5.1 Implement node merge with hash-map lookup (field last-wins, block recursive merge)
- [x] 5.2 Add merge unit tests

## 6. Go Emit

- [x] 6.1 Implement AST-to-SKG-text serializer (all value types, indentation, multiline strings)
- [x] 6.2 Add round-trip tests (parse → emit → compare)

## 7. Go Unmarshal

- [x] 7.1 Implement struct-tag-based unmarshaling: string, int64, float64, bool, pointer (nullable), slices (arrays), nested structs (blocks)
- [x] 7.2 Implement `Unmarshal(data []byte, v interface{}) error`
- [x] 7.3 Implement `UnmarshalFile(path string, v interface{}) error`
- [x] 7.4 Add unmarshal unit tests (all types, nested, nullable, missing fields, extra fields ignored)

## 8. Go Marshal

- [x] 8.1 Implement struct-to-SKG-text marshaling via reflection → AST → emit
- [x] 8.2 Implement `Marshal(v interface{}) ([]byte, error)`
- [x] 8.3 Add marshal round-trip tests (marshal → unmarshal → compare)

## 9. Conformance Wiring

- [x] 9.1 Create `go/conformance_test.go` — reads all `testdata/` fixtures and asserts Go parser matches expected output
- [x] 9.2 Create Zig conformance test — reads all `testdata/` fixtures via `@embedFile` or filesystem and asserts Zig parser matches expected output
- [x] 9.3 Verify both `go test` and `zig build test` pass all fixtures

## 10. Spec and Docs

- [x] 10.1 Update `docs/spec.md` to document: null type, multiline strings, nested arrays, string skg_version
- [x] 10.2 Add Go usage examples to `README.md`
