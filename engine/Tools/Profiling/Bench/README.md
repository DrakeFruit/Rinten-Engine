# The bench

The engine's measuring bench: the same scenes, the same way, one command. It builds a tree of its
own (so a measurement never runs in the build somebody is editing), takes the GPU lock, waits for
memory and an idle machine, runs each scene once for timing and once under the Vulkan validation
layers, and draws a table.

This directory holds three things:

- `bench.sh` - build a tree, run scenes, compare two runs.
- `scenes.sh` - the scene sets, sourced by `bench.sh`.
- `phase0.sh` - the reproducible baseline: builds, times the builds, runs the core set, and writes
  `baseline/YYYY-MM-DD.json` and `.md`.

## Quick start

```bash
cd engine/Tools/Profiling/Bench

# The engine's own fixture project - no other project or assets needed.
BENCH_SET=core ./bench.sh tree phase0
BENCH_SET=core ./bench.sh run -t phase0 -l first -f 1500 -w 20

# The whole Phase 0 baseline, including build timings and the committed files.
./phase0.sh
```

`BENCH_SET=core` measures `engine/Tests/Fixtures/BenchProject`: five scenes whose contents are made
at runtime by `BenchProject.StressField` (1k, 10k and 100k static cubes) and `BenchProject.PhysicsField`
(1000 rigid bodies on a floor). Nothing outside this repo is required, so the numbers reproduce on
any clone.

Without `BENCH_SET` the default set comes from `scenes.sh`, which points at external projects
(`BENCH_MY_PROJECT` and friends). Override those paths in the environment.

## The compositor

By default the bench starts its own headless GNOME compositor on `BENCH_DISPLAY` (default
`rinten-rp`), so a measured window is never on the desktop. That needs `gnome-shell`.

Where `gnome-shell` is not installed - a plain KWin session, for instance - the run can use the
session it is already in:

```bash
BENCH_NO_COMPOSITOR=1 ./bench.sh run -t phase0 -l local
```

A fullscreen measured window then sits on the desktop for the length of the run. `BENCH_WAYLAND_DISPLAY`
picks the display socket; it defaults to `WAYLAND_DISPLAY`.

## Reading the output

Each run goes to `$BENCH_HOME/out/<label>/` (default `~/.cache/rinten-bench/out`):

- `NAME.txt` - the perf report, parsed by BenchReport.
- `NAME.check.txt` / `.check.ppm` - the validated run and the window it photographed.
- `NAME.run` - exit code, other Rinten processes, tree and convars.
- `summary.txt` - the table printed at the end.

Compare two runs side by side, pictures included:

```bash
./bench.sh compare ~/.cache/rinten-bench/out/A ~/.cache/rinten-bench/out/B
```

A/B interleave two trees or convar sets, so drift affects both equally:

```bash
./bench.sh ab phase0 phase0@\"r_shadows 0\" -r 3
```

## Rules the script keeps for you

- One measurement at a time, under `$BENCH_GPU_LOCK` (default `~/.cache/rinten-perf/gpu.lock`).
- Nothing starts with less than 6-7 GB of memory free.
- `BENCH_LIMIT` (default 300 s) stops a run that will not finish.
- The tree's saved convars and video settings are deleted before every run.
- Only the process it started is killed.

Do not run two GPU measurements at once, and do not run one while playing a game.

## BenchmarkDotNet

The scene, component and physics microbenchmarks live in `engine/Benchmark`:

```bash
cd engine/Benchmark
dotnet run -c Release -- scene         # GameObjects: create, destroy, clone, walk, transform
dotnet run -c Release -- components    # components, tags, connections
RINTEN_ENGINE=$PWD/../../game dotnet run -c Release -- physics   # bodies and world step
```

`BenchmarkDotNet.Artifacts/` is gitignored.

## The baseline

`baseline/YYYY-MM-DD.json` and `.md` are written by `phase0.sh`: commit, SDK, GPU, driver, kernel,
build times, and per-scene fps, frame times and validation state. `BASELINE.md` is the prose version
- what the machine was, what the numbers mean, and which failures were known when it was taken.
