//! The header name id of a lower-case name through a perfect hash per
//! length over header_names.names: the length picks a group, up to three
//! bytes of the name pick a slot in the group's table, and one compare
//! with the slot's name settles it.
//!
//! The byte positions and the multipliers of each group are found at
//! compile time, starting from one byte and adding another until every
//! name of the length has a slot of its own.

const std = @import("std");
const header_names = @import("header_names.zig");
const names = header_names.names;

/// The longest name a group covers; a longer one is never known.
pub const max_len = 64;

/// Slots per group: enough for the largest group at two per name.
const group_bits = 5;
const group_size = 1 << group_bits;

const Group = struct {
    /// How many of `at` and `mul` are used.
    bytes: u8,
    at: [3]u8,
    mul: [3]u32,
    ids: [group_size]i8,

    fn slot(g: *const Group, name: []const u8) usize {
        var h: u32 = 0;
        inline for (0..3) |i| {
            if (i < g.bytes) h ^= @as(u32, name[g.at[i]]) *% g.mul[i];
        }
        return (h *% 0x9E3779B1) >> (32 - group_bits);
    }
};

const groups: [max_len + 1]?Group = blk: {
    @setEvalBranchQuota(10_000_000);
    var out: [max_len + 1]?Group = @splat(null);
    for (0..max_len + 1) |len| {
        var members: [group_size]usize = undefined;
        var count: usize = 0;
        for (names, 0..) |name, id| {
            if (name.len != len) continue;
            if (count == group_size / 2) @compileError("too many header names of one length");
            members[count] = id;
            count += 1;
        }
        if (count == 0) continue;
        out[len] = findGroup(len, members[0..count]) orelse
            @compileError(std.fmt.comptimePrint("no perfect hash for the header names of length {d}", .{len}));
    }
    break :blk out;
};

fn findGroup(len: usize, members: []const usize) ?Group {
    var rng: u32 = 0x2545F491;
    var bytes: u8 = 1;
    while (bytes <= 3) : (bytes += 1) {
        var at: [3]u8 = @splat(0);
        // Every choice of `bytes` positions, in order.
        var pick: [3]usize = .{ 0, 1, 2 };
        while (true) {
            for (0..bytes) |i| at[i] = @intCast(pick[i]);
            var tries: usize = 0;
            while (tries < 64) : (tries += 1) {
                var g: Group = .{ .bytes = bytes, .at = at, .mul = undefined, .ids = @splat(-1) };
                for (0..3) |i| {
                    rng = rng *% 1664525 +% 1013904223;
                    g.mul[i] = rng | 1;
                }
                var ok = true;
                for (members) |id| {
                    const s = g.slot(names[id]);
                    if (g.ids[s] >= 0) {
                        ok = false;
                        break;
                    }
                    g.ids[s] = @intCast(id);
                }
                if (ok) return g;
            }
            // The next choice of positions, or none left for this count.
            var i: usize = bytes;
            while (i > 0) {
                i -= 1;
                if (pick[i] + (bytes - 1 - i) < len - 1) {
                    pick[i] += 1;
                    for (i + 1..bytes) |j| pick[j] = pick[j - 1] + 1;
                    break;
                }
            } else break;
        }
    }
    return null;
}

/// Every name padded with zeros to `max_len`, for a compare by blocks.
const padded: [names.len][max_len]u8 = blk: {
    var out: [names.len][max_len]u8 = undefined;
    for (names, 0..) |name, id| {
        out[id] = @splat(0);
        @memcpy(out[id][0..name.len], name);
    }
    break :blk out;
};

/// The id of `lower`, a lower-case name, or -1.
pub fn lookupLower(lower: []const u8) i32 {
    if (lower.len > max_len) return -1;
    var buf: [max_len]u8 = @splat(0);
    @memcpy(buf[0..lower.len], lower);
    return lookupPadded(&buf, lower.len);
}

/// The id of the lower-case name in `lower[0..len]`, zero-padded to
/// `max_len`, or -1. The compare runs sixteen bytes at a time over the
/// blocks the name reaches into, zeros against zeros past its end.
pub fn lookupPadded(lower: *const [max_len]u8, len: usize) i32 {
    if (len > max_len) return -1;
    const g = &(groups[len] orelse return -1);
    const id = g.ids[g.slot(lower)];
    if (id < 0) return -1;
    const candidate = &padded[@intCast(id)];
    const Bytes16 = @Vector(16, u8);
    var at: usize = 0;
    while (at < len) : (at += 16) {
        const a: Bytes16 = lower[at..][0..16].*;
        const b: Bytes16 = candidate[at..][0..16].*;
        if (!@reduce(.And, a == b)) return -1;
    }
    return id;
}

test "every name looks itself up in lower case, a stranger does not" {
    for (names, 0..) |name, id| {
        try std.testing.expectEqual(@as(i32, @intCast(id)), lookupLower(name));
    }
    try std.testing.expectEqual(@as(i32, -1), lookupLower("x-custom"));
    try std.testing.expectEqual(@as(i32, -1), lookupLower("content-typo"));
    try std.testing.expectEqual(@as(i32, -1), lookupLower("Content-Type"));
    try std.testing.expectEqual(@as(i32, -1), lookupLower("a"));
    try std.testing.expectEqual(@as(i32, -1), lookupLower(""));
}
