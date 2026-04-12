## ADDED Requirements

### Requirement: Shared test fixtures
The SKG project SHALL maintain a `testdata/` directory containing `.skg` input files paired with `.expected.json` files that describe the expected parse result in a language-neutral JSON format.

#### Scenario: Valid fixture round-trip
- **WHEN** a `.skg` file in `testdata/valid/` is parsed by any conforming implementation
- **THEN** the resulting AST matches the structure in the paired `.expected.json`

#### Scenario: Invalid fixture rejection
- **WHEN** a `.skg` file in `testdata/invalid/` is parsed by any conforming implementation
- **THEN** parsing fails, and the error message contains the substring specified in `.expected.json`

### Requirement: All implementations pass conformance
Every parser implementation in the SKG repository SHALL include a test that runs all shared fixtures from `testdata/` and asserts correct output.

#### Scenario: Zig conformance
- **WHEN** `zig build test` is run
- **THEN** all fixtures in `testdata/valid/` and `testdata/invalid/` pass

#### Scenario: Go conformance
- **WHEN** `go test` is run in the `go/` directory
- **THEN** all fixtures in `testdata/valid/` and `testdata/invalid/` pass

### Requirement: Fixture coverage
The conformance fixtures SHALL cover all value types (string, int, float, bool, null, array, nested array, multiline string), blocks, imports, skg_version, schema_version, comments, and all error conditions documented in the spec.

#### Scenario: Complete type coverage
- **WHEN** examining the set of valid fixtures
- **THEN** every SKG value type and structural element has at least one fixture
