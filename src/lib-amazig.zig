//! SPDX-License-Identifier: MIT
const std = @import("std");
const testing = std.testing;

pub const Maze = @This();

// This sentinel expresses that a node does not have a next node. This saves
// space over using an optional. Only one node has this value at any given
// time, namely the origin node.
pub const None = std.math.maxInt(u32);

path_rows: u32,
path_columns: u32,
origin: usize,
path: []u32,
random: std.Random,

/// Generate a perfect maze path of the given path dimensions (columns and rows for the paths, without any walls),
/// using the supplied random number generator.
///
/// If `iterations` is null, a heuristic default of `rows*columns*20` will be used.
/// If `iterations` is 0, you are expected to call `iterate` or `iterateOnce` yourself.
/// The `path_buffer` slice must be exactly rows * columns in length, otherwise `InvalidPathBufferSize` is returned.
pub fn init(path_buffer: []u32, rows: u32, columns: u32, random: std.Random, iterations: ?usize) !Maze {
    if (path_buffer.len != rows * columns) return error.InvalidPathBufferSize;
    if (rows < 2 or columns < 2) return error.InvalidMazeSize;

    var self = Maze{
        .path_rows = rows,
        .path_columns = columns,
        .origin = 0,
        .random = random,
        .path = path_buffer,
    };

    // Make all nodes on each row point to their right-hand neighbor.
    var offset: u32 = 0;
    for (0..self.path_rows) |_| {
        for (0..self.path_columns - 1) |_| {
            self.path[offset] = offset + 1;
            offset += 1;
        }

        // Make all rightmost nodes on each row point to the neighbor below.
        self.path[offset] = offset + self.path_columns;
        offset += 1;
    }

    // The very last node (lower right node) is the initial origin node and
    // must thus point nowhere. This initial layout is purely by convention.
    self.origin = self.path.len - 1;
    self.path[self.origin] = None;

    // Randomize the maze
    self.iterate(iterations);

    // At this point, we have a perfect maze which means every node is reachable
    // from any other node through a single path. The origin shift algorithm
    // will maintain this property even if you call `iterate` later on.
    return self;
}

/// The possible directions for origin movement
pub const Direction = enum(u2) {
    right,
    left,
    up,
    down,
};

/// This is called by `init()` to perform the initial mutations. This function can be
/// called any number of times to perform further random mutations.
/// If `iterations` is null, a heuristic is used.
pub fn iterate(self: *Maze, iterations: ?usize) void {
    const i = iterations orelse self.path_rows * self.path_columns * 20;
    for (0..i) |_| {
        self.iterateOnce(@enumFromInt(self.random.intRangeAtMost(u2, 0, 3)));
    }
}

/// Move the origin one step in the given direction. If the movement is not possible,
/// such as when attempting to move down from the last row, this is a no-op.
pub fn iterateOnce(self: *Maze, direction: Direction) void {
    const row = self.origin / self.path_columns;
    const col = self.origin % self.path_columns;

    switch (direction) {
        .right => {
            if (col + 1 < self.path_columns) {
                self.path[self.origin] = @intCast(self.origin + 1);
                self.origin += 1;
                self.path[self.origin] = None;
            }
        },
        .left => {
            if (col > 0) {
                self.path[self.origin] = @intCast(self.origin - 1);
                self.origin -= 1;
                self.path[self.origin] = None;
            }
        },
        .up => {
            if (row > 0) {
                self.path[self.origin] = @intCast(self.origin - self.path_columns);
                self.origin -= self.path_columns;
                self.path[self.origin] = None;
            }
        },
        .down => {
            if (row + 1 < self.path_rows) {
                self.path[self.origin] = @intCast(self.origin + self.path_columns);
                self.origin += self.path_columns;
                self.path[self.origin] = None;
            }
        },
    }
}

/// Row and column dimensions
pub const RowCol = struct {
    row: u32,
    column: u32,
};

/// Returns the current zero-based path row and path column of the origin
pub fn getOrigin(self: *const Maze) RowCol {
    const row = self.origin / self.path_columns;
    const col = self.origin % self.path_columns;
    return .{ .row = @intCast(row), .column = @intCast(col) };
}

/// Given path row and path column coordinates into the maze path, return the
/// offset into the paths slice.
pub fn getOffset(self: *const Maze, row: u32, column: u32) u32 {
    return row * self.path_columns + column;
}

