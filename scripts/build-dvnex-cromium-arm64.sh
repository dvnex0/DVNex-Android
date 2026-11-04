#!/usr/bin/env bash
set -Eeuo pipefail

# Experimental DVNex NEW 3 build using the pinned Cromite/Chromium source.
# Not a production release: this branch deliberately skips Cromite branding,
# Cromite's updater, and the reviewed UI patches deferred for DVNex adaptation.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORKSPACE="${WORKSPACE:-$ROOT/.dvnex-build}"
CROMITE_DIR="$WORKSPACE/cromite"
CHROMIUM_ROOT="$WORKSPACE/chromium"
CHROMIUM_SRC="$CHROMIUM_ROOT/src"
DEPOT_TOOLS="$WORKSPACE/depot_tools"
OUT_DIR="$CHROMIUM_SRC/out/dvnex-arm64"

CROMITE_REPO="https://github.com/uazo/cromite.git"
CROMITE_SHA="3724efc6ede3d2d94611c1fe71d1b090ebbb40a7"
CHROMIUM_TAG="153.0.8010.37"
APP_ID="com.browser.dvnexnew3"
APP_NAME="DVNex NEW 3"

die() { echo "ERROR: $*" >&2; exit 1; }

command -v git >/dev/null || die "Git is required."
command -v python3 >/dev/null || die "Python 3 is required."
[[ "$(uname -s)" == "Linux" ]] || die "Run this script on Linux."
[[ "$(uname -m)" == "x86_64" ]] || die "The Chromium build host must be x86_64 Linux."

mkdir -p "$WORKSPACE"
AVAILABLE_GB="$(df -BG "$WORKSPACE" | awk 'NR==2 {gsub(/G/, "", $4); print $4}')"
RAM_GB="$(awk '/^MemTotal:/ {printf "%d\n", $2 / 1024 / 1024}' /proc/meminfo)"
echo "Workspace: $WORKSPACE"
echo "Free disk: $AVAILABLE_GB GiB"
echo "RAM: $RAM_GB GiB"

if (( AVAILABLE_GB < 100 )); then
  die "At least 100 GiB of free disk is recommended before syncing Chromium."
fi
if (( RAM_GB < 8 )); then
  die "At least 8 GiB RAM is required; 16 GiB or more is strongly recommended."
fi
if (( RAM_GB < 16 )); then
  echo "WARNING: RAM below 16 GiB. Linking may fail or the build may be killed."
fi

echo "=== Install depot_tools ==="
if [[ ! -d "$DEPOT_TOOLS/.git" ]]; then
  rm -rf "$DEPOT_TOOLS"
  git clone --depth 1 https://chromium.googlesource.com/chromium/tools/depot_tools.git "$DEPOT_TOOLS"
fi
export PATH="$DEPOT_TOOLS:$PATH"
export DEPOT_TOOLS_UPDATE=0

echo "=== Checkout the pinned Cromite patch revision ==="
if [[ ! -d "$CROMITE_DIR/.git" ]]; then
  mkdir -p "$CROMITE_DIR"
  git -C "$CROMITE_DIR" init
  git -C "$CROMITE_DIR" remote add origin "$CROMITE_REPO"
fi
git -C "$CROMITE_DIR" fetch --depth=1 origin "$CROMITE_SHA"
git -C "$CROMITE_DIR" checkout --detach FETCH_HEAD
[[ "$(git -C "$CROMITE_DIR" rev-parse HEAD)" == "$CROMITE_SHA" ]] \
  || die "Cromite source revision does not match the pinned SHA."

echo "=== Fetch Chromium Android source ==="
if [[ ! -d "$CHROMIUM_SRC/.git" ]]; then
  rm -rf "$CHROMIUM_ROOT"
  mkdir -p "$CHROMIUM_ROOT"
  cd "$CHROMIUM_ROOT"
  fetch --nohooks --no-history android
fi
[[ -d "$CHROMIUM_SRC/.git" ]] || die "fetch did not create chromium/src."

