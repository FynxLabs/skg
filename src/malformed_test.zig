// Malformed SKG input rejection tests.
//
// Ensures that invalid SKG syntax is rejected with a meaningful error
// and never panics or produces a corrupt AST.
//
// Coverage:
//   - Lexer errors (bad escape sequence, unterminated string)
//   - Parser errors (missing colon, unclosed block, mixed array types)
const std = @import("std");
const testing = std.testing;

const skg_root = @import("root.zig");

// ─── Helpers ─────────────────────────────────────────────────────────────────

fn parseOnly(src: []const u8) !skg_root.ParseResult {
    return skg_root.parseSource(testing.allocator, src, "<test>");
}

// ─── Lexer errors ─────────────────────────────────────────────────────────────

test "reject unterminated string" {
    const err = parseOnly("key: \"unterminated");
    try testing.expectError(error.UnterminatedString, err);
}

test "reject bad escape sequence" {
    const err = parseOnly("key: \"bad \\q escape\"");
    try testing.expectError(error.InvalidEscape, err);
}

// ─── Parser errors ────────────────────────────────────────────────────────────

test "reject missing colon" {
    const err = parseOnly("key \"value\"");
    try testing.expectError(error.UnexpectedToken, err);
}

test "reject unclosed block" {
    const err = parseOnly("theme {\n  accent: \"green\"\n");
    try testing.expectError(error.ExpectedRbrace, err);
}

test "reject mixed array types" {
    const err = parseOnly("arr: [1, \"two\", 3]");
    try testing.expectError(error.MixedArrayTypes, err);
}

test "reject duplicate skg_version" {
    const err = parseOnly("skg_version: 1.0\nskg_version: 2.0\n");
    try testing.expectError(error.DuplicateSKGVersion, err);
}

test "reject duplicate schema_version" {
    const err = parseOnly("schema_version: \"1.0.0\"\nschema_version: \"2.0.0\"\n");
    try testing.expectError(error.DuplicateSchemaVersion, err);
}
