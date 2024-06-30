**amazig** is a non-allocating library for generating perfect mazes for games and puzzles, using the 
Origin Shift algorithm. A perfect maze is one where you can pick any pair of positions and 
be guaranteed that these two positions are joined by a unique path. Such a maze
is a minimum spanning tree, and it is thus free of loops and isolated areas.
You can still add such features using the generated maze as the starting point.

<img width="300" alt="image" src="https://github.com/user-attachments/assets/bb56d5de-80f0-4478-9aa0-9caf297fc1f2" />

## The Origin Shift algorithm
The Origin Shift algorithm was discussed in a January 2024 video by [CaptainLuma](https://www.youtube.com/watch?v=zbXKcDVV4G0), and
turns out to be a rediscovery of an algorithm described in a 1988 [paper](https://people.eecs.berkeley.edu/~ananth/1987-1989/MC_TreeTheorem.pdf)
on Markov chains by V. Anantharam. It's been noted that Origin Shift is essentially the Aldous-Broder algorithm in reverse.

The key property of Origin Shift is that the starting point is an already perfect maze, and every iteration produces a new perfect maze.
During the maze generation, we thus never have to ask if the maze is complete - it always is! However, since we usually start with a trivial
maze we still run the algorithm steps quite a few times to make the maze look good.

### Seeding the maze
The fact that a perfect maze generator requires a perfect maze to begin with might be the reason
why it took so long for someone to consider this approach. However, a baseline perfect maze is trivial 
to contruct programmatically, regardless of size.

The initial maze is by convention one with the origin at the lower-right corner. Every
node points to its right neighbor, except for the last one on each row, which points to
its neighbor below.

For a 25 by 12 maze, the initial state looks like this:
``` 
 →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  ↓
 →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  ↓
 →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  ↓
 →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  ↓
 →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  ↓
 →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  ↓
 →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  ↓
 →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  ↓
 →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  ↓
 →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  ↓
 →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  ↓
 →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  →  O
```

*Any initial perfect maze will do, and in some cases it may make sense to start off
with a pre-selected perfect maze, and then perhaps mutate it per some rules. This can
lead to some fun game ideas.*

You should be able to convince yourself that wherever you start navigating in this maze,
you'll end up at the origin. The simple maze mutation algorithm below maintains
this property no matter how often you iterate:

* Point the current origin to a neighbor in any random direction
* Make the selected neighbor point to nothing, thus also making it the new origin

The direction can be picked by any means, but a good PRNG is usually used.

After a number of iterations, the maze paths may look something like this:

```
 →  ↓  ←  ↓  ↓  ←  ↓  ←  ←  ↓  →  →  ↓  ←  ←  →  →  ↓  →  ↓  ←  ←  ←  ←  ←
 ↓  →  ↓  →  ↓  ↓  ↓  ↑  →  →  ↓  ↑  ↓  ←  ↓  ↑  ←  ↓  ↓  ↓  ↑  ↑  ←  ↑  ←
 →  ↑  ↓  →  →  →  →  ↓  ↑  ←  →  ↑  →  →  ↓  ↑  ↑  ↓  ←  ←  ←  ↓  ↑  ←  ↑
 →  ↓  →  →  →  ↑  ↑  →  ↓  →  ↓  ↓  ←  →  →  ↑  →  ↓  ←  ←  ↓  ←  ↑  ↑  ↑
 ↑  ↓  →  →  ↑  ↓  →  ↑  O  ↑  →  ↓  ↑  ←  ←  ←  ↓  ←  ↓  ↑  ←  ←  →  ↑  ←
 ↑  →  ↓  ↑  ↑  ←  →  ↑  ↑  ←  ←  ←  →  ↑  ←  →  →  →  ↓  ←  ↑  →  ↑  ↑  ←
 ↑  ↑  ↓  →  →  ↑  ←  ←  ↑  →  ↓  ↑  →  ↑  ←  ←  ←  ←  ←  ↓  →  →  →  ↑  ↑
 ↑  ↓  ←  ↑  ↑  ↓  ←  ←  ↑  ↓  ↓  ↑  ↑  ←  ↓  ↑  →  ↑  ←  ↓  ↑  ↓  ↑  →  ↑
 ↑  →  →  ↑  ←  ↓  ←  ←  ↑  ←  →  ↓  ↑  ←  →  ↑  ↓  ↓  ←  →  →  →  →  ↑  ←
 →  →  ↑  ↓  →  ↓  →  ↓  ↓  ↑  ↓  →  ↓  ↑  →  ↑  →  ↓  →  ↑  →  ↓  ↑  ↑  ↓
 ↑  →  ↑  ←  ←  ←  ←  ←  ←  ↑  ↓  ↓  →  ↑  ←  ←  →  →  ↑  ↑  ←  →  →  ↑  ←
 →  ↑  ↑  ↑  ←  ←  ←  ←  ↑  ↑  ←  →  ↑  →  ↑  ←  ↑  ↑  ←  ←  ↑  ←  ←  ←  ←
```

Pick any arrow at random and follow the path. You'll eventually end up at the origin.

Note that we're generating the *paths* here, not the walls. The library does, however,
offer a "wallified API" to make it easy to render mazes for games and puzzles.

Origin Shift is not the most time-efficient maze generator, though for typical maze sizes used in
games and puzzles this is unlikely to be an issue. For mazes that don't change at runtime, you can also pre-generate
the maze either through tooling or at compile-time.

Origin Shift is a simple algorithm which allows for mazes to mutate at runtime.
This might be handy in certain games and puzzles.

Moreover, the generated maze have directed edges for every single position already pointing towards the
origin, which may represent an exit or a final destination on a level (or you can completely ignore the origin after maze generation)

### Representation in memory
The maze is represented as a simple row-major u32 slice of size `rows * columns` where each item is the offset to
the neighbor it points to. This is all the memory ever needed by the library, and the buffer is provided by the library user.

If needed, you can convert this representation into whatever suits your project.

## Using the library
The library requires Zig 0.13 or Zig master (last tested on version `0.14.0-dev.2628+5b5c60f43`)

Use `zig fetch --save <url>` to update your zon file. Alternatively, just copy `lib-amazig.zig` to your
project, as it's self-contained.

A simple example is included which animates the generation. Simply run `zig build run`. This example also shows how
to use the wallified API, which makes it trivial to draw the walls and paths without additional memory.

The library does not allocate, so it's up to you to provide a backing buffer for the maze paths. This can
be heap allocated or a static buffer.

To generate a new maze, call `init`. Supply a random number generator of your choice, the number of rows and columns,
and optionally the initial number of iterations. If this is null, then a heuristic default is used. If you supply 0 iterations, then you
can can call `iterate` or `iterateOnce` yourself any number of times.
