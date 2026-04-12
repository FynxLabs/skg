## MODIFIED Requirements

### Requirement: No external dependencies
Each language implementation SHALL depend only on its language's standard library and its own internal modules. The Zig parser depends only on `std`. The Go parser depends only on the Go standard library. SKG is project-agnostic — no consuming application code may be imported.

#### Scenario: Zig clean import graph
- **WHEN** examining the import graph of `zig/*.zig` (excluding tests)
- **THEN** no file imports from outside `zig/` or `std`

#### Scenario: Go clean import graph
- **WHEN** examining the import graph of `go/*.go` (excluding tests)
- **THEN** no imports from outside the Go standard library
