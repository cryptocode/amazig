//! SPDX-License-Identifier: MIT
//! A simple terminal application that animates the generation of a maze.
//! Use a modern terminal like Kitty, Ghostty or WezTerm.

const std = @import("std");
const amazig = @import("amazig");

// Try playing around with these settings:
const show_path_arrows = false;
const print_wallified_maze = true;
const animate_generation = true;

// Increase to slow down the animation
const animation_delay_ms = 2;

pub fn main() !void {
    // In this case we use a fixed seed to get a reproducible maze
    var rng = std.Random.Xoshiro256.init(1);

    // Rows and columns in terms of path size. Walls are not included in this size.
    const rows = 12;
    const cols = 12;

    // This can also be a statically allocated buffer
    const path_buffer = try std.heap.c_allocator.alloc(u32, rows * cols);
    defer std.heap.c_allocator.free(path_buffer);

    var maze = try amazig.Maze.init(
        path_buffer,
        rows,
        cols,
        rng.random(),
        if (animate_generation) 0 else null,
    );

    if (!animate_generation) {
        if (print_wallified_maze) {
            try printMazeWithWalls(&maze, std.io.getStdOut().writer());
        } else {
            try printMazePaths(&maze, std.io.getStdOut().writer());
        }
    } else {
        try std.io.getStdOut().writer().print("\x1b[?25l", .{});
        for (0..rows * cols * 8 + 10) |_| {
            try std.io.getStdOut().writer().print("\x1b[?2026h", .{});
            try std.io.getStdOut().writer().print("\x1b[H\x1b[J", .{});

            if (print_wallified_maze) {
                try printMazeWithWalls(&maze, std.io.getStdOut().writer());
            } else {
                try printMazePaths(&maze, std.io.getStdOut().writer());
            }

            maze.iterateOnce(@enumFromInt(maze.random.intRangeAtMost(u2, 0, 3)));
            try std.io.getStdOut().writer().print("\x1b[?2026l", .{});
            std.time.sleep(std.time.ns_per_ms * animation_delay_ms);
        }
        try std.io.getStdOut().writer().print("\x1b[?25h", .{});
    }
}

pub fn printMazePaths(maze: *amazig.Maze, writer: anytype) !void {
    var offset: u32 = 0;
    for (0..maze.path_rows) |_| {
        for (0..maze.path_columns) |_| {
            if (maze.path[offset] == amazig.None) {
                try writer.print(" 😊", .{});
            } else {
                const diff = @as(i32, @intCast(maze.path[offset])) - @as(i32, @intCast(offset));
                const arrow = if (diff == -@as(i32, @intCast(maze.path_columns))) " ↑ " else if (diff == maze.path_columns) " ↓ " else if (diff == -1) " ← " else " → ";
                try writer.print("{s}", .{arrow});
            }
            offset += 1;
        }
        try writer.print("\n", .{});
    }
}

pub fn printMazeWithWalls(maze: *amazig.Maze, writer: anytype) !void {
    const size = maze.getWallifiedMazeSize();
    for (0..size.row) |r| {
        for (0..size.column) |c| {
            const maybe_cell = maze.getWallifiedMazeCell(@intCast(r), @intCast(c));
            if (maybe_cell) |cell| {
                switch (cell) {
                    .origin => try writer.print("😊", .{}),
                    .wall => |dir| {
                        _ = dir;
                        try writer.print("██", .{});
                    },
                    .path => |dir| {
                        if (show_path_arrows) {
                            const arrow: u21 = switch (dir) {
                                .left => '←',
                                .right => '→',
                                .up => '↑',
                                .down => '↓',
                            };
                            try writer.print("{u} ", .{arrow});
                        } else try writer.print("  ", .{});
                    },
                }
            } else std.debug.assert(false);
        }
        try writer.print("\n", .{});
    }
    try writer.print("\n", .{});
}
