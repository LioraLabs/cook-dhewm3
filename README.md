# dhewm3, built with Cook

This is a fork of **[dhewm3](https://github.com/dhewm/dhewm3)** — the GPL _Doom 3_
source port — that builds the engine, its built-in tools, **and** its map assets
with the [Cook build system](https://github.com/LioraLabs/cook) via the `cook_cc`
module, instead of CMake.

It exists as a worked example of Cook on a real, large C++ codebase. The
interesting part isn't that Cook can compile Doom 3 — it's the shape of the graph:

> The engine, the compilers it *ships* (`dmap`, `runaas`), and the map/AAS assets
> those compilers *produce* all live in one DAG. `cook game` builds the binary and
> bakes every map in a single parallel, fully-cached run.

Compiling a tool and then running it are ordinary upstream and downstream nodes —
not two build systems joined by a shell script. `$<dhewm3>` inside the asset
recipe *is* the dependency: Cook knows every baked map needs the freshly-built
engine, and rebuilds exactly what a change invalidates.

> **Scope.** This Cookfile is **Linux / x86_64 only** — it hardcodes the arch and
> OS values that CMake normally probes. The upstream CMake build
> (`neo/CMakeLists.txt`, untouched here) remains the portable, official way to
> build dhewm3 on every platform. The two build systems coexist; nothing about the
> engine source was changed to accommodate Cook.

## Building

You need a C++14 compiler and the usual dhewm3 development libraries — **SDL2,
OpenAL (Soft), libcurl, zlib, and OpenGL** — plus
[Cook](https://github.com/LioraLabs/cook).

```sh
cook modules install      # fetch the cook_cc module pinned in cook.toml
cook game                 # build the engine, the base.so/d3xp.so game plugins, and bake maps
```

`cook game` produces:

- `build/bin/dhewm3` — the engine binary (engine + built-in compilers)
- `build/bin/base.so`, `build/bin/d3xp.so` — the game logic as dlopen'd plugins
- baked `*.proc` / `*.cm` / `*.aas*` assets alongside any `base/maps/*.map`

Other targets:

```sh
cook menu                 # list every recipe and chore
cook dhewm3               # just the engine binary
cook clean                # remove build/ and .cook/
```

`compile_commands.json` is regenerated automatically at the repo root on every build — there is no separate target.

## Running the game

dhewm3 needs the retail _Doom 3_ game data — **this repository contains none of
it**, and none is distributed with it. The game data remains covered by the
original _Doom 3_ EULA. You must own a copy (e.g. the
[Steam release](https://store.steampowered.com/app/208200/DOOM_3/)) patched to
1.3.1.

A helper copies your own `pak*.pk4` files into place (all `*.pk4` are git-ignored,
so game data can never be committed):

```sh
DOOM3_PAKS="/path/to/Doom 3/base" cook install-paks
./build/bin/dhewm3
```

## What Cook builds

`use cook_cc` drives the whole thing: nine engine static libraries (`idLib`,
`framework`, `cm`, `ui`, `imgui`, `renderer`, `sound`, `compilers`, `sys`), the two
game plugins (`cook_cc.shared` → `base.so`/`d3xp.so`), and the final binary
(`cook_cc.bin`). Generated configuration comes from a `config_header`
(`neo/config.h.in` → `build/dhewm3/config.h`), replacing CMake's `configure_file`.
The asset pipeline is a plain Cook `recipe` that fans out over `base/maps/*.map`,
running the just-built `dhewm3 +dmap` and `+runaas` per map.

## License and credits

**dhewm3 and the _Doom 3_ source are licensed under the GNU GPL v3** — see
[COPYING.txt](COPYING.txt). The source is also subject to **id Software's
additional terms**, and it bundles third-party code under its own licenses
(Dear ImGui, miniz, minizip, stb, and others). All of this, along with the full
upstream project documentation, credits, and homepage, is preserved verbatim in
**[README.dhewm3.md](README.dhewm3.md)** — read it; those notices must travel with
the code.

dhewm3 is a community project hosted at https://github.com/dhewm — the official
homepage is https://dhewm3.org. This fork changes only the build system; all the
credit for the engine and the port belongs upstream.

## Contributing and a note on how this was built

The **Cook build files** in this fork (`Cookfile`, `cook.toml`, `scripts/`) were
developed with AI assistance.

The **dhewm3 engine** is not this fork's to govern. Upstream dhewm3 has an explicit
policy of accepting **only human-written code** and no generative-AI contributions
(see [README.dhewm3.md](README.dhewm3.md#contributing)). Please respect it: send
engine fixes and features to [upstream dhewm3](https://github.com/dhewm/dhewm3),
human-written, under their rules. Issues specific to *this* Cook build belong here.
