/// SKG conformance tests — validates the Zig parser against shared testdata/ fixtures.
///
/// Each valid fixture is a .skg file with a .expected.json file describing the expected AST.
/// Each invalid fixture is a .skg file that should fail to parse, with a .expected.json
/// describing the expected error message substring.
const std = @import("std");
const testing = std.testing;
const skg_root = @import("root.zig");
const ast = @import("ast.zig");

// ─── Valid fixtures ─────────────────────────────────────────────────────────

const valid_fixtures = [_][]const u8{
    "all-types",
    "arrays",
    "block",
    "comments",
    "duplicate-lastwins",
    "empty",
    "escaped-string",
    "imports",
    "multiline-string",
    "nested-array",
    "nested-block",
    "simple-string",
    "versions",
};

const invalid_fixtures = [_][]const u8{
    "bad-escape",
    "duplicate-skg-version",
    "missing-colon",
    "mixed-array",
    "unclosed-block",
    "unterminated-array",
    "unterminated-string",
};

fn readFixture(alloc: std.mem.Allocator, comptime subdir: []const u8, name: []const u8, comptime ext: []const u8) ![]u8 {
    var path_buf: [512]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "testdata/{s}/{s}{s}", .{ subdir, name, ext }) catch return error.PathTooLong;

    const cwd = std.fs.cwd();
    const file = cwd.openFile(path, .{}) catch |err| {
        std.debug.print("Failed to open {s}: {}\n", .{ path, err });
        return err;
    };
    defer file.close();
    return file.readToEndAlloc(alloc, 1024 * 1024);
}

// ─── JSON parsing helpers ───────────────────────────────────────────────────

fn expectJsonString(json: std.json.Value) ?[]const u8 {
    return switch (json) {
        .string => |s| s,
        else => null,
    };
}

fn expectJsonBool(json: std.json.Value) ?bool {
    return switch (json) {
        .bool => |b| b,
        else => null,
    };
}

fn expectJsonInt(json: std.json.Value) ?i64 {
    return switch (json) {
        .integer => |n| n,
        else => null,
    };
}

fn expectJsonFloat(json: std.json.Value) ?f64 {
    return switch (json) {
        .float => |f| f,
        .integer => |n| @as(f64, @floatFromInt(n)),
        else => null,
    };
}

fn expectJsonArray(json: std.json.Value) ?[]std.json.Value {
    return switch (json) {
        .array => |a| a.items,
        else => null,
    };
}

fn expectJsonObject(json: std.json.Value) ?std.json.ObjectMap {
    return switch (json) {
        .object => |o| o,
        else => null,
    };
}

// ─── AST comparison ─────────────────────────────────────────────────────────

fn compareValue(expected_obj: std.json.ObjectMap, actual: ast.Value) !void {
    const type_str = expectJsonString(expected_obj.get("type") orelse return error.MissingType) orelse return error.BadType;

    if (std.mem.eql(u8, type_str, "string")) {
        try testing.expectEqual(ast.ValueType.string, std.meta.activeTag(actual));
        const expected_data = expectJsonString(expected_obj.get("data") orelse return error.MissingData) orelse return error.BadData;
        try testing.expectEqualStrings(expected_data, actual.string);
    } else if (std.mem.eql(u8, type_str, "int")) {
        try testing.expectEqual(ast.ValueType.int, std.meta.activeTag(actual));
        const expected_data = expectJsonInt(expected_obj.get("data") orelse return error.MissingData) orelse return error.BadData;
        try testing.expectEqual(expected_data, actual.int);
    } else if (std.mem.eql(u8, type_str, "float")) {
        try testing.expectEqual(ast.ValueType.float, std.meta.activeTag(actual));
        const expected_data = expectJsonFloat(expected_obj.get("data") orelse return error.MissingData) orelse return error.BadData;
        try testing.expectApproxEqAbs(expected_data, actual.float, 1e-9);
    } else if (std.mem.eql(u8, type_str, "bool")) {
        try testing.expectEqual(ast.ValueType.bool, std.meta.activeTag(actual));
        const expected_data = expectJsonBool(expected_obj.get("data") orelse return error.MissingData) orelse return error.BadData;
        try testing.expectEqual(expected_data, actual.bool);
    } else if (std.mem.eql(u8, type_str, "null")) {
        try testing.expectEqual(ast.ValueType.@"null", std.meta.activeTag(actual));
    } else if (std.mem.eql(u8, type_str, "array")) {
        try testing.expectEqual(ast.ValueType.array, std.meta.activeTag(actual));
        const expected_items = expectJsonArray(expected_obj.get("data") orelse return error.MissingData) orelse return error.BadData;
        try testing.expectEqual(expected_items.len, actual.array.items.len);
        for (expected_items, 0..) |item_json, i| {
            const item_obj = expectJsonObject(item_json) orelse return error.BadArrayItem;
            try compareValue(item_obj, actual.array.items[i]);
        }
    } else {
        std.debug.print("Unknown type in expected JSON: {s}\n", .{type_str});
        return error.UnknownType;
    }
}

