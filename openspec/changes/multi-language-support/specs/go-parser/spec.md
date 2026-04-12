## ADDED Requirements

### Requirement: Pure Go implementation
The Go SKG parser SHALL be a pure Go module with zero CGo dependencies. It SHALL support cross-compilation and `go get` without native toolchains.

#### Scenario: Cross-compilation
- **WHEN** building a Go program that imports the SKG module with `GOOS=linux GOARCH=arm64`
- **THEN** the build succeeds without requiring a C compiler

### Requirement: Idiomatic Go public interface
The Go module SHALL expose `Unmarshal`, `UnmarshalFile`, `Marshal`, `Parse`, and `ParseFile` functions following Go naming conventions and error handling patterns.

#### Scenario: Parse from string
- **WHEN** calling `skg.Parse([]byte("key: \"val\""))`
- **THEN** returns an `*skg.File` AST and nil error

#### Scenario: Unmarshal to struct
- **WHEN** calling `skg.Unmarshal([]byte(...), &cfg)` where `cfg` has `skg:"fieldname"` struct tags
- **THEN** fields are populated by matching tag names to SKG keys

#### Scenario: Marshal from struct
- **WHEN** calling `skg.Marshal(&cfg)` on a tagged struct
- **THEN** returns valid SKG text that round-trips through Parse

### Requirement: Struct tag schema
The Go module SHALL use struct field tags (`skg:"name"`) to define the mapping between SKG keys/blocks and Go struct fields. Untagged exported fields SHALL use the lowercased field name. Unexported fields SHALL be skipped.

#### Scenario: Tagged field mapping
- **WHEN** a struct has `Accent string \x60skg:"accent"\x60` and SKG contains `accent: "green"`
- **THEN** Unmarshal sets Accent to "green"

#### Scenario: Nested block mapping
- **WHEN** a struct has `Theme ThemeConfig \x60skg:"theme"\x60` and SKG contains `theme { accent: "green" }`
- **THEN** Unmarshal populates Theme.Accent

#### Scenario: Nullable fields
- **WHEN** a struct has `Name *string \x60skg:"name"\x60` and SKG contains `name: null`
- **THEN** Unmarshal sets Name to nil

### Requirement: Error reporting
The Go parser SHALL return structured errors containing file path, line number, column number, and a human-readable message for all parse failures.

#### Scenario: Parse error includes location
- **WHEN** parsing invalid SKG input
- **THEN** the returned error includes line and column of the failure

### Requirement: Value type support
The Go parser SHALL support all SKG value types: string, multiline string, integer, float, boolean, null, and arrays (including nested arrays).

#### Scenario: All types parse correctly
- **WHEN** parsing a file containing every value type
- **THEN** the AST contains correctly typed nodes for each value

### Requirement: Conformance
The Go parser SHALL pass all shared conformance fixtures in `testdata/`.

#### Scenario: Conformance test suite
- **WHEN** running `go test ./...` in the `go/` directory
- **THEN** all fixtures in `testdata/valid/` and `testdata/invalid/` produce expected results