echo "=== Configure Android checkout and PGO profile dependency ==="
python3 - "$CHROMIUM_ROOT/.gclient" <<'PY'
import ast
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
source = path.read_text(encoding="utf-8")
ast.parse(source)

if not re.search(r"(?m)^target_os\s*=", source):
    source += '\ntarget_os = ["android"]\n'

statement = (
    'solutions[0]["custom_vars"] = {'
    '**solutions[0].get("custom_vars", {}), '
    '"checkout_pgo_profiles": True}'
)
if "checkout_pgo_profiles" not in source:
    source += "\n" + statement + "\n"

ast.parse(source)
path.write_text(source, encoding="utf-8")
print("Configured target_os=android and checkout_pgo_profiles=True.")
PY

echo "=== Checkout the Chromium version pinned by Cromite ==="
git -C "$CHROMIUM_SRC" fetch --depth=1 --no-tags origin \
  "refs/tags/$CHROMIUM_TAG:refs/tags/$CHROMIUM_TAG"
git -C "$CHROMIUM_SRC" checkout --detach "refs/tags/$CHROMIUM_TAG"
[[ "$(git -C "$CHROMIUM_SRC" describe --tags --exact-match HEAD)" == "$CHROMIUM_TAG" ]] \
  || die "Chromium checkout is not on the expected tag."

if [[ "${SKIP_BUILD_DEPS:-0}" != "1" ]]; then
  echo "=== Install Linux dependencies for Android Chromium ==="
  "$CHROMIUM_SRC/build/install-build-deps.sh" --android --no-prompt
fi

echo "=== Sync DEPS and run Chromium hooks ==="
cd "$CHROMIUM_ROOT"
gclient sync --no-history --jobs="$(nproc)"
gclient runhooks

echo "=== Select the DVNex patch subset ==="
PATCH_LIST="$CROMITE_DIR/build/cromite_patches_list.txt"
[[ -f "$PATCH_LIST" ]] || die "Cromite patch list not found."

python3 - "$PATCH_LIST" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
skip = {
    "Cromite-Branding.patch",
    "Cromite-Branding--improve-settings-ui.patch",
    "Bromite-auto-updater.patch",
    "Android-Toolbar-Scroll-Ablation-setting.patch",
    "Restore-adaptive-button-in-top-toolbar-customization.patch",
    "Use-list-mode-for-tab-switcher.patch",
    "Move-navigation-bar-to-bottom.patch",
    "Add-option-to-force-tablet-UI.patch",
    "Always-open-browser-controls-in-new-tab.patch",
}
lines = path.read_text(encoding="utf-8").splitlines()
kept, removed = [], []
for line in lines:
    if line.strip() in skip:
        removed.append(line.strip())
    else:
        kept.append(line)
path.write_text("\n".join(kept) + "\n", encoding="utf-8")
print("Deferred patches:")
for name in removed:
    print("  - " + name)
print(f"Remaining patch-list lines: {len(kept)}")
PY

echo "=== Prepare the upstream patch applicator ==="
PATCH_APPLIER="$CROMITE_DIR/tools/images/cromite-source/apply-cromite-patches.sh"
[[ -f "$PATCH_APPLIER" ]] || die "Cromite patch applicator not found."
python3 - "$PATCH_APPLIER" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
source = path.read_text(encoding="utf-8")
source = source.replace("sudo apt install sed\n", "")
path.write_text(source, encoding="utf-8")
PY

if [[ -f "$WORKSPACE/.dvnex-patches-applied" ]]; then
  echo "Patch marker found; not applying the patch series twice."
else
  cd "$WORKSPACE"
  if ! bash "$PATCH_APPLIER"; then
    echo "Patch application failed. Do not rerun against this partial tree." >&2
    echo "After inspecting the first failing patch, remove: $WORKSPACE" >&2
    exit 1
  fi
  touch "$WORKSPACE/.dvnex-patches-applied"
fi

echo "=== Apply DVNex package ID, app label and GN arguments ==="
python3 - "$CHROMIUM_SRC" "$CROMITE_DIR/build/cromite.gn_args" "$APP_ID" "$APP_NAME" <<'PY'
import re
import sys
from pathlib import Path

