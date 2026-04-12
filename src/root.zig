/// SKG public API.
///
/// Usage:
///   var result = try skg.parse(backing_allocator, "/path/to/config.skg");
///   defer result.deinit();
///   const file = result.file;
///   // walk file.children...
///
/// All AST memory lives in an internal arena. `result.deinit()` frees everything at once.
const std = @import("std");
const Allocator = std.mem.Allocator;
const parser = @import("parser.zig");
const merge = @import("merge.zig");

pub const ast = @import("ast.zig");
pub const File = ast.File;
pub const Node = ast.Node;
pub const Block = ast.Block;
pub const Field = ast.Field;
pub const Value = ast.Value;
pub const ValueType = ast.ValueType;
pub const Array = ast.Array;

pub const ParseError = parser.ParseError;

/// A parsed SKG file tree with its owning arena.
/// Call `deinit()` to release all memory.
pub const ParseResult = struct {
    arena: std.heap.ArenaAllocator,
    file: ast.File,

    pub fn deinit(self: *ParseResult) void {
        self.arena.deinit();
    }
};

/// Parse an SKG file from disk, resolving imports recursively.
/// Returns a ParseResult whose arena owns all AST memory.
pub fn parse(backing: Allocator, path: []const u8) !ParseResult {
    var arena = std.heap.ArenaAllocator.init(backing);
    errdefer arena.deinit();

    var visited = std.StringHashMap(void).init(backing);
    defer visited.deinit();

    const file = try parseWithVisited(arena.allocator(), path, &visited);
    return ParseResult{ .arena = arena, .file = file };
}

/// Parse SKG source from a string. No import resolution.
pub fn parseSource(backing: Allocator, src: []const u8, path: []const u8) !ParseResult {
    var arena = std.heap.ArenaAllocator.init(backing);
    errdefer arena.deinit();
    const file = try parser.parseSource(arena.allocator(), src, path);
    return ParseResult{ .arena = arena, .file = file };
}

fn parseWithVisited(
    allocator: Allocator,
    path: []const u8,
    visited: *std.StringHashMap(void),
) !ast.File {
    // Circular import guard
    if (visited.contains(path)) return error.CircularImport;
    try visited.put(path, {});
    defer _ = visited.remove(path);

    // Read source
    const f = try std.fs.cwd().openFile(path, .{});
    defer f.close();
    const src = try f.readToEndAlloc(allocator, std.math.maxInt(usize));

    // Parse this file
    var result = try parser.parseSource(allocator, src, path);

    // Resolve imports
    if (result.import_paths.len > 0) {
        const dir = std.fs.path.dirname(path) orelse ".";
        var merged: []ast.Node = &.{};

        for (result.import_paths) |import_path| {
            const abs = try std.fs.path.join(allocator, &.{ dir, import_path });
            const imported = try parseWithVisited(allocator, abs, visited);
            merged = try merge.mergeNodes(allocator, merged, imported.children);
        }

        // Main file's children overlay the merged imports
        result.children = try merge.mergeNodes(allocator, merged, result.children);
    }

    return result;
}
