// Example: loading an SKG config in Zig.
//
// In Zig, your struct IS still the schema - you define what your app
// cares about, then walk the parsed AST to populate it. There's no
// runtime reflection or struct tags, so you write a small walker that
// maps keys to fields. This is explicit, zero-allocation (on an arena),
// and gives you full control over validation and defaults.
//
// Build and run:
//   cd examples/zig && zig build run
//
const std = @import("std");
const skg = @import("skg");

// ── The struct IS the schema ───────────────────────────────────────────────
//
// Define what your app cares about. Defaults are set right here.
// The walker below maps config keys → struct fields.
// Extra keys in the config are silently skipped.

const Streams = struct {
    stdout: bool = false,
    file: bool = false,
    syslog: bool = false,
};

const Logging = struct {
    level: []const u8 = "info",
    max_size_mb: i64 = 5,
    keep_rotations: i64 = 3,
    streams: Streams = .{},
};

const Database = struct {
    host: []const u8 = "localhost",
    port: i64 = 5432,
    name: []const u8 = "",
    max_connections: i64 = 10,
    ssl: bool = false,
};

const Config = struct {
    name: []const u8 = "",
    port: i64 = 0,
    debug: bool = false,
    motd: []const u8 = "",
    database: Database = .{},
    logging: Logging = .{},
};

// ── Walker: maps AST nodes → struct fields ─────────────────────────────────
//
// This is the Zig equivalent of Go's `skg:"name"` struct tags.
// You pattern-match on field keys and block names. It's more code than
// tags, but it's explicit - you see exactly what gets populated and can
// add validation inline.

fn walkConfig(nodes: []const skg.ast.Node) Config {
    var cfg = Config{};
    for (nodes) |node| {
        switch (node) {
            .field => |f| {
                if (std.mem.eql(u8, f.key, "name")) {
                    cfg.name = f.value.string;
                } else if (std.mem.eql(u8, f.key, "port")) {
                    cfg.port = f.value.int;
                } else if (std.mem.eql(u8, f.key, "debug")) {
                    cfg.debug = f.value.bool;
                } else if (std.mem.eql(u8, f.key, "motd")) {
                    cfg.motd = f.value.string;
                }
                // extra keys silently ignored - struct defines the schema
            },
            .block => |b| {
                if (std.mem.eql(u8, b.name, "database")) {
                    cfg.database = walkDatabase(b.children);
                } else if (std.mem.eql(u8, b.name, "logging")) {
                    cfg.logging = walkLogging(b.children);
                }
            },
        }
    }
    return cfg;
}

fn walkDatabase(nodes: []const skg.ast.Node) Database {
    var db = Database{};
    for (nodes) |node| {
        switch (node) {
            .field => |f| {
                if (std.mem.eql(u8, f.key, "host")) {
                    db.host = f.value.string;
                } else if (std.mem.eql(u8, f.key, "port")) {
                    db.port = f.value.int;
                } else if (std.mem.eql(u8, f.key, "name")) {
                    db.name = f.value.string;
                } else if (std.mem.eql(u8, f.key, "max_connections")) {
                    db.max_connections = f.value.int;
                } else if (std.mem.eql(u8, f.key, "ssl")) {
                    db.ssl = f.value.bool;
                }
            },
            .block => {},
        }
    }
    return db;
}

fn walkLogging(nodes: []const skg.ast.Node) Logging {
    var log = Logging{};
    for (nodes) |node| {
        switch (node) {
            .field => |f| {
                if (std.mem.eql(u8, f.key, "level")) {
                    log.level = f.value.string;
                } else if (std.mem.eql(u8, f.key, "max_size_mb")) {
                    log.max_size_mb = f.value.int;
                } else if (std.mem.eql(u8, f.key, "keep_rotations")) {
                    log.keep_rotations = f.value.int;
                }
            },
            .block => |b| {
                if (std.mem.eql(u8, b.name, "streams")) {
                    log.streams = walkStreams(b.children);
                }
            },
        }
    }
    return log;
}

fn walkStreams(nodes: []const skg.ast.Node) Streams {
    var s = Streams{};
    for (nodes) |node| {
        switch (node) {
            .field => |f| {
                if (std.mem.eql(u8, f.key, "stdout")) {
                    s.stdout = f.value.bool;
                } else if (std.mem.eql(u8, f.key, "file")) {
                    s.file = f.value.bool;
                } else if (std.mem.eql(u8, f.key, "syslog")) {
                    s.syslog = f.value.bool;
                }
            },
            .block => {},
        }
    }
    return s;
}

pub fn main() void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // ── Read and parse ─────────────────────────────────────────────────
    // In a real app you'd use skg.parse() which reads from disk and
    // resolves imports. Here we read manually for a self-contained example.
    const cwd = std.fs.cwd();
    const src = cwd.openFile("../app.skg", .{}) catch |err| {
        std.debug.print("cannot open app.skg: {}\n", .{err});
        return;
    };
    defer src.close();
    const data = src.readToEndAlloc(allocator, 1024 * 1024) catch |err| {
        std.debug.print("read error: {}\n", .{err});
        return;
    };
    defer allocator.free(data);

    var result = skg.parseSource(allocator, data, "app.skg");
    defer result.deinit();

    if (result.file == null) {
        if (result.diagnostic) |d| {
            std.debug.print("parse error: {s}:{d}:{d}: {s}\n", .{ d.path, d.line, d.col, d.message });
        }
        return;
    }
    const file = result.file.?;

    // ── Walk the AST into our struct ───────────────────────────────────
    const cfg = walkConfig(file.children);

    // ── Use it ─────────────────────────────────────────────────────────
    const p = std.debug.print;
    p("name:         {s}\n", .{cfg.name});
    p("port:         {d}\n", .{cfg.port});
    p("debug:        {}\n", .{cfg.debug});
    p("db:           {s}:{d}/{s} (ssl={}, pool={d})\n", .{
        cfg.database.host,
        cfg.database.port,
        cfg.database.name,
        cfg.database.ssl,
        cfg.database.max_connections,
    });
    p("log level:    {s}\n", .{cfg.logging.level});
    p("log streams:  stdout={} file={} syslog={}\n", .{
        cfg.logging.streams.stdout,
        cfg.logging.streams.file,
        cfg.logging.streams.syslog,
    });
    p("motd:\n{s}\n", .{cfg.motd});
}
