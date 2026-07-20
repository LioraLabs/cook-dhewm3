# dhewm3, built with cook

> **The engine, the compilers it ships, and the maps they bake: one graph,
> one cache.**

This is a fork of [dhewm3](https://github.com/dhewm/dhewm3), the GPL _Doom 3_
source port, with its build described in
[cook](https://github.com/LioraLabs/cook) through the `cook_cc` module. The
upstream CMake build (`neo/CMakeLists.txt`) stays in-tree, untouched, so the
two descriptions of the same build can be read side by side.

This is cook building **Doom 3**: id Tech 4, nine engine libraries, two
game plugins, a generated config header, and 429 nodes of dependency graph
described in one readable file. And the best part is not the C++. Doom 3
ships its own compilers: `dmap` bakes map geometry into `.proc`/`.cm`
files, `runaas` bakes AI navigation, and both live *inside* the engine
binary. Upstream, running them is something you do by hand, in the game
console, after the build, remembering yourself when a change made it
necessary. Here they are ordinary nodes in the build graph, expressed with
a mechanism no other build tool has.

## First pull, no game data

```sh
cook modules install
cook game
```

That works on a machine that has never seen Doom 3. It compiles the engine,
builds the `base.so` / `d3xp.so` game plugins, and then uses the engine it
just built to bake the repo's demo map: `dmap` produces `cookbox.proc` and
`cookbox.cm`, `runaas` produces the three AAS navigation files. No retail
`.pk4` data is required to *build* anything; retail files are only needed to
*play*.

The bake runs on a tiny, fully free base authored in this repo: a box room
(`base/maps/cookbox.map`), three materials, two engine-script stubs, and a
set of AAS hull definitions. About 150 lines of text, and the entire asset
pipeline demonstrably works on first pull.

## dmap is a compiler, and cook treats it like one

The entire asset pipeline is this recipe:

```
recipe maps
    ingredients "base/maps/*.map"

    cook "base/maps/$<in.stem>.proc" "base/maps/$<in.stem>.cm" {
        $<dhewm3> +set fs_basepath . +set fs_savepath . +set r_fullscreen 0 +dmap $<in.stem> +quit
    }

    cook "base/maps/$<in.stem>.aas48"
         "base/maps/$<in.stem>.aas96"
         "base/maps/$<in.stem>.aas120" {
        $<dhewm3> +set fs_basepath . +set fs_savepath . +set r_fullscreen 0 +runaas $<in.stem> +quit
    } nondet
```

Two mechanisms carry it.

**`$<dhewm3>` is a cross-recipe reference.** It expands to the engine
recipe's output path *and* records the dependency edge, so "the tool that
bakes this map" is an input like any other, keyed by the binary's
**content**. That one sigil replaces the Makefile glue, the "now re-run
dmap" step, and the judgment call about whether you needed to. Edit a
comment in the renderer and the recompiled object comes out byte-identical,
so the archive, the link, and every baked map stay cached. Make a real
change and the build output narrates the whole chain, each line naming the
artifact that pulled it in:

```text
renderer/RenderSystem.o   rebuild (input changed: neo/renderer/RenderSystem.cpp)
renderer/librenderer.a    rebuild (input changed: build/obj/renderer/RenderSystem.o)
dhewm3/build/bin/dhewm3   rebuild (input changed: build/lib/librenderer.a)
maps/cookbox.proc         rebuild (input changed: build/bin/dhewm3)
maps/cookbox.aas48        rebuild (input changed: build/bin/dhewm3)
```

And no false rebakes, because the edge keys on what the binary contains,
not on when it was linked.

**`$<in.stem>` fans the step out.** One unit per `.map` file, parallel,
each cached under its own key. Drop a second map into `base/maps/` and it
becomes two more units; edit one map and exactly its own units rebake.
There is no loop to write and no stamp files to manage; the shape of the
outputs tells cook the shape of the work.

> **Source invalidation does not have to become artifact invalidation.**
> The set of things worth rebuilding is the set of things that consume the
> changed bytes, and a compiler you built five seconds ago is one of those
> things like any other.

## The two build descriptions

Upstream, building this repository *and its assets* means: install the
development libraries, configure and build with CMake, acquire game data,
launch the game, and bake each map by typing `dmap` and `runaas` into the
console, re-running them whenever the map or the engine changes. The build
description is `neo/CMakeLists.txt`: 1,456 lines of imperative
configuration, and it ends at the binary. Assets are not its problem.

Here, the whole thing is:

```sh
cook modules install
cook game
```

backed by a 283-line [`Cookfile`](Cookfile) you can read top to bottom:
engine libraries, game plugins, generated config header, and the asset
pipeline included.

That comparison carries its caveat: the CMakeLists is portable across every
platform dhewm3 supports, and this Cookfile deliberately is not (see scope,
below). The point is not the line count. One file declares artifacts and
lets the graph do the work; the other scripts a configure step, and
everything downstream of the binary stays manual.

## What cook builds

`use cook_cc` drives the whole thing: nine engine static libraries
(`idLib`, `framework`, `cm`, `ui`, `imgui`, `renderer`, `sound`,
`compilers`, `sys`), the two game plugins (`cook_cc.shared` →
`base.so` / `d3xp.so`), and the final binary (`cook_cc.bin`). Generated
configuration comes from a `config_header` (`neo/config.h.in` →
`build/dhewm3/config.h`), replacing CMake's `configure_file`. Compile flags
mirror upstream's defaults (`-g -ggdb -O2`), so both descriptions produce
comparable builds of the same engine.

You need a C++14 compiler, the usual dhewm3 development libraries (SDL2,
OpenAL Soft, libcurl, zlib, OpenGL), and
[cook](https://github.com/LioraLabs/cook). Useful targets:

```sh
cook menu               # every recipe and chore
cook dag                # browse all 429 nodes of the graph in a TUI
cook dhewm3             # just the engine binary
cook maps               # just the asset bake
cook why maps           # every determinant behind the bake, hit or miss
cook cache verify maps  # re-run the bake, compare bytes
cook clean              # remove build/ and .cook/
```

## Running the game

dhewm3 needs the retail _Doom 3_ game data: **this repository contains
none of it**, and none is distributed with it. The game data remains
covered by the original _Doom 3_ EULA. You must own a copy (e.g. the
[Steam release](https://store.steampowered.com/app/208200/DOOM_3/))
patched to 1.3.1.

A helper copies your own `pak*.pk4` files into place (all `*.pk4` are
git-ignored, so game data can never be committed):

```sh
DOOM3_PAKS="/path/to/Doom 3/base" cook install-paks
./build/bin/dhewm3
```

With retail data installed, `map cookbox` loads the demo room.

## Scope, honestly

* **Linux / x86_64 only.** The Cookfile hardcodes what CMake probes.
  Upstream CMake remains the portable, official build; nothing about the
  engine source was changed for cook.
* The demo map is a build-pipeline demo, not a level: one lit white room,
  AAS hulls flooded from the player start.

## License and credits

**dhewm3 and the _Doom 3_ source are licensed under the GNU GPL v3**; see
[COPYING.txt](COPYING.txt). The source is also subject to **id Software's
additional terms**, and it bundles third-party code under its own licenses
(Dear ImGui, miniz, minizip, stb, and others). All of this, along with the
full upstream project documentation, credits, and homepage, is preserved
verbatim in **[README.dhewm3.md](README.dhewm3.md)**. Read it; those
notices must travel with the code.

dhewm3 is a community project hosted at https://github.com/dhewm; the
official homepage is https://dhewm3.org. This fork changes only the build
description; all the credit for the engine and the port belongs upstream.

## Contributing and a note on how this was built

The cook build files in this fork (`Cookfile`, `cook.toml`, `base/`'s free
demo content, `scripts/`) were developed with AI assistance, as a
dogfooding exercise for `cook_cc`.

The dhewm3 engine is not this fork's to govern. Upstream dhewm3 has an
explicit policy of accepting **only human-written code** and no
generative-AI contributions (see
[README.dhewm3.md](README.dhewm3.md#contributing)). Please respect it: send
engine fixes and features to
[upstream dhewm3](https://github.com/dhewm/dhewm3), human-written, under
their rules. Issues specific to *this* cook build belong here.
