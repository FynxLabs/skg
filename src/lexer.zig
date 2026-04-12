/// SKG lexer - tokenizes source into a stream of Tokens.
///
/// Returns raw source slices. No allocation. Strings include surrounding quotes.
/// The parser is responsible for unescaping string content.
///
/// Error position: after a LexError, check `lexer.line` and `lexer.col`.
const std = @import("std");
const token = @import("token.zig");

pub const Token = token.Token;
pub const Tag = token.Tag;

pub const LexError = error{
    UnexpectedChar,
    UnterminatedString,
    InvalidEscape,
};

pub const Lexer = struct {
    src: []const u8,
    pos: usize,
    line: u32,
    col: u32,

    pub fn init(src: []const u8) Lexer {
        return .{ .src = src, .pos = 0, .line = 1, .col = 1 };
    }

    fn peek(self: *const Lexer) ?u8 {
        if (self.pos >= self.src.len) return null;
        return self.src[self.pos];
    }

    fn peekAhead(self: *const Lexer, offset: usize) ?u8 {
        const idx = self.pos + offset;
        if (idx >= self.src.len) return null;
        return self.src[idx];
    }

    fn advance(self: *Lexer) u8 {
        const c = self.src[self.pos];
        self.pos += 1;
        if (c == '\n') {
            self.line += 1;
            self.col = 1;
        } else {
            self.col += 1;
        }
        return c;
    }

    fn skipWhitespaceAndComments(self: *Lexer) void {
        while (self.pos < self.src.len) {
            const c = self.src[self.pos];
            if (c == '#') {
                // skip to end of line
                while (self.pos < self.src.len and self.src[self.pos] != '\n') {
                    self.pos += 1;
                }
            } else if (c == ' ' or c == '\t' or c == '\r' or c == '\n') {
                _ = self.advance();
            } else {
                break;
            }
        }
    }

    /// Return the next token. Returns `.eof` at end of input.
    pub fn next(self: *Lexer) LexError!Token {
        self.skipWhitespaceAndComments();

        if (self.pos >= self.src.len) {
            return Token{ .tag = .eof, .text = "", .line = self.line, .col = self.col };
        }

        const tok_line = self.line;
        const tok_col = self.col;
        const c = self.src[self.pos];

        switch (c) {
            ':' => {
                const start = self.pos;
                _ = self.advance();
                return Token{ .tag = .colon, .text = self.src[start..self.pos], .line = tok_line, .col = tok_col };
            },
            '{' => {
                const start = self.pos;
                _ = self.advance();
                return Token{ .tag = .lbrace, .text = self.src[start..self.pos], .line = tok_line, .col = tok_col };
            },
            '}' => {
                const start = self.pos;
                _ = self.advance();
                return Token{ .tag = .rbrace, .text = self.src[start..self.pos], .line = tok_line, .col = tok_col };
            },
            '[' => {
                const start = self.pos;
                _ = self.advance();
                return Token{ .tag = .lbracket, .text = self.src[start..self.pos], .line = tok_line, .col = tok_col };
            },
            ']' => {
                const start = self.pos;
                _ = self.advance();
                return Token{ .tag = .rbracket, .text = self.src[start..self.pos], .line = tok_line, .col = tok_col };
            },
            ',' => {
                const start = self.pos;
                _ = self.advance();
                return Token{ .tag = .comma, .text = self.src[start..self.pos], .line = tok_line, .col = tok_col };
            },
            '"' => return self.lexString(tok_line, tok_col),
            '-' => return self.lexNegativeNumber(tok_line, tok_col),
            '0'...'9' => return self.lexNumber(tok_line, tok_col),
            'a'...'z', 'A'...'Z', '_' => return self.lexIdent(tok_line, tok_col),
            else => return error.UnexpectedChar,
        }
    }

    fn lexString(self: *Lexer, line: u32, col: u32) LexError!Token {
        const start = self.pos;
        _ = self.advance(); // consume opening "

        while (self.pos < self.src.len) {
            const c = self.src[self.pos];
            if (c == '\\') {
                // validate escape sequence
                if (self.pos + 1 >= self.src.len) return error.UnterminatedString;
                switch (self.src[self.pos + 1]) {
                    '"', '\\', 'n', 't' => {},
                    else => return error.InvalidEscape,
                }
                self.pos += 2;
                self.col += 2;
            } else if (c == '"') {
                _ = self.advance(); // consume closing "
                return Token{ .tag = .string, .text = self.src[start..self.pos], .line = line, .col = col };
            } else if (c == '\n') {
                return error.UnterminatedString;
            } else {
                _ = self.advance();
            }
        }
        return error.UnterminatedString;
    }

    fn lexNegativeNumber(self: *Lexer, line: u32, col: u32) LexError!Token {
        // '-' followed by a digit → number. Anything else is an error.
        if (self.peekAhead(1)) |next_c| {
            if (next_c >= '0' and next_c <= '9') {
                return self.lexNumber(line, col);
            }
        }
        return error.UnexpectedChar;
    }

    fn lexNumber(self: *Lexer, line: u32, col: u32) LexError!Token {
        const start = self.pos;
        // optional leading minus
        if (self.peek() == '-') _ = self.advance();
        // integer part: one or more digits
        while (self.peek()) |c| {
            if (c >= '0' and c <= '9') _ = self.advance() else break;
        }
        // decimal point → float
        if (self.peek() == '.') {
            _ = self.advance();
            // fractional digits
            while (self.peek()) |c| {
                if (c >= '0' and c <= '9') _ = self.advance() else break;
            }
            return Token{ .tag = .float, .text = self.src[start..self.pos], .line = line, .col = col };
        }
        return Token{ .tag = .int, .text = self.src[start..self.pos], .line = line, .col = col };
    }

    fn lexIdent(self: *Lexer, line: u32, col: u32) LexError!Token {
        const start = self.pos;
        while (self.peek()) |c| {
            if ((c >= 'a' and c <= 'z') or
                (c >= 'A' and c <= 'Z') or
                (c >= '0' and c <= '9') or
                c == '_')
            {
                _ = self.advance();
            } else break;
        }
        const text = self.src[start..self.pos];
        const tag: Tag = if (std.mem.eql(u8, text, "true"))
            .bool_true
        else if (std.mem.eql(u8, text, "false"))
            .bool_false
        else
            .ident;
        return Token{ .tag = tag, .text = text, .line = line, .col = col };
    }
};
