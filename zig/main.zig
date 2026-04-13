const std = @import("std");
const skg = @import("skg");

const usage =
    \\Usage: skg <command> [options] [files...]
    \\
    \\Commands:
    \\  fmt    Format SKG files
    \\
    \\Options:
    \\  --check    Check if files are formatted (exit 1 if not)
    \\  --stdin    Read from stdin, write to stdout
    \\  -h, --help Show this help
    \\
;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const stderr: std.fs.File = .stderr();
    const stdout: std.fs.File = .stdout();

    if (args.len < 2) {
        try stderr.writeAll(usage);
        std.process.exit(1);
    }

    if (std.mem.eql(u8, args[1], "fmt")) {
        std.process.exit(try fmtCommand(allocator, args[2..]));
    } else if (std.mem.eql(u8, args[1], "-h") or std.mem.eql(u8, args[1], "--help")) {
        try stdout.writeAll(usage);
    } else {
        var buf: [256]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, "unknown command: {s}\n", .{args[1]}) catch "unknown command\n";
        try stderr.writeAll(msg);
        try stderr.writeAll(usage);
        std.process.exit(1);
    }
}

fn fmtCommand(allocator: std.mem.Allocator, args: []const []const u8) !u8 {
    var check = false;
    var use_stdin = false;
    var files: std.ArrayListUnmanaged([]const u8) = .empty;

    for (args) |arg| {
        if (std.mem.eql(u8, arg, "--check")) {
            check = true;
        } else if (std.mem.eql(u8, arg, "--stdin")) {
            use_stdin = true;
        } else if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
            const stdout: std.fs.File = .stdout();
            try stdout.writeAll(usage);
            return 0;
        } else if (std.mem.startsWith(u8, arg, "-")) {
            const stderr: std.fs.File = .stderr();
            var buf: [256]u8 = undefined;
            const msg = std.fmt.bufPrint(&buf, "unknown flag: {s}\n", .{arg}) catch "unknown flag\n";
            try stderr.writeAll(msg);
            return 1;
        } else {
            try files.append(allocator, arg);
        }
    }

    if (use_stdin) {
        return try fmtStdin(allocator, check);
    }

    if (files.items.len == 0) {
        const stderr: std.fs.File = .stderr();
        try stderr.writeAll("skg fmt: no files specified\n");
        return 1;
    }

    var any_changed: bool = false;
    for (files.items) |path| {
        const changed = fmtFile(allocator, path, check) catch |err| {
            const stderr: std.fs.File = .stderr();
            var buf: [512]u8 = undefined;
            const msg = std.fmt.bufPrint(&buf, "{s}: {s}\n", .{ path, @errorName(err) }) catch "format error\n";
            try stderr.writeAll(msg);
            return 1;
        };
        if (changed) any_changed = true;
    }

    if (check and any_changed) return 1;
    return 0;
}

fn fmtStdin(allocator: std.mem.Allocator, check: bool) !u8 {
    const stdin: std.fs.File = .stdin();
    const src = try stdin.readToEndAlloc(allocator, 10 * 1024 * 1024);
    defer allocator.free(src);

    var result = skg.parseSource(allocator, src, "<stdin>");
    defer result.deinit();

    if (result.file == null) {
        if (result.diagnostic) |d| {
            const stderr: std.fs.File = .stderr();
            var buf: [512]u8 = undefined;
            const msg = std.fmt.bufPrint(&buf, "<stdin>:{d}:{d}: {s}\n", .{ d.line, d.col, d.message }) catch "parse error\n";
            try stderr.writeAll(msg);
        }
        return 1;
    }

    const formatted = try skg.emit.emitFile(allocator, result.file.?);
    defer allocator.free(formatted);

    if (check) {
        if (!std.mem.eql(u8, src, formatted)) {
            const stderr: std.fs.File = .stderr();
            try stderr.writeAll("<stdin>: not formatted\n");
            return 1;
        }
        return 0;
    }

    const stdout: std.fs.File = .stdout();
    try stdout.writeAll(formatted);
    return 0;
}

fn fmtFile(allocator: std.mem.Allocator, path: []const u8, check: bool) !bool {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const src = try file.readToEndAlloc(allocator, 10 * 1024 * 1024);
    defer allocator.free(src);

    var result = skg.parseSource(allocator, src, path);
    defer result.deinit();

    if (result.file == null) {
        if (result.diagnostic) |d| {
            const stderr: std.fs.File = .stderr();
            var buf: [512]u8 = undefined;
            const msg = std.fmt.bufPrint(&buf, "{s}:{d}:{d}: {s}\n", .{ d.path, d.line, d.col, d.message }) catch "parse error\n";
            try stderr.writeAll(msg);
        }
        return error.ParseError;
    }

    const formatted = try skg.emit.emitFile(allocator, result.file.?);
    defer allocator.free(formatted);

    if (std.mem.eql(u8, src, formatted)) return false;

    if (check) {
        const stderr: std.fs.File = .stderr();
        try stderr.writeAll(path);
        try stderr.writeAll("\n");
        return true;
    }

    // Write formatted content back
    const out = try std.fs.cwd().createFile(path, .{});
    defer out.close();
    try out.writeAll(formatted);
    return true;
}
