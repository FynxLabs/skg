/// SKG merge - overlays one node list on top of another.
///
/// Used by root.zig to apply import files before the main file.
/// Load order rule: later values overwrite earlier values.
/// Block children are merged recursively by name.
///
/// All allocations go into `allocator`. With an arena, this is free to discard.
const std = @import("std");
const Allocator = std.mem.Allocator;
const ast = @import("ast.zig");

/// Merge `overlay` nodes on top of `base`, returning a new owned slice.
///
/// - Fields with the same key: overlay wins.
/// - Blocks with the same name: children merged recursively, overlay children win.
/// - New keys/blocks from overlay are appended.
///
/// Neither `base` nor `overlay` is modified. The result may reference elements
/// from both - only free via the allocator/arena that owns this memory.
pub fn mergeNodes(allocator: Allocator, base: []const ast.Node, overlay: []const ast.Node) ![]ast.Node {
    var result: std.ArrayListUnmanaged(ast.Node) = .empty;

    // start with all base nodes
    for (base) |node| {
        try result.append(allocator, node);
    }

    // apply overlay
    for (overlay) |ov_node| {
        switch (ov_node) {
            .field => |ov_field| {
                var replaced = false;
                for (result.items, 0..) |*r, i| {
                    if (r.* == .field and std.mem.eql(u8, r.field.key, ov_field.key)) {
                        result.items[i] = ov_node;
                        replaced = true;
                        break;
                    }
                }
                if (!replaced) try result.append(allocator, ov_node);
            },
            .block => |ov_block| {
                var replaced = false;
                for (result.items, 0..) |*r, i| {
                    if (r.* == .block and std.mem.eql(u8, r.block.name, ov_block.name)) {
                        const merged = try mergeNodes(allocator, r.block.children, ov_block.children);
                        result.items[i] = ast.Node{ .block = .{
                            .name = r.block.name,
                            .children = merged,
                            .line = r.block.line,
                            .col = r.block.col,
                        } };
                        replaced = true;
                        break;
                    }
                }
                if (!replaced) try result.append(allocator, ov_node);
            },
        }
    }

    return result.toOwnedSlice(allocator);
}
