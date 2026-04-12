# SKG

**Static Key Graph** - a simple, hierarchical configuration language for Zig.

SKG is human-readable, unambiguous, and has one way to write each construct.
It is structured data - no variables, no templates, no expressions, no computation.
The consuming application defines and validates the schema.

Created for [dusk](https://github.com/fynxlabs/dusk) but designed as a
standalone library - nothing in the parser depends on dusk.

## Usage

```zig
const skg = @import("skg");

var result = try skg.parse(allocator, "/path/to/config.skg");
defer result.deinit();

const file = result.file;
// walk file.children...
```

## Build

Requires Zig 0.15+.

```sh
zig build       # build the module
zig build test  # run parser tests
```

## Language Reference

See [docs/spec.md](docs/spec.md) for the full SKG language specification.

## License

MIT