/// A cell in a wallified maze. Using the wallified maze API is optional.
pub const Cell = union(enum) {
    /// The cell is a wall
    wall: void,

    /// The cell is on a path with the given direction towards the origin.
    path: Direction,

    /// The cell is the origin
    origin: void,
};

/// While the library generates the paths inside a maze, this function can be used
/// to figure out if a "wallified" maze's cell is a wall or not. This is just a
/// computation and thus does not require additional memory.
///
/// This is likely the only amazig function you need to call in a typical game loop.
///
/// The output can be used to draw a maze or to construct a custom in-memory representation.
///
/// A wallified maze is surrounded by walls, but you can poke additional holes in walls
/// if you need to, using custom game logic, for instance if you want entrance/exit cells.
///
/// The `row` and `column` are zero-based coordinates into a grid whose size
/// is determined by `getWallifiedMazeSize`
///
/// Returns `null` if `row` or `column` is out of bounds.
pub fn getWallifiedMazeCell(self: *const Maze, row: u32, column: u32) ?Cell {
    return self.getWallifiedMazeCellInternal(row, column, true);
}

fn getWallifiedMazeCellInternal(self: *const Maze, row: u32, column: u32, find_neighbor: bool) ?Cell {
    const size = self.getWallifiedMazeSize();
    if (row >= size.row or column >= size.column) return null;

    // The bounding box is all walls. The library user can still decide to
    // poke holes through walls.
    if (row == 0 or row == size.row - 1 or column == 0 or column == size.column - 1) return .{ .wall = {} };

    // At this point we know that the coordinates are inside the maze
    const path_row = row / 2;
    const path_col = column / 2;
    const path_off = self.getOffset(path_row, path_col);
    const path_next = self.path[path_off];

    // Path cells are at odd numbered row/column indices
    if (row % 2 != 0 and column % 2 != 0) {
        if (path_next == None) {
            return .{ .origin = {} };
        }
        std.debug.assert(path_off < self.path.len);
        return .{ .path = self.computeDirection(path_off, path_next).? };
    } else {
        // Interior wall cell or poke hole for path.
        if (find_neighbor) {
            const north: ?Cell = if (row > 1) self.getWallifiedMazeCellInternal(row - 1, column, false) else null;
            if (north) |neighbor| {
                if (neighbor == .path and neighbor.path == .down) return .{ .path = .down };
            }
            const south: ?Cell = if (row < self.path_rows * 2 - 1) self.getWallifiedMazeCellInternal(row + 1, column, false) else null;
            if (south) |neighbor| {
                if (neighbor == .path and neighbor.path == .up) return .{ .path = .up };
            }
            const west: ?Cell = if (column > 1) self.getWallifiedMazeCellInternal(row, column - 1, false) else null;
            if (west) |neighbor| {
                if (neighbor == .path and neighbor.path == .right) return .{ .path = .right };
            }
            const east: ?Cell = if (column < self.path_columns * 2 - 1) self.getWallifiedMazeCellInternal(row, column + 1, false) else null;
            if (east) |neighbor| {
                if (neighbor == .path and neighbor.path == .left) return .{ .path = .left };
            }
        }

        return .{ .wall = {} };
    }

    return null;
}

/// The wallified maze has walls between the paths, and walls surrounding the entire maze.
/// Given the following path after maze generation:
///
///  ↓ ← → ↓
///  ↓ ✥ ↓ ←
///  → ↑ ← ←
///  ↑ → ↑ ←
///
/// ...the wallified virtual maze looks like the one below. Note how
/// path cells replace any wall cells between themself and the cell
/// they point to:
///
/// █████████
/// █↓←←█→→↓█
/// █↓█████↓█
/// █↓█✥█↓←←█
/// █↓█↑█↓███
/// █→→↑←←←←█
/// █↑███↑███
/// █↑█→→↑←←█
/// █████████
///
/// The wallified maze size is `2r + 1 by 2c + 1`, where `r` and `c` is the original
/// path row and path column dimensions; in other words what you passed to `init`.
///
/// Call `getWallifiedMazeCell` to obtain cells with wall and path information.
pub fn getWallifiedMazeSize(self: *const Maze) RowCol {
    return .{ .row = self.path_rows * 2 + 1, .column = self.path_columns * 2 + 1 };
}

