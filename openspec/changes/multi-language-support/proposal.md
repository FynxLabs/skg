## Why

SKG fills a gap between CUE (bloated), JSON (no comments, unreadable), YAML (whitespace-sensitive), and TOML (flat). To make it a real option for projects that span multiple languages — specifically Go and Zig today — it needs native parsers in each language and a shared conformance test suite so they don't drift.

## What Changes

- Add shared conformance test fixtures (`testdata/valid/`, `testdata/invalid/`) — `.skg` input files paired with `.expected.json` AST output. Every parser implementation must pass these.
- Add native Go parser module (`go/`) with: lexer, parser, AST, struct-tag-based unmarshaling (`skg.Unmarshal`), and marshal/emit back to SKG text.
- Go unmarshal uses struct tags (`skg:"fieldname"`) as the schema — the Go struct IS the schema, same pattern as `encoding/json`.
- Wire Zig parser to also run the shared conformance fixtures.
- Update `docs/spec.md` to document all current language features (null, multiline strings, nested arrays, string skg_version).

## Capabilities

### New Capabilities
- `conformance`: Shared cross-language test fixtures and conformance contract. Every parser implementation must produce identical AST output for the same input.
- `go-parser`: Native Go implementation of the SKG parser — lexer, parser, AST, merge, emit, and struct-tag-based unmarshaling.

### Modified Capabilities
- `parser`: Modify "No external dependencies" requirement to be Zig-specific (the Go parser has its own dependency constraint). Add language-agnostic AST contract.

## Impact

- New `testdata/` directory at repo root with shared fixtures
- New `go/` directory with Go module (`github.com/fynxlabs/skg`)
- Existing Zig tests gain conformance fixture runner
- `docs/spec.md` updated to current language state
- No breaking changes to Zig parser or its public interface
