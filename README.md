# SKG

**Static Key Group** - a simple, hierarchical configuration language with native parsers in Zig and Go.

SKG is human-readable, unambiguous, and has one way to write each construct.
It is structured data - no variables, no templates, no expressions, no computation.
The consuming application defines and validates the schema.

Created for [dusk](https://github.com/fynxlabs/dusk) but designed as a
standalone library - nothing in the parser depends on dusk.

## Your struct IS the schema

SKG has no separate schema language. Your application's structs define what fields
and blocks are valid. The parser gives you an AST; you map it onto your types
however your language does that.

- **Go**: `skg:"name"` struct tags, just like `json:"name"`. Unmarshal parses and
  populates in one call. Extra config keys are ignored. Missing keys keep zero values.
- **Zig**: Walk the AST and pattern-match on field keys and block names. Explicit,
  zero-allocation (on an arena), full control over defaults and validation.

Both approaches mean: add a field to your struct, it picks up from the config.
Remove it, the config key is silently ignored. No schema file to keep in sync.

## Examples

Full working examples that parse the same config file and populate the same
logical struct in each language:

- **[examples/go/](examples/go/)** - Go struct tags, unmarshal, marshal round-trip
- **[examples/zig/](examples/zig/)** - AST walker, struct defaults, explicit mapping

Run them:

```sh
cd examples/go  && go run main.go
cd examples/zig && zig build run
```

## Quick start

### Go

```go
import skg "github.com/fynxlabs/skg/go"

type Config struct {
    Name  string   `skg:"name"`
    Port  int64    `skg:"port"`
    Debug bool     `skg:"debug"`
    Tags  []string `skg:"tags"`
    DB    Database `skg:"database"` // nested struct = block
}

var cfg Config
err := skg.UnmarshalFile("config.skg", &cfg)
```

### Zig

```zig
const skg = @import("skg");

var result = skg.parseSource(allocator, source, "config.skg");
defer result.deinit();

if (result.file) |file| {
    // walk file.children, match on field keys and block names
} else if (result.diagnostic) |diag| {
    // diag.path, diag.line, diag.col, diag.message
}
```

## Build

### Zig

Requires Zig 0.15+.

```sh
zig build       # build the module
zig build test  # run parser tests
```

### Go

Requires Go 1.26+.

```sh
cd go
go build ./...
go test ./...
```

## Repo structure

```
skg/
  zig/        # Zig implementation (lexer, parser, ast, merge, emit)
  go/         # Go implementation (lexer, parser, ast, merge, emit, unmarshal, marshal)
  testdata/   # Shared conformance fixtures — the contract between implementations
  examples/   # Working examples for each language
  docs/       # Language spec
```

Each language directory is a self-contained implementation with its own build
tooling. Both are validated against the same `testdata/` fixtures.

## Language reference

See [docs/spec.md](docs/spec.md) for the full SKG language specification.

## License

MIT
