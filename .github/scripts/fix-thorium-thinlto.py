import sys
from pathlib import Path

if len(sys.argv) != 2:
    raise SystemExit("Usage: fix-thorium-thinlto.py <chromium-src>")

chromium_src = Path(sys.argv[1]).resolve()
path = chromium_src / "build/config/compiler/BUILD.gn"
source = path.read_text()

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

if source.count(old_assignment) != 1:
    raise SystemExit(
        "Expected exactly one Thorium ThinLTO assignment before the Windows branch; "
        "source does not match the audited patch."
    )
source = source.replace(old_assignment, new_assignment, 1)

old_linux = """    } else if (is_linux) {
      ldflags = [ "-Wl,--lto-O" + lto_opt_level ]
"""
new_linux = """    } else if (is_linux) {
      _thorium_x86_thinlto =
          is_full_optimization_build && lto_opt_level == 2 &&
          (current_cpu == "x86" || current_cpu == "x64")
      ldflags = [ "-Wl,--lto-O" + lto_opt_level ]
"""

if source.count(old_linux) != 1:
    raise SystemExit(
        "Expected exactly one Thorium Linux ThinLTO branch; "
        "source does not match the audited patch."
    )
source = source.replace(old_linux, new_linux, 1)

expected = "is_full_optimization_build && lto_opt_level == 2"
if source.count(expected) != 2:
    raise SystemExit("ThinLTO branch validation failed.")

path.write_text(source)
print("Fixed Thorium ThinLTO temporary-variable scope for Android.")