/// Given two path offsets, compute the direction. The cell at `offset2` must be a neighbor of the cell
/// at `offset1`
pub fn computeDirection(self: *const Maze, offset1: u32, offset2: u32) ?Direction {
    const diff = @as(i32, @intCast(offset2)) - @as(i32, @intCast(offset1));
    if (diff == 0) return null;
    return if (diff == -@as(i32, @intCast(self.path_columns))) .up else if (diff == self.path_columns) .down else if (diff == -1) .left else .right;
}

/// Debug and test helper that prints the maze paths to a writer
pub fn dump(maze: *Maze, writer: anytype) !void {
    var offset: u32 = 0;
    for (0..maze.path_rows) |_| {
        for (0..maze.path_columns) |_| {
            if (maze.path[offset] == None) {
                try writer.print(" ✥ ", .{});
            } else {
                const arrow: []const u8 = switch (maze.computeDirection(offset, maze.path[offset]).?) {
                    .left => " ← ",
                    .right => " → ",
                    .up => " ↑ ",
                    .down => " ↓ ",
                };
                try writer.print("{s}", .{arrow});
            }
            offset += 1;
        }
        try writer.print("\n", .{});
    }
}

test "create and check initial state" {
    var rng = std.Random.DefaultPrng.init(@bitCast(std.time.milliTimestamp()));
    const rows = 10;
    const cols = 10;

    // This could also be a statically allocated buffer
    const maze_array = try std.testing.allocator.alloc(u32, rows * cols);
    defer std.testing.allocator.free(maze_array);

    const maze = try Maze.init(
        maze_array,
        rows,
        cols,
        rng.random(),
        0,
    );

    const expected = [100]u32{
        1,  2,  3,  4,  5,  6,  7,  8,  9,  19,
        11, 12, 13, 14, 15, 16, 17, 18, 19, 29,
        21, 22, 23, 24, 25, 26, 27, 28, 29, 39,
        31, 32, 33, 34, 35, 36, 37, 38, 39, 49,
        41, 42, 43, 44, 45, 46, 47, 48, 49, 59,
        51, 52, 53, 54, 55, 56, 57, 58, 59, 69,
        61, 62, 63, 64, 65, 66, 67, 68, 69, 79,
        71, 72, 73, 74, 75, 76, 77, 78, 79, 89,
        81, 82, 83, 84, 85, 86, 87, 88, 89, 99,
        91, 92, 93, 94, 95, 96, 97, 98, 99, None,
    };

    for (maze.path, expected) |m, e| {
        try std.testing.expectEqual(m, e);
    }

    const org = maze.getOrigin();
    try std.testing.expectEqual(9, org.row);
    try std.testing.expectEqual(9, org.column);

    try std.testing.expectEqual(10, maze.getOffset(1, 0));
    try std.testing.expectEqual(23, maze.getOffset(2, 3));

    const size = maze.getWallifiedMazeSize();
    try std.testing.expectEqual(21, size.row);
    try std.testing.expectEqual(21, size.column);
}