fn compareNodes(expected_children: []std.json.Value, actual_children: []const ast.Node) !void {
    try testing.expectEqual(expected_children.len, actual_children.len);

    for (expected_children, 0..) |child_json, i| {
        const child_obj = expectJsonObject(child_json) orelse return error.BadChild;
        const node_type = expectJsonString(child_obj.get("type") orelse return error.MissingNodeType) orelse return error.BadNodeType;

        if (std.mem.eql(u8, node_type, "field")) {
            const actual = actual_children[i];
            try testing.expect(actual == .field);
            const expected_key = expectJsonString(child_obj.get("key") orelse return error.MissingKey) orelse return error.BadKey;
            try testing.expectEqualStrings(expected_key, actual.field.key);

            if (child_obj.get("value")) |val_json| {
                const val_obj = expectJsonObject(val_json) orelse return error.BadValue;
                try compareValue(val_obj, actual.field.value);
            }
        } else if (std.mem.eql(u8, node_type, "block")) {
            const actual = actual_children[i];
            try testing.expect(actual == .block);
            const expected_name = expectJsonString(child_obj.get("name") orelse return error.MissingName) orelse return error.BadName;
            try testing.expectEqualStrings(expected_name, actual.block.name);

            if (child_obj.get("children")) |children_json| {
                const nested = expectJsonArray(children_json) orelse return error.BadChildren;
                try compareNodes(nested, actual.block.children);
            }
        }
    }
}

fn compareNullableString(expected_json: std.json.Value, actual: ?[]const u8) !void {
    switch (expected_json) {
        .null => try testing.expect(actual == null),
        .string => |s| {
            try testing.expect(actual != null);
            try testing.expectEqualStrings(s, actual.?);
        },
        else => return error.BadExpectedJson,
    }
}

// ─── Test runners ───────────────────────────────────────────────────────────

fn runValidFixture(name: []const u8) !void {
    const skg_data = try readFixture(testing.allocator, "valid", name, ".skg");
    defer testing.allocator.free(skg_data);

    const json_data = try readFixture(testing.allocator, "valid", name, ".expected.json");
    defer testing.allocator.free(json_data);

    const parsed_json = std.json.parseFromSlice(std.json.Value, testing.allocator, json_data, .{}) catch |err| {
        std.debug.print("FAIL valid/{s}: bad JSON: {}\n", .{ name, err });
        return error.BadFixtureJson;
    };
    defer parsed_json.deinit();

    const root_obj = expectJsonObject(parsed_json.value) orelse return error.BadRoot;

    var result = skg_root.parseSource(testing.allocator, skg_data, name);
    defer result.deinit();

    if (result.file == null) {
        std.debug.print("FAIL valid/{s}: parse failed", .{name});
        if (result.diagnostic) |d| {
            std.debug.print(": {s}:{d}:{d}: {s}", .{ d.path, d.line, d.col, d.message });
        }
        std.debug.print("\n", .{});
        return error.ParseFailed;
    }
    const file = result.file.?;

    // Compare skg_version
    if (root_obj.get("skg_version")) |v| {
        try compareNullableString(v, file.skg_version);
    }

    // Compare schema_version
    if (root_obj.get("schema_version")) |v| {
        try compareNullableString(v, file.schema_version);
    }

    // Compare imports
    if (root_obj.get("imports")) |imports_json| {
        if (expectJsonArray(imports_json)) |expected_imports| {
            try testing.expectEqual(expected_imports.len, file.import_paths.len);
            for (expected_imports, 0..) |imp_json, i| {
                const imp_str = expectJsonString(imp_json) orelse return error.BadImport;
                try testing.expectEqualStrings(imp_str, file.import_paths[i]);
            }
        }
    }

    // Compare children
    if (root_obj.get("children")) |children_json| {
        const expected_children = expectJsonArray(children_json) orelse return error.BadChildren;
        compareNodes(expected_children, file.children) catch |err| {
            std.debug.print("FAIL valid/{s}: children mismatch: {}\n", .{ name, err });
            return err;
        };
    }
}

test "conformance: valid fixtures" {
    for (valid_fixtures) |name| {
        runValidFixture(name) catch |err| {
            std.debug.print("FAIL valid/{s}: {}\n", .{ name, err });
            return err;
        };
    }
}

fn runInvalidFixture(name: []const u8) !void {
    const skg_data = try readFixture(testing.allocator, "invalid", name, ".skg");
    defer testing.allocator.free(skg_data);

    const json_data = try readFixture(testing.allocator, "invalid", name, ".expected.json");
    defer testing.allocator.free(json_data);

    const parsed_json = std.json.parseFromSlice(std.json.Value, testing.allocator, json_data, .{}) catch |err| {
        std.debug.print("FAIL invalid/{s}: bad JSON: {}\n", .{ name, err });
        return error.BadFixtureJson;
    };
    defer parsed_json.deinit();

    const root_obj = expectJsonObject(parsed_json.value) orelse return error.BadRoot;

    var result = skg_root.parseSource(testing.allocator, skg_data, name);
    defer result.deinit();

    // Should have failed
    if (result.file != null) {
        std.debug.print("FAIL invalid/{s}: expected parse error, got success\n", .{name});
        return error.ExpectedParseError;
    }

    // Check message_contains if specified
    if (root_obj.get("message_contains")) |mc_json| {
        const needle = expectJsonString(mc_json) orelse return error.BadMessageContains;
        const diag = result.diagnostic orelse {
            std.debug.print("FAIL invalid/{s}: no diagnostic\n", .{name});
            return error.NoDiagnostic;
        };
        if (std.mem.indexOf(u8, diag.message, needle) == null) {
            std.debug.print("FAIL invalid/{s}: message \"{s}\" does not contain \"{s}\"\n", .{ name, diag.message, needle });
            return error.MessageMismatch;
        }
    }
}

test "conformance: invalid fixtures" {
    for (invalid_fixtures) |name| {
        runInvalidFixture(name) catch |err| {
            std.debug.print("FAIL invalid/{s}: {}\n", .{ name, err });
            return err;
        };
    }
}
