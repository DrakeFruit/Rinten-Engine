# Phase 0 baseline — 2026-11-22

The first trustworthy build/test/perf baseline for the port, taken before any s&box stability or performance
work. It exists so that the 490-commit porting report has something to be measured against.

- **Engine commit:** `caf11ad` (the working tree that produced these numbers is listed in
  [`baseline/2026-11-22.json`](baseline/2026-11-22.json); the Phase 0 changes themselves landed after this
  snapshot).
- **Bench set:** `BENCH_SET=core` — the engine's own fixture project, nothing external.
- **Measured:** 1,500 frames per scene after a 20 s warm-up, one timing run per scene.
- **Raw table:** `~/.cache/rinten-bench/out/phase0-2026-11-22/summary.txt`.

## Machine

| | |
| --- | --- |
| OS | CachyOS |
| Kernel | 7.3.5-2-cachyos |
| CPU | AMD Ryzen 7 7800X3D (8 cores) |
| Memory | 30 GB |
| GPU | AMD Radeon RX 9070 XT (RADV GFX1201, Navi 48) |
| Driver | RADV, Vulkan 1.4.363 |
| Session | KWin Wayland (`wayland-1`), no `gnome-shell` |
| SDK | .NET 11.0.100 |
| Runtime | .NET 11.0.0 |
| Vulkan validation | Khronos layer **not installed** |

## The core scenes

`engine/Tests/Fixtures/BenchProject` is a dev-only project in this repo. Its scenes are tiny: each has a
sky, a sun, a camera, and one component (`BenchProject.StressField` or `BenchProject.PhysicsField`) that
makes its contents at runtime. There is no checked-in geometry to drift or to download.

| Scene | Contents |
| --- | --- |
| `minimal` | Sky, sun, camera — the cost of a frame with nothing in it |
| `objects-1k` | 1,000 static cubes on a centred 32 × 32 grid, 2 m apart |
| `objects-10k` | 10,000 static cubes, 100 × 100 |
| `objects-100k` | 100,000 static cubes, 317 × 317, about 634 m across |
| `physics` | 1,000 rigid bodies with box colliders dropped onto a runtime-made floor |

## Results

| Scene | fps | frame typical (ms) | gpu frame (ms) |
| --- | ---: | ---: | ---: |
| minimal | 3156 | 0.20 | 0.19 |
| objects-1k | 4041 | 0.22 | 0.21 |
| objects-10k | 2915 | 0.31 | 0.29 |
| objects-100k | 1120 | 0.63 | 0.62 |
| physics | 2253 | 0.43 | 0.34 |

The object scenes are dominated by cull/depth/material work that grows with the count (100k: cull 0.160 ms,
depth 0.101 ms, materials 0.161 ms). **Run-to-run variance is large** for these small, GPU-idle frames —
an earlier run of the same build measured 1k/10k/100k at 2285/1450/815 fps. Treat a single session's numbers
as a snapshot; use `bench.sh ab` for anything that must be compared.

## Builds

| Step | Seconds |
| --- | ---: |
| `bench.sh tree` (fresh copy, managed build, shaders) | 43.66 |
| Managed build, warm (same tree) | 52.61 |
| Shaders | 4.05 |
| First project open (compiles `BenchProject` content) | 22.62 |

The tree build copies `game/bin` from the working tree, so its managed step is incremental. "Warm" is a
second `./build.sh managed` in the built tree; the number being larger than the tree build reflects the
R2R publish step being paid there rather than incrementally.

## Tests at this baseline

| Suite | Result |
| --- | --- |
| Unit (`Rinten.Test.Unit`) | **1,587 passed, 0 failed, 4 skipped** |
| Engine (`Rinten.Test.Engine`), full | aborts on GPU tests — see below |
| Engine, non-GPU subset | **2,317 passed, 43 failed, 9 skipped** |
| Integration (`Rinten.Test.Integration`) | **681 passed, 252 failed, 5 skipped** |

### Engine: why it aborts

Three render tests hang this machine's Vulkan path and were excluded from the completed non-GPU run:

- `ComputePassTests.APassCanLookAtAPicture`
- `DescriptorPoolTests.MoreObjectsThanTheFirstPoolHolds`
- `CustomObjectCullingTests.SomethingBehindTheCameraDoesNotDrawItself`

The render tests that do finish consistently see black output (`ABuiltQuadIsDrawn`: 0 of 65,536 pixels;
`DrawsFramesIntoAWindow` and friends fail the same way), and nine standard-surface shader stages fail to
build. That is the same pathology as the `OBJECTS` scenes producing fewer triangles than their counts would
suggest. It is an engine/render-path issue, not a harness one, and is the first thing Phase 1 should look at.

The remaining Engine failures cluster as:

- **Content not provisioned:** `game/download/assets` (materials, models, animations) and
  `game/thirdpartylegalnotices/licenses` are not in this checkout — license checks, compiled-material and
  ported-model/animation tests.
- **RintenUI revision:** the engine records submodule commit `5d91d4c`, which is not present locally; the
  checkout is at `a706b7b`. Editor layout tests are written against the recorded revision.
- **s&box install content:** `ACharactersSkinDecodes` reads a real s&box install and decodes a 4×4 texture.
- **Gizmo/paint/pick:** `AHandleWithNoPictureIsNeitherDrawnNorHit`,
  `TheDeepestThingUnderThePointerIsTheOneFound`.

### Integration: 252 failures

Two systemic causes were fixed after this snapshot: 22 filesystem tests passed a relative path to
`EngineFileSystem.Initialize`, which now requires an absolute path; and the package-ident parser rejected
local project names containing dots (`local.bench.core#local`), which stopped the Phase 0 bench project
from opening at all. The rest are broad and pre-existing: physics/joints (24 joint tests, 21 model-physics
tests, 12 character-controller, 8 player-controller), navmesh, prefabs/serialization, audio, and the web
exporter's missing `unittest/addons/spacewars/Assets`. They need their own pass; they are recorded here so
Phase 1 does not mistake them for regressions.

## Reproduce

```bash
cd engine/Tools/Profiling/Bench
BENCH_NO_COMPOSITOR=1 ./phase0.sh
```

`BENCH_NO_COMPOSITOR=1` measures in the current KWin session; without it the bench starts its own headless
GNOME compositor, which this machine does not have. The Khronos validation layer is not installed, so
`phase0.sh` skips the validated check run and records `vulkan_validation: missing` rather than claiming a
clean validation.
