#!/bin/bash
# Phase 0: the reproducible baseline. Builds a tree of this repo, times the builds, measures the
# engine's own bench project (BENCH_SET=core), and writes baseline/YYYY-MM-DD.json and .md with
# the numbers and the machine they came from.
#
#   engine/Tools/Profiling/Bench/phase0.sh
#
# Environment: BENCH_TREE (default phase0), BENCH_FRAMES (1500), BENCH_WARMUP (20),
# BENCH_LABEL (phase0-YYYY-MM-DD), BENCH_NO_COMPOSITOR (1 here - this machine has no gnome-shell).
#
# One measurement at a time, and only when the machine is quiet: bench.sh owns the GPU lock and the
# memory guard. Safe to re-run; each run gets a new label unless BENCH_LABEL is set.

set -u

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO=$(cd "$HERE/../../../.." && pwd)
BENCH_HOME=${BENCH_HOME:-$HOME/.cache/rinten-bench}

TREE=${BENCH_TREE:-phase0}
FRAMES=${BENCH_FRAMES:-1500}
WARM=${BENCH_WARMUP:-20}
DATE=$(date +%F)
LABEL=${BENCH_LABEL:-phase0-$DATE}
TREE_DIR="$BENCH_HOME/trees/$TREE"
OUT="$BENCH_HOME/out/$LABEL"
BASELINE="$HERE/baseline"
mkdir -p "$BENCH_HOME"
WORK=$(mktemp -d "$BENCH_HOME/phase0.XXXXXX")

export BENCH_SET=core
export BENCH_NO_COMPOSITOR=${BENCH_NO_COMPOSITOR:-1}

say() { printf '%s\n' "$*" >&2; }
die() { say "phase0: $*"; exit 1; }

cleanup() {
	rm -rf "$WORK"
}
trap cleanup EXIT

mkdir -p "$BASELINE"

# Seconds a command took, printed so it can be collected without /usr/bin/time's format quirks.
timed() {
	local out=$1; shift
	local start end
	start=$(date +%s.%N)
	"$@" || return 1
	end=$(date +%s.%N)
	awk -v a="$start" -v b="$end" 'BEGIN { printf "%.2f\n", b - a }' > "$out"
}

# -- conditions ----------------------------------------------------------------

commit=$(git -C "$REPO" rev-parse HEAD 2>/dev/null || echo unknown)
dirty=$(git -C "$REPO" status --short 2>/dev/null | head -50)
sdk=$(dotnet --version 2>/dev/null || echo unknown)
runtime=$(dotnet --list-runtimes 2>/dev/null | awk '/Microsoft.NETCore.App/ { print $2 }' | sort -V | tail -1)
os=$(awk -F= '/^PRETTY_NAME=/ { gsub(/"/, "", $2); print $2 }' /etc/os-release 2>/dev/null)
kernel=$(uname -r)
cpu=$(awk -F: '/model name/ { gsub(/^ +/, "", $2); print $2; exit }' /proc/cpuinfo)
cores=$(nproc)
memory=$(awk '/MemTotal/ { printf "%.0f GB", $2 / 1024 / 1024 }' /proc/meminfo)
gpu=$(lspci -nn 2>/dev/null | grep -m1 -E 'VGA compatible controller|3D controller' | sed -E 's/^[^ ]+ [^:]+: //')
driver=$(vulkaninfo --summary 2>/dev/null | awk -F= '/driverName/ { gsub(/^ +| +$/, "", $2); print $2; exit }')
wayland=${WAYLAND_DISPLAY:-unset}

# The Khronos validation layer is what -vkvalidate needs; without it a check run is a timing run with a screenshot.
if compgen -G "/usr/share/vulkan/*layer*.d/VkLayer_khronos_validation.json" >/dev/null 2>&1; then
	validation=available
else
	validation=missing
fi

# -- builds --------------------------------------------------------------------

say "phase0: build tree $TREE"
timed "$WORK/tree.txt" "$HERE/bench.sh" tree "$TREE" \
	|| die "the tree did not build - see $TREE_DIR/.bench-build.log"

[ -x "$TREE_DIR/game/Rinten" ] || die "no game binary in $TREE_DIR"

say "phase0: warm managed build"
timed "$WORK/managed.txt" bash -c "cd '$TREE_DIR' && MSBUILDDISABLENODEREUSE=1 ./build.sh managed" \
	|| die "the warm managed build failed"

say "phase0: shaders"
timed "$WORK/shaders.txt" bash -c "cd '$TREE_DIR' && ./build.sh shaders" \
	|| die "the shader build failed"

# -- runs ----------------------------------------------------------------------

# A first, short run opens the bench project and compiles its content into the bench's own copy, so
# the measured run does not pay for that inside its frames. Its wall time is the first-open time.
say "phase0: first project open (content compile)"
timed "$WORK/first-open.txt" "$HERE/bench.sh" run -t "$TREE" -l "$LABEL-warm" \
	-f 100 -w 5 --no-check minimal \
	|| die "the first run failed - see $BENCH_HOME/out/$LABEL-warm"

