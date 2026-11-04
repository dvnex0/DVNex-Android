
import sys
from pathlib import Path

if len(sys.argv) != 2:
    raise SystemExit("Usage: fix-thorium-thinlto.py <chromium-src>")

chromium_src = Path(sys.argv[1]).resolve()
path = chromium_src / "build/config/compiler/BUILD.gn"

if not path.is_file():
    raise SystemExit(f"Chromium GN file not found: {path}")

source = path.read_text()

# Restrict all modifications to thinlto_optimize_max.
config_marker = 'config("thinlto_optimize_max") {'
end_marker = "# This provides the basic options to select the target CPU and ABI."

if source.count(config_marker) != 1:
    raise SystemExit("Expected exactly one thinlto_optimize_max configuration.")

start = source.index(config_marker)
end = source.find(end_marker, start)

if end == -1:
    raise SystemExit("Could not locate the end of thinlto_optimize_max.")

block = source[start:end]

old_assignment = """    _thorium_x86_thinlto =
        is_full_optimization_build && lto_opt_level == 2 &&
        (is_win || is_linux) && (current_cpu == "x86" || current_cpu == "x64")

    if (is_win) {
"""

new_assignment = """    if (is_win) {
      _thorium_x86_thinlto =
          is_full_optimization_build && lto_opt_level == 2 &&
          (current_cpu == "x86" || current_cpu == "x64")
"""

old_linux = """    } else if (is_linux) {
      ldflags = [ "-Wl,--lto-O" + lto_opt_level ]
"""

new_linux = """    } else if (is_linux) {
      _thorium_x86_thinlto =
          is_full_optimization_build && lto_opt_level == 2 &&
          (current_cpu == "x86" || current_cpu == "x64")
      ldflags = [ "-Wl,--lto-O" + lto_opt_level ]
"""

if old_assignment in block:
    if block.count(old_assignment) != 1:
        raise SystemExit(
            "Expected exactly one ThinLTO assignment inside thinlto_optimize_max."
        )
    block = block.replace(old_assignment, new_assignment, 1)
elif block.count(new_assignment) != 1:
    raise SystemExit(
        "ThinLTO Windows branch is neither original nor already patched."
    )


if old_linux in block:
    if block.count(old_linux) != 1:
        raise SystemExit(
            "Expected exactly one Linux ThinLTO branch inside thinlto_optimize_max."
        )
    block = block.replace(old_linux, new_linux, 1)
elif block.count(new_linux) != 1:
    raise SystemExit(
        "ThinLTO Linux branch is neither original nor already patched."
    )

expected = "is_full_optimization_build && lto_opt_level == 2"

if block.count(expected) != 2:
    raise SystemExit("ThinLTO branch validation failed.")

if block.count("_thorium_x86_thinlto =") != 2:
    raise SystemExit("ThinLTO variable scope validation failed.")

# Preserve all other GN configurations unchanged.
source = source[:start] + block + source[end:]

path.write_text(source)

print("Fixed Thorium ThinLTO variable scope for Android.")
