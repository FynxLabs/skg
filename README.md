# SKG

**Static Key Graph** - a simple, hierarchical configuration language with native parsers in Zig and Go.

SKG is human-readable, unambiguous, and has one way to write each construct.
It is structured data - no variables, no templates, no expressions, no computation.
The consuming application defines and validates the schema.

Created for [dusk](https://github.com/fynxlabs/dusk) but designed as a
standalone library - nothing in the parser depends on dusk.

## Zig Usage

```zig
const skg = @import("skg");

var result = skg.parseSource(allocator, source, "config.skg");
defer result.deinit();

if (result.file) |file| {
    // walk file.children...
} else if (result.diagnostic) |diag| {
    // diag.path, diag.line, diag.col, diag.message
}
```

## Go Usage

### Parse and walk the AST

```go
import "github.com/fynxlabs/skg/go"

file, err := skg.Parse(data)
// or from disk:
file, err := skg.ParseFile("/path/to/config.skg")
```

### Unmarshal into structs

```go
type Theme struct {
    Accent string  `skg:"accent"`
    Size   float64 `skg:"size"`
}

type Config struct {
    Name  string   `skg:"name"`
    Theme Theme    `skg:"theme"`
    Tags  []string `skg:"tags"`
}

var cfg Config
err := skg.Unmarshal(data, &cfg)
```

### Marshal from structs

```go
data, err := skg.Marshal(cfg)
```

### Emit AST back to SKG text

```go
output := skg.Emit(file)
```

## Build

### Zig

Requires Zig 0.15+.

```sh
zig build       # build the module
zig build test  # run parser tests
```

### Go

Requires Go 1.23+.

```sh
cd go
go build ./...
go test ./...
```

## Language Reference

See [docs/spec.md](docs/spec.md) for the full SKG language specification.

## License

MIT