say "phase0: measured run ($FRAMES frames, ${WARM}s warm-up)"
"$HERE/bench.sh" run -t "$TREE" -l "$LABEL" -f "$FRAMES" -w "$WARM" --no-check \
	|| die "the measured run failed - see $OUT"

# The check run is only validation if the Khronos layer is installed. Without it, the run is another timing run
# with a screenshot, and the layer-less report says "not validated" anyway - so say so and skip the window.
if [ "$validation" = available ]; then
	say "phase0: validated check run (200 frames)"
	"$HERE/bench.sh" run -t "$TREE" -l "$LABEL-check" -f 200 -w 10 \
		|| die "the check run failed - see $BENCH_HOME/out/$LABEL-check"
	CHECK_DIR="$BENCH_HOME/out/$LABEL-check"
else
	say "phase0: no Vulkan validation layer on this machine - skipping the validated check run"
	CHECK_DIR="/nonexistent"
fi

[ -f "$OUT/summary.txt" ] || die "no summary in $OUT"

# -- baseline files ------------------------------------------------------------

export PHASE0_COMMIT="$commit"
export PHASE0_DIRTY="$dirty"
export PHASE0_SDK="$sdk"
export PHASE0_RUNTIME="$runtime"
export PHASE0_OS="$os"
export PHASE0_KERNEL="$kernel"
export PHASE0_CPU="$cpu"
export PHASE0_CORES="$cores"
export PHASE0_MEMORY="$memory"
export PHASE0_GPU="$gpu"
export PHASE0_DRIVER="$driver"
export PHASE0_VALIDATION="$validation"
export PHASE0_WAYLAND="$wayland"
export PHASE0_DATE="$DATE"
export PHASE0_LABEL="$LABEL"
export PHASE0_TREE="$TREE"
export PHASE0_FRAMES="$FRAMES"
export PHASE0_WARM="$WARM"
export PHASE0_TREE_SECONDS=$(cat "$WORK/tree.txt")
export PHASE0_MANAGED_SECONDS=$(cat "$WORK/managed.txt")
export PHASE0_SHADERS_SECONDS=$(cat "$WORK/shaders.txt")
export PHASE0_FIRST_OPEN_SECONDS=$(cat "$WORK/first-open.txt")

python3 - "$OUT" "$CHECK_DIR" "$BASELINE/$DATE.json" "$BASELINE/$DATE.md" <<'PY'
import json, os, re, sys

out_dir, check_dir, json_path, md_path = sys.argv[1:]

ZONES = [ "cull", "cull cells", "cull instances", "cull clusters", "depth", "materials", "sky", "post pass", "compose" ]

def read(path):
    try:
        with open(path) as f:
            return f.read()
    except OSError:
        return ""

def parse(path):
    text = read(path)
    if not text:
        return None

    row = {}
    m = re.search(r"(\d+) fps", text.split("\n", 1)[0])
    if m:
        row["fps"] = float(m.group(1))
    for key, pattern in (("typical_ms", r"frame typical ([\d.]+) ms"), ("gpu_ms", r"gpu frame ([\d.]+) ms")):
        m = re.search(pattern, text)
        if m:
            row[key] = float(m.group(1))

    m = re.search(r"validation (on|off), (\d+) errors, (\d+) warnings", text)
    if m:
        row["validation"] = { "on": m.group(1) == "on", "errors": int(m.group(2)), "warnings": int(m.group(3)) }

    section = text.split("the renderer's last frame", 1)
    if len(section) == 2:
        zones = {}
        for line in section[1].split("\n"):
            m = re.match(r"^\s+(\S.*?)\s+gpu\s+([\d.]+) ms", line)
            if m and m.group(1) in ZONES and m.group(1) not in zones:
                zones[m.group(1)] = float(m.group(2))
        row["zones"] = zones

    return row

scenes = {}
for name in sorted(os.listdir(out_dir)):
    if not name.endswith(".txt") or name.endswith(".check.txt") or name == "summary.txt":
        continue
    key = name[:-4]
    timing = parse(os.path.join(out_dir, name))
    if timing is None:
        continue
    check = parse(os.path.join(check_dir, name)) if os.path.isdir(check_dir) else None
    timing["check"] = None
    if check and "validation" in check:
        v = check["validation"]
        timing["check"] = "ok" if v["on"] and v["errors"] == 0 else (
            "not validated" if not v["on"] else f"FAIL {v['errors']} errors")
        timing["check_warnings"] = v["warnings"]
    scenes[key] = timing

def env(name, default=""):
    return os.environ.get(name, default)