src = Path(sys.argv[1])
gn_source = Path(sys.argv[2])
app_id = sys.argv[3]
app_name = sys.argv[4]

text = gn_source.read_text(encoding="utf-8")
text, count = re.subn(
    r'(?m)^(\s*chrome_public_manifest_package\s*=\s*)"[^"]+"',
    lambda m: m.group(1) + '"' + app_id + '"',
    text,
    count=1,
)
if count != 1:
    raise SystemExit("Expected exactly one chrome_public_manifest_package assignment.")

# This GN arg is declared by Cromite-Branding.patch, which is skipped here.
text = re.sub(r"(?m)^\s*cromite_pref_hash_seed_bin\s*=.*\n", "", text)

out_dir = src / "out" / "dvnex-arm64"
out_dir.mkdir(parents=True, exist_ok=True)
(out_dir / "args.gn").write_text(
    'target_os = "android"\n'
    'target_cpu = "arm64"\n'
    + text
    + '\n# DVNex development-build overrides.\n'
      'is_debug = false\n'
      'is_official_build = false\n'
      'symbol_level = 0\n'
      'blink_symbol_level = 0\n'
      'v8_symbol_level = 0\n'
      'chrome_pgo_phase = 0\n'
      'treat_warnings_as_errors = false\n'
      'android_static_analysis = "off"\n',
    encoding="utf-8",
)
print(f"Generated {out_dir / 'args.gn'} for {app_id}.")

strings = src / "chrome/android/java/res_chromium_base/values/channel_constants.xml"
if not strings.is_file():
    raise SystemExit(f"Chromium string resource is missing: {strings}")
xml = strings.read_text(encoding="utf-8")
updates = {
    "app_name": app_name,
    "bookmark_widget_title": app_name + " bookmarks",
    "search_widget_title": app_name + " search",
    "quick_action_search_widget_title": app_name + " quick action search",
}
for key, value in updates.items():
    pattern = rf'(<string name="{re.escape(key)}"[^>]*>)[^<]*(</string>)'
    xml, count = re.subn(pattern, lambda m: m.group(1) + value + m.group(2), xml, count=1)
    if count != 1:
        raise SystemExit(f"Expected one string resource named {key}; found {count}.")
strings.write_text(xml, encoding="utf-8")

manifest = src / "chrome/android/java/AndroidManifest.xml"
manifest_text = manifest.read_text(encoding="utf-8")
if '@string/app_name' not in manifest_text:
    raise SystemExit("Manifest no longer uses @string/app_name; inspect branding before building.")
if 'android:label="Cromite"' in manifest_text:
    raise SystemExit("Unexpected hard-coded Cromite application label in AndroidManifest.xml.")
print("Applied the DVNex label and verified the resource-based manifest label.")
PY

echo "=== Generate GN build files ==="
cd "$CHROMIUM_SRC"
gn gen "$OUT_DIR"

CPU_COUNT="$(nproc)"
SAFE_JOBS=$((RAM_GB / 2))
(( SAFE_JOBS < 1 )) && SAFE_JOBS=1
(( SAFE_JOBS > CPU_COUNT )) && SAFE_JOBS="$CPU_COUNT"
JOBS="${JOBS:-$SAFE_JOBS}"
echo "=== Compile Chromium browser APK with $JOBS jobs ==="
autoninja -C "$OUT_DIR" -j "$JOBS" chrome_public_apk

echo "=== Verify APK output ==="
APK="$(find "$OUT_DIR" -type f -name 'ChromePublic.apk' -print -quit)"
if [[ -z "$APK" ]]; then
  APK="$(find "$OUT_DIR" -type f -name '*.apk' -print -quit)"
fi
[[ -n "$APK" ]] || die "Build ended without an APK in $OUT_DIR."
echo "APK: $APK"
ls -lh "$APK"
sha256sum "$APK"

if [[ "${INSTALL:-0}" == "1" ]]; then
  command -v adb >/dev/null || die "adb is not installed."
  adb install -r "$APK"
fi

echo "BUILD SUCCESS"
