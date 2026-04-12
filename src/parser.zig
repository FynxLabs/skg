/// SKG parser - builds an AST from a token stream.
///
/// All allocations go into the caller-provided allocator (use an arena for easy cleanup).
/// Returns an ast.File with all memory owned by that allocator.
///
/// Import resolution is NOT handled here - see root.zig.
const std = @import("std");
const Allocator = std.mem.Allocator;
const Lexer = @import("lexer.zig").Lexer;
const LexError = @import("lexer.zig").LexError;
const Token = @import("token.zig").Token;
const Tag = @import("token.zig").Tag;
const ast = @import("ast.zig");

pub const ParseError = LexError || error{
    UnexpectedToken,
    ExpectedValue,
    ExpectedRbrace,
    ExpectedRbracket,
    MixedArrayTypes,
    DuplicateSKGVersion,
    DuplicateSchemaVersion,
    InvalidInt,
    InvalidFloat,
    OutOfMemory,
};

const Parser = struct {
    allocator: Allocator,
    lexer: Lexer,
    peeked: ?Token,
    path: []const u8,

    fn init(allocator: Allocator, src: []const u8, path: []const u8) Parser {
        return .{
            .allocator = allocator,
            .lexer = Lexer.init(src),
            .peeked = null,
            .path = path,
        };
    }

    fn peek(self: *Parser) ParseError!Token {
        if (self.peeked == null) {
            self.peeked = try self.lexer.next();
        }
        return self.peeked.?;
    }

    fn consume(self: *Parser) ParseError!Token {
        if (self.peeked) |t| {
            self.peeked = null;
            return t;
        }
        return self.lexer.next();
    }

    fn expect(self: *Parser, tag: Tag) ParseError!Token {
        const t = try self.consume();
        if (t.tag != tag) return error.UnexpectedToken;
        return t;
    }

    fn parseFile(self: *Parser) ParseError!ast.File {
        var skg_version: ?f64 = null;
        var schema_version: ?[]const u8 = null;
        var import_paths: std.ArrayListUnmanaged([]const u8) = .empty;
        var children: std.ArrayListUnmanaged(ast.Node) = .empty;

        while (true) {
            const t = try self.peek();
            if (t.tag == .eof) break;

            if (t.tag == .ident) {
                if (std.mem.eql(u8, t.text, "skg_version")) {
                    _ = try self.consume();
                    _ = try self.expect(.colon);
                    const val_tok = try self.expect(.float);
                    if (skg_version != null) return error.DuplicateSKGVersion;
                    skg_version = std.fmt.parseFloat(f64, val_tok.text) catch return error.InvalidFloat;
                    continue;
                }
                if (std.mem.eql(u8, t.text, "schema_version")) {
                    _ = try self.consume();
                    _ = try self.expect(.colon);
                    const val_tok = try self.expect(.string);
                    if (schema_version != null) return error.DuplicateSchemaVersion;
                    schema_version = try self.unescapeString(val_tok.text);
                    continue;
                }
                if (std.mem.eql(u8, t.text, "import")) {
                    _ = try self.consume();
                    try self.parseImports(&import_paths);
                    continue;
                }
            }

            const node = try self.parseNode();
            try children.append(self.allocator, node);
        }

        return ast.File{
            .skg_version = skg_version,
            .schema_version = schema_version,
            .import_paths = try import_paths.toOwnedSlice(self.allocator),
            .children = try children.toOwnedSlice(self.allocator),
            .path = self.path,
        };
    }

    fn parseImports(self: *Parser, list: *std.ArrayListUnmanaged([]const u8)) ParseError!void {
        const t = try self.peek();
        if (t.tag == .string) {
            _ = try self.consume();
            try list.append(self.allocator, try self.unescapeString(t.text));
        } else if (t.tag == .lbracket) {
            _ = try self.consume();
            while (true) {
                const nt = try self.peek();
                if (nt.tag == .rbracket) {
                    _ = try self.consume();
                    break;
                }
                if (nt.tag == .comma) {
                    _ = try self.consume();
                    continue;
                }
                if (nt.tag == .eof) return error.ExpectedRbracket;
                const path_tok = try self.expect(.string);
                try list.append(self.allocator, try self.unescapeString(path_tok.text));
            }
        } else {
            return error.UnexpectedToken;
        }
    }

    /// Parse a single node (field or block). Expects an ident token next.
    fn parseNode(self: *Parser) ParseError!ast.Node {
        const name_tok = try self.expect(.ident);
        const nt = try self.peek();

        if (nt.tag == .colon) {
            _ = try self.consume();
            const value = try self.parseValue();
            return ast.Node{ .field = .{
                .key = name_tok.text,
                .value = value,
                .line = name_tok.line,
                .col = name_tok.col,
            } };
        } else if (nt.tag == .lbrace) {
            _ = try self.consume();
            var children: std.ArrayListUnmanaged(ast.Node) = .empty;
            while (true) {
                const ct = try self.peek();
                if (ct.tag == .rbrace) {
                    _ = try self.consume();
                    break;
                }
                if (ct.tag == .eof) return error.ExpectedRbrace;
                try children.append(self.allocator, try self.parseNode());
            }
            return ast.Node{ .block = .{
                .name = name_tok.text,
                .children = try children.toOwnedSlice(self.allocator),
                .line = name_tok.line,
                .col = name_tok.col,
            } };
        } else {
            return error.UnexpectedToken;
        }
    }

    fn parseValue(self: *Parser) ParseError!ast.Value {
        const t = try self.consume();
        return switch (t.tag) {
            .int => ast.Value{ .int = std.fmt.parseInt(i64, t.text, 10) catch return error.InvalidInt },
            .float => ast.Value{ .float = std.fmt.parseFloat(f64, t.text) catch return error.InvalidFloat },
            .bool_true => ast.Value{ .bool = true },
            .bool_false => ast.Value{ .bool = false },
            .string => ast.Value{ .string = try self.unescapeString(t.text) },
            .lbracket => try self.parseArray(),
            else => error.ExpectedValue,
        };
    }

    /// Parse array elements. `[` already consumed.
    fn parseArray(self: *Parser) ParseError!ast.Value {
        var items: std.ArrayListUnmanaged(ast.Value) = .empty;
        var element_type: ?ast.ValueType = null;

        while (true) {
            const t = try self.peek();
            if (t.tag == .rbracket) {
                _ = try self.consume();
                break;
            }
            if (t.tag == .comma) {
                _ = try self.consume();
                continue;
            }
            if (t.tag == .eof) return error.ExpectedRbracket;

            const val = try self.parseValue();
            const vtype = std.meta.activeTag(val);
            if (element_type) |et| {
                if (et != vtype) return error.MixedArrayTypes;
            } else {
                element_type = vtype;
            }
            try items.append(self.allocator, val);
        }

        return ast.Value{ .array = .{
            .element_type = element_type orelse .string,
            .items = try items.toOwnedSlice(self.allocator),
        } };
    }

    /// Strip surrounding quotes and process escape sequences.
    /// `raw` must be a quoted string token including the outer `"` chars.
    fn unescapeString(self: *Parser, raw: []const u8) ParseError![]const u8 {
        std.debug.assert(raw.len >= 2 and raw[0] == '"' and raw[raw.len - 1] == '"');
        const inner = raw[1 .. raw.len - 1];

        var buf: std.ArrayListUnmanaged(u8) = .empty;
        var i: usize = 0;
        while (i < inner.len) {
            if (inner[i] == '\\') {
                i += 1;
                switch (inner[i]) {
                    '"' => try buf.append(self.allocator, '"'),
                    '\\' => try buf.append(self.allocator, '\\'),
                    'n' => try buf.append(self.allocator, '\n'),
                    't' => try buf.append(self.allocator, '\t'),
                    else => return error.InvalidEscape,
                }
            } else {
                try buf.append(self.allocator, inner[i]);
            }
            i += 1;
        }
        return buf.toOwnedSlice(self.allocator);
    }
};

/// Parse an SKG source string into an ast.File.
/// All AST memory is allocated from `allocator` - use an arena for easy cleanup.
/// Import paths are recorded but not resolved (see root.zig).
pub fn parseSource(allocator: Allocator, src: []const u8, path: []const u8) ParseError!ast.File {
    var p = Parser.init(allocator, src, path);
    return p.parseFile();
}