baseline = {
    "date": env("PHASE0_DATE"),
    "label": env("PHASE0_LABEL"),
    "commit": env("PHASE0_COMMIT"),
    "dirty": [ line for line in env("PHASE0_DIRTY").splitlines() if line.strip() ],
    "machine": {
        "os": env("PHASE0_OS"),
        "kernel": env("PHASE0_KERNEL"),
        "cpu": env("PHASE0_CPU"),
        "cores": env("PHASE0_CORES"),
        "memory": env("PHASE0_MEMORY"),
        "gpu": env("PHASE0_GPU"),
        "driver": env("PHASE0_DRIVER"),
        "vulkan_validation": env("PHASE0_VALIDATION"),
        "wayland_display": env("PHASE0_WAYLAND"),
        "sdk": env("PHASE0_SDK"),
        "runtime": env("PHASE0_RUNTIME"),
    },
    "conditions": {
        "tree": env("PHASE0_TREE"),
        "bench_set": "core",
        "frames": int(env("PHASE0_FRAMES")),
        "warmup_seconds": int(env("PHASE0_WARM")),
        "compositor": "current Wayland session (BENCH_NO_COMPOSITOR=1)",
    },
    "builds_seconds": {
        "tree": float(env("PHASE0_TREE_SECONDS")),
        "managed_warm": float(env("PHASE0_MANAGED_SECONDS")),
        "shaders": float(env("PHASE0_SHADERS_SECONDS")),
        "first_project_open": float(env("PHASE0_FIRST_OPEN_SECONDS")),
    },
    "commands": {
        "tree": "BENCH_SET=core bench.sh tree " + env("PHASE0_TREE"),
        "measure": f"BENCH_SET=core bench.sh run -t {env('PHASE0_TREE')} -l {env('PHASE0_LABEL')} "
                   f"-f {env('PHASE0_FRAMES')} -w {env('PHASE0_WARM')} --no-check",
        "check": f"BENCH_SET=core bench.sh run -t {env('PHASE0_TREE')} -l {env('PHASE0_LABEL')}-check -f 200 -w 10",
    },
    "scenes": scenes,
}

with open(json_path, "w") as f:
    json.dump(baseline, f, indent=2)
    f.write("\n")

def val(row, key, digits=2):
    v = row.get(key)
    return "-" if v is None else (f"{v:.{digits}f}")

lines = [
    f"# Phase 0 baseline - {baseline['date']}",
    "",
    f"Commit `{baseline['commit']}` on tree `{baseline['conditions']['tree']}`, "
    f"{baseline['conditions']['frames']} measured frames after {baseline['conditions']['warmup_seconds']}s warm-up, "
    f"`BENCH_SET=core`. Machine, commands and per-scene numbers are in "
    f"[{os.path.basename(json_path)}]({os.path.basename(json_path)}).",
    "",
    "## Machine",
    "",
    "| | |",
    "| --- | --- |",
]
for key, label in (("os", "OS"), ("kernel", "Kernel"), ("cpu", "CPU"), ("cores", "Cores"),
                   ("memory", "Memory"), ("gpu", "GPU"), ("driver", "Driver"),
                   ("vulkan_validation", "Vulkan validation layer"), ("wayland_display", "Wayland display"), ("sdk", "SDK"), ("runtime", "Runtime")):
    lines.append(f"| {label} | {baseline['machine'][key] or '-'} |")

lines += [
    "",
    "## Builds",
    "",
    "| Step | Seconds |",
    "| --- | ---: |",
    f"| Tree (fresh copy + managed + shaders) | {baseline['builds_seconds']['tree']:.2f} |",
    f"| Managed, warm | {baseline['builds_seconds']['managed_warm']:.2f} |",
    f"| Shaders | {baseline['builds_seconds']['shaders']:.2f} |",
    f"| First project open (compiles bench content) | {baseline['builds_seconds']['first_project_open']:.2f} |",
    "",
    "## Scenes",
    "",
    "| Scene | fps | typical ms | gpu ms | validation |",
    "| --- | ---: | ---: | ---: | --- |",
]
for name, row in scenes.items():
    check = row.get("check") or "no check"
    if row.get("check_warnings"):
        check += f" ({row['check_warnings']} warnings)"
    lines.append(f"| {name} | {val(row, 'fps', 0)} | {val(row, 'typical_ms')} | {val(row, 'gpu_ms')} | {check} |")

lines += [
    "",
    "## Commands",
    "",
    "```",
    baseline["commands"]["tree"],
    baseline["commands"]["measure"],
    baseline["commands"]["check"],
    "```",
]

if baseline["dirty"]:
    lines += ["", "## Working tree when measured", "", "```"]
    lines += baseline["dirty"]
    lines += ["```", ""]

with open(md_path, "w") as f:
    f.write("\n".join(lines).rstrip() + "\n")

print(json_path)
print(md_path)
PY

say "phase0: wrote $BASELINE/$DATE.json and $BASELINE/$DATE.md"
say "phase0: table: $OUT/summary.txt"