test "create and iterate" {
    // Fixed seed for reproducible tests
    var rng = std.Random.Xoshiro256.init(0);
    const rows = 23;
    const cols = 12;

    // This could also be a statically allocated buffer
    const maze_array = try std.testing.allocator.alloc(u32, rows * cols);
    defer std.testing.allocator.free(maze_array);

    var maze = try Maze.init(
        maze_array,
        rows,
        cols,
        rng.random(),
        rows * cols * 15,
    );

    var generation0 = std.ArrayList(u8).init(std.testing.allocator);
    defer generation0.deinit();
    try maze.dump(generation0.writer());

    const expected0 =
        \\ ↓  →  ↓  ←  ←  ←  ↓  ←  ←  ←  ↓  ← 
        \\ ↓  ←  →  ↓  ←  ←  ←  ↑  ↑  ↑  ←  ↑ 
        \\ ↓  ←  →  ↓  →  ↑  ↓  ←  →  ↑  ←  ← 
        \\ ↓  ↓  ↓  ←  ↑  ↑  ↓  ↓  ↑  ←  ←  ← 
        \\ ✥  ←  ←  →  ↑  ↑  ←  ←  ←  ↓  ↑  ← 
        \\ ↑  →  ↑  ←  ←  ↑  ↑  ←  →  ↓  →  ↑ 
        \\ →  ↓  ↑  ↑  ↑  ↑  ↑  ↑  ↑  ↓  →  ↓ 
        \\ ↓  →  ↑  ↓  ↓  ↑  →  ↑  ←  ←  ↓  ↓ 
        \\ ↓  ↑  ←  →  ↓  ↑  ↑  →  ↑  ←  ←  ← 
        \\ →  ↑  →  ↓  ↓  →  →  ↓  ↓  ↓  ↑  ↓ 
        \\ ↑  →  ↓  ↓  ↓  ↑  ↓  →  ↓  ↓  ↑  ← 
        \\ ↑  ↑  →  ↓  ↓  ↑  ←  ↑  →  →  ↓  ↑ 
        \\ →  ↓  ←  ←  →  →  ↑  ←  ↑  →  ↓  ↑ 
        \\ →  →  →  →  →  ↓  ↑  ←  ↓  →  →  ↑ 
        \\ ↑  ↑  ←  ↑  ←  →  ↑  ↑  ←  ↑  →  ↑ 
        \\ →  ↑  ↑  ←  ↑  ↑  ↓  ↓  ↓  →  →  ↑ 
        \\ ↓  ↓  ↑  ←  ↑  ↑  ↓  ←  ←  ←  ←  ↑ 
        \\ ↓  →  ↑  ←  →  ↑  ←  ↑  ↑  ←  ↑  ↑ 
        \\ →  ↑  ←  ←  ←  ←  ←  ↑  ↓  →  ↑  ↑ 
        \\ ↑  ←  ↑  ↑  ↑  →  ↑  ↑  ←  ↓  ←  ↑ 
        \\ ↓  ←  →  →  →  →  ↑  ←  →  →  ↓  ← 
        \\ →  ↓  →  ↑  ↓  ↓  ↑  ↑  ←  →  ↓  ← 
        \\ →  →  ↑  ↑  ←  ←  →  ↑  ↑  ←  ←  ↑ 
        \\
    ;
    try std.testing.expectEqualStrings(expected0, generation0.items);

    // Move the origin right, then upwards
    maze.iterateOnce(.right);
    maze.iterateOnce(.up);

    var generation1 = std.ArrayList(u8).init(std.testing.allocator);
    defer generation1.deinit();
    try maze.dump(generation1.writer());

    const expected1 =
        \\ ↓  →  ↓  ←  ←  ←  ↓  ←  ←  ←  ↓  ← 
        \\ ↓  ←  →  ↓  ←  ←  ←  ↑  ↑  ↑  ←  ↑ 
        \\ ↓  ←  →  ↓  →  ↑  ↓  ←  →  ↑  ←  ← 
        \\ ↓  ✥  ↓  ←  ↑  ↑  ↓  ↓  ↑  ←  ←  ← 
        \\ →  ↑  ←  →  ↑  ↑  ←  ←  ←  ↓  ↑  ← 
        \\ ↑  →  ↑  ←  ←  ↑  ↑  ←  →  ↓  →  ↑ 
        \\ →  ↓  ↑  ↑  ↑  ↑  ↑  ↑  ↑  ↓  →  ↓ 
        \\ ↓  →  ↑  ↓  ↓  ↑  →  ↑  ←  ←  ↓  ↓ 
        \\ ↓  ↑  ←  →  ↓  ↑  ↑  →  ↑  ←  ←  ← 
        \\ →  ↑  →  ↓  ↓  →  →  ↓  ↓  ↓  ↑  ↓ 
        \\ ↑  →  ↓  ↓  ↓  ↑  ↓  →  ↓  ↓  ↑  ← 
        \\ ↑  ↑  →  ↓  ↓  ↑  ←  ↑  →  →  ↓  ↑ 
        \\ →  ↓  ←  ←  →  →  ↑  ←  ↑  →  ↓  ↑ 
        \\ →  →  →  →  →  ↓  ↑  ←  ↓  →  →  ↑ 
        \\ ↑  ↑  ←  ↑  ←  →  ↑  ↑  ←  ↑  →  ↑ 
        \\ →  ↑  ↑  ←  ↑  ↑  ↓  ↓  ↓  →  →  ↑ 
        \\ ↓  ↓  ↑  ←  ↑  ↑  ↓  ←  ←  ←  ←  ↑ 
        \\ ↓  →  ↑  ←  →  ↑  ←  ↑  ↑  ←  ↑  ↑ 
        \\ →  ↑  ←  ←  ←  ←  ←  ↑  ↓  →  ↑  ↑ 
        \\ ↑  ←  ↑  ↑  ↑  →  ↑  ↑  ←  ↓  ←  ↑ 
        \\ ↓  ←  →  →  →  →  ↑  ←  →  →  ↓  ← 
        \\ →  ↓  →  ↑  ↓  ↓  ↑  ↑  ←  →  ↓  ← 
        \\ →  →  ↑  ↑  ←  ←  →  ↑  ↑  ←  ←  ↑ 
        \\
    ;
    try std.testing.expectEqualStrings(expected1, generation1.items);

    // Iterate a few thousand times to get a completely difference maze
    maze.iterate(3000);

    var generation2 = std.ArrayList(u8).init(std.testing.allocator);
    defer generation2.deinit();
    try maze.dump(generation2.writer());

    const expected2 =
        \\ →  ↓  ←  →  →  ↓  ↓  ←  ↓  ↓  ←  ↓ 
        \\ ↑  →  →  ↑  ↓  ←  ←  →  ↓  ←  ↑  ← 
        \\ →  ↑  ↑  ↑  →  ↓  →  →  →  ↓  ↑  ← 
        \\ ↑  →  →  →  →  ↓  →  ↓  ←  ←  ↓  ↓ 
        \\ →  ↑  ↑  →  →  ↓  ←  ↓  →  ↑  ←  ↓ 
        \\ ↑  ←  ↑  →  ↓  →  →  ↓  →  →  ↑  ← 
        \\ ↓  ←  →  ↓  ←  →  ↓  ↓  ↑  ↓  ↑  ↓ 
        \\ →  ↓  ←  ←  →  →  ↓  ←  ↓  ↓  ↓  ↓ 
        \\ ↓  ↓  ↓  ↓  ↓  ↑  ↓  ↑  ←  ←  ↓  ↓ 
        \\ →  →  ↓  →  ↓  ↓  →  ↓  ↑  →  ↓  ↓ 
        \\ →  ↑  →  ↓  ←  ←  ←  →  ↓  ↓  →  ↓ 
        \\ →  ↓  →  →  ↓  ↑  ←  ←  ↓  →  ↓  ↓ 
        \\ ↓  ←  ↓  ←  ↓  ↑  →  ↑  ↓  ↑  ↓  ↓ 
        \\ ↓  →  ↓  ↑  ↓  ↓  ↑  ↓  →  →  →  ↓ 
        \\ →  ↓  ↓  →  →  →  ↓  →  →  ↓  ↓  ← 
        \\ ↓  →  ↓  ↑  →  →  →  ↓  ↓  ←  ↓  ↑ 
        \\ →  →  →  ↓  →  →  ↓  ↓  ←  ↑  ←  ↓ 
        \\ →  ↓  ↑  →  ↑  ←  ↓  ←  →  ↓  ←  ↓ 
        \\ ↓  →  ↑  ←  ↑  ↓  ↓  →  ↓  ←  →  ↓ 
        \\ ↓  ↑  ↑  ↑  ↑  ↓  ↓  ↓  ←  ↑  ↑  ↓ 
        \\ →  →  ↑  ↑  ↓  ←  ↓  →  ✥  ↑  ↓  ← 
        \\ ↑  ←  ←  ↓  ←  →  →  ↑  ↑  ←  ←  ↓ 
        \\ →  →  ↑  ←  ←  ←  →  ↑  ↑  ↑  ↑  ← 
        \\
    ;
    try std.testing.expectEqualStrings(expected2, generation2.items);

    const size = maze.getWallifiedMazeSize();
    try std.testing.expectEqual(47, size.row);
    try std.testing.expectEqual(25, size.column);

    try std.testing.expectEqual(maze.getWallifiedMazeCell(0, 5).?, Cell{ .wall = {} });
    try std.testing.expectEqual(maze.getWallifiedMazeCell(46, 10).?, Cell{ .wall = {} });
}
