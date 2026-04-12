## Context

SKG has a Zig parser (~600 lines) covering lexer, parser, merge, emit, and error reporting. The format is language-agnostic but only has one implementation. To use SKG from Go projects (like ember), a native Go parser is needed. A shared conformance test suite ensures both implementations stay in sync as the language evolves.

## Goals / Non-Goals

**Goals:**
- Native Go parser that passes the same conformance tests as the Zig parser
- Idiomatic Go interface: struct tags for schema, `Unmarshal`/`Marshal` like `encoding/json`
- Shared test fixtures that any future language implementation must also pass
- Zero CGo — pure Go, supports cross-compilation and `go get`

**Non-Goals:**
- Runtime schema validation from a schema definition file (struct tags are the schema)
- C ABI bindings from the Zig parser
- Any language beyond Go and Zig for now
- Streaming/incremental parsing
- Go import resolution (Go consumers parse single files or strings; import merging is app-level)

## Decisions

### Go module location: `go/` subdirectory in skg repo
Single repo keeps conformance fixtures, spec, and all implementations together. The Go module path is `github.com/fynxlabs/skg/go` with a `go.mod` at `go/go.mod`. Consumers: `go get github.com/fynxlabs/skg/go`.

Alternative: separate `skg-go` repo. Rejected — splits the conformance fixtures and makes spec updates require cross-repo coordination.

### Struct tags as schema (`skg:"name"`)
Go struct fields with `skg:"fieldname"` tags define what blocks and fields are valid. Unmarshal maps AST nodes to struct fields by tag name. Untagged exported fields use lowercased field name. Unexported fields are skipped.

Supported field types: `string`, `int64`, `float64`, `bool`, pointer-to-any (nullable), `[]T` (arrays), nested structs (blocks). A `*string` field accepts both string values and null.

This is the same pattern as `encoding/json` — no learning curve for Go devs.

### Conformance fixture format
Each fixture is a `.skg` file paired with a `.expected.json` file. The JSON describes the expected AST in a language-neutral format:

```json
{
  "skg_version": "1.0",
  "schema_version": null,
  "imports": [],
  "children": [
    {"type": "field", "key": "name", "value": {"type": "string", "data": "hello"}},
    {"type": "block", "name": "theme", "children": [...]}
  ]
}
```

Invalid fixtures have a `.expected.json` with:
```json
{"error": true, "message_contains": "unterminated string"}
```

### Go package structure
```
go/
  go.mod
  go.sum
  skg.go          # Public API: Unmarshal, UnmarshalFile, Marshal, Parse, ParseFile
  ast.go          # AST types: File, Node, Field, Block, Value
  lexer.go        # Tokenizer
  parser.go       # Token stream → AST
  merge.go        # Node list overlay merge
  emit.go         # AST → SKG text
  unmarshal.go    # AST → Go structs via reflection
  marshal.go      # Go structs → AST → SKG text
  conformance_test.go  # Runs shared testdata/ fixtures
  skg_test.go     # Go-specific unit tests
```

### No Go import resolution
The Go parser parses single files/strings. Import resolution (`import "other.skg"`) is recorded in the AST but not resolved — the consuming application handles file loading and merge order. This keeps the parser simple and avoids filesystem assumptions.

## Risks / Trade-offs

- **Drift between implementations** → Mitigated by shared conformance fixtures. Any new SKG feature requires adding fixtures before the feature is considered done.
- **Reflection overhead in Go unmarshal** → Acceptable for config parsing (runs once at startup, not in hot paths). Same trade-off `encoding/json` makes.
- **Go module in subdirectory** → Slightly unusual `go get` path. But well-supported by Go toolchain and keeps everything in one repo.
