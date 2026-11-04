#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="${GITHUB_WORKSPACE:-$(pwd)}"
THOR_DIR="$ROOT/thorium"
CR_DIR="$ROOT/chromium/src"
DEPOT_TOOLS_DIR="$ROOT/depot_tools"
export THOR_DIR CR_DIR DEPOT_TOOLS_DIR
THORIUM_CHROMIUM_TAG="150.0.7871.129"

cd "$ROOT"

echo "=== Free runner disk space ==="
sudo rm -rf /usr/share/dotnet
sudo rm -rf /usr/local/lib/android
sudo rm -rf /opt/ghc
sudo rm -rf /usr/local/share/boost
sudo rm -rf /usr/local/.ghcup
sudo apt-get clean
df -h /

echo "=== Check basic build prerequisites ==="
if ! command -v git >/dev/null 2>&1 \
  || ! command -v python3 >/dev/null 2>&1 \
  || ! command -v curl >/dev/null 2>&1 \
  || ! python3 -m pip --version >/dev/null 2>&1 \
  || ! python3 -m venv --help >/dev/null 2>&1; then
  echo "A required base tool is missing; installing prerequisites."
  sudo apt-get update
  sudo apt-get install -y git python3 python3-venv python3-pip curl
else
  echo "Git, Python, pip, venv and curl are already available; skipping redundant apt update/install."
fi
python3 --version

echo "=== Restore or clone depot_tools ==="
if [ -d "$DEPOT_TOOLS_DIR/.git" ]; then
  echo "Reusing existing depot_tools checkout in the runner workspace."
else
  rm -rf "$DEPOT_TOOLS_DIR"
  git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git "$DEPOT_TOOLS_DIR"
fi
export PATH="$DEPOT_TOOLS_DIR:$PATH"
export DEPOT_TOOLS_UPDATE=0
"$DEPOT_TOOLS_DIR/ensure_bootstrap"
test -s "$DEPOT_TOOLS_DIR/python3_bin_reldir.txt"
python3 --version

echo "=== Restore or clone pinned Thorium M150 source ==="
if [ -d "$THOR_DIR/.git" ]; then
  echo "Reusing existing Thorium checkout in the runner workspace."
else
  rm -rf "$THOR_DIR"
  git clone --branch M150 --single-branch https://github.com/Alex313031/thorium.git "$THOR_DIR"
fi
git -C "$THOR_DIR" checkout a212fdaa6b9de74d08e68390137cf08d8e41017a
git -C "$THOR_DIR" submodule update --init --recursive

echo "=== Optimize Thorium dependency sync for pinned Android build ==="
python3 - "$THOR_DIR/version.py" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
source = path.read_text()

old = '''            "--with_branch_heads",
            "--with_tags",
'''
new = '''            "--no-history",
'''

if source.count(old) == 1:
    source = source.replace(old, new, 1)
elif source.count(new) == 1:
    print("Shallow DEPS sync arguments were already applied.")
else:
    raise SystemExit(
        "Could not safely locate the pinned Thorium gclient sync arguments."
    )

path.write_text(source)
print("Removed unnecessary branch-head/tag downloads; enabled shallow DEPS sync.")
PY

echo "=== Preflight pinned Thorium build configuration ==="
python3 -m py_compile "$THOR_DIR/version.py" "$THOR_DIR/setup.py" "$THOR_DIR/build.py"
test -s "$THOR_DIR/arm/android/arm64_args.gn"
python3 "$THOR_DIR/build.py" --help > /tmp/dvnex-build-help.txt
grep -q -- "--expect-os" /tmp/dvnex-build-help.txt
grep -q -- "--expect-cpu" /tmp/dvnex-build-help.txt
python3 "$THOR_DIR/setup.py" --help > /tmp/dvnex-setup-help.txt
grep -q -- "--android" /tmp/dvnex-setup-help.txt

python3 - "$THOR_DIR/version.py" "$THORIUM_CHROMIUM_TAG" <<'PY'
import re
import sys
from pathlib import Path

version_source = Path(sys.argv[1]).read_text()
expected_tag = sys.argv[2]
match = re.search(
    r'^THORIUM_VERSION\s*=\s*"([^"]+)"',
    version_source,
    re.MULTILINE,
)
if not match or match.group(1) != expected_tag:
    actual = match.group(1) if match else "not found"
    raise SystemExit(
        f"Thorium version mismatch: expected {expected_tag}, found {actual}"
    )
print(f"Verified Thorium Chromium tag: {expected_tag}")
PY

git ls-remote --exit-code --refs https://chromium.googlesource.com/chromium/src.git \
  "refs/tags/$THORIUM_CHROMIUM_TAG"

echo "=== Restore or fetch Chromium source without full Git history ==="
mkdir -p "$(dirname "$CR_DIR")"
if [ -d "$CR_DIR/.git" ]; then
  echo "Reusing existing Chromium checkout in the runner workspace."
else
  rm -rf "$CR_DIR"
  cd "$(dirname "$CR_DIR")"
  fetch --nohooks --no-history chromium
fi

echo "=== Configure Chromium checkout for Android ==="
cd "$ROOT"
python3 "$ROOT/.github/scripts/configure-chromium.py"
git -C "$CR_DIR" fetch --depth=1 --no-tags origin \
  "refs/tags/${THORIUM_CHROMIUM_TAG}:refs/tags/${THORIUM_CHROMIUM_TAG}"
git -C "$CR_DIR" show-ref --verify --quiet "refs/tags/${THORIUM_CHROMIUM_TAG}"

echo "=== Install Chromium Linux build dependencies ==="
cd "$CR_DIR"
./build/install-build-deps.sh --arm --chromeos-fonts

run_version_sync_with_retry() {
  local attempt=1
  local max_attempts=4
  local wait_seconds=60
  local log_file="/tmp/dvnex-thorium-version-sync.log"
  local status=1

  while (( attempt <= max_attempts )); do
    echo "=== Thorium dependency sync: attempt ${attempt}/${max_attempts} ==="

    if python3 "$THOR_DIR/version.py" >"$log_file" 2>&1; then
      cat "$log_file"
      return 0
    else
      status=$?
      cat "$log_file"
    fi

    if ! grep -Eqi \
      'HTTP 429|HTTP 5[0-9][0-9]|RPC failed|Connection reset|temporarily unavailable|early EOF' \
      "$log_file"; then
      echo "Thorium sync failed for a non-transient reason; not retrying." >&2
      return "$status"
    fi

    if (( attempt == max_attempts )); then
      echo "Thorium sync still failing after ${max_attempts} attempts." >&2
      return "$status"
    fi

    echo "Temporary Git/network failure detected; retrying in ${wait_seconds}s..."
    sleep "$wait_seconds"
    attempt=$((attempt + 1))
    wait_seconds=$((wait_seconds * 2))
  done

  return "$status"
}

echo "=== Pin Chromium revision and download Android dependencies ==="
VERSION_SYNC_MARKER="$THOR_DIR/.dvnex-version-sync.done"
if [ -f "$VERSION_SYNC_MARKER" ]; then
  echo "Chromium DEPS sync already completed; preserving the existing build tree."
else
  cd "$THOR_DIR"
  run_version_sync_with_retry
  touch "$VERSION_SYNC_MARKER"
fi
df -h /

echo "=== Apply Thorium Android patches and resources ==="
SETUP_MARKER="$THOR_DIR/.dvnex-android-setup.done"
if [ -f "$SETUP_MARKER" ]; then
  echo "Thorium Android overlay and patch setup already completed; reusing it."
else
  cd "$THOR_DIR"
  python3 setup.py --android
  touch "$SETUP_MARKER"
fi

echo "=== Remove obsolete launcher resources excluded by Thorium branding ==="
python3 - "$CR_DIR" <<'PY'
import sys
from pathlib import Path

chromium = Path(sys.argv[1]).resolve()
launcher = chromium / "chrome/android/java/res_base/drawable/ic_launcher_round.xml"

if not launcher.is_file():
    raise SystemExit(f"Expected patched Android launcher XML is missing: {launcher}")

launcher_source = launcher.read_text()
legacy_references = (
    "@mipmap/layered_app_icon_background",
    "@mipmap/layered_app_icon_foreground",
)
if any(reference in launcher_source for reference in legacy_references):
    raise SystemExit(
        "Refusing to remove legacy launcher resources: the patched launcher "
        "still references them."
    )

obsolete_resources = (
    "chrome/android/java/res_chromium_base/mipmap-hdpi/layered_app_icon_background.png",
    "chrome/android/java/res_chromium_base/mipmap-mdpi/layered_app_icon_background.png",
    "chrome/android/java/res_chromium_base/mipmap-xhdpi/layered_app_icon_background.png",
    "chrome/android/java/res_chromium_base/mipmap-xxhdpi/layered_app_icon_background.png",
    "chrome/android/java/res_chromium_base/mipmap-xxxhdpi/layered_app_icon_background.png",
    "chrome/android/java/res_chromium_base/mipmap-nodpi/layered_app_icon_foreground.xml",
)

for relative_path in obsolete_resources:
    resource = chromium / relative_path
    if resource.exists():
        resource.unlink()
        print(f"Removed unused resource: {relative_path}")
    else:
        print(f"Already absent: {relative_path}")

print("Verified Thorium launcher does not reference removed resources.")
PY

echo "=== Fix Thorium ThinLTO GN scope for Android ==="
python3 "$ROOT/.github/scripts/fix-thorium-thinlto.py" "$CR_DIR"

echo "=== Configure ARM64 release build ==="
cd "$CR_DIR"
mkdir -p out/thorium
cp "$THOR_DIR/arm/android/arm64_args.gn" out/thorium/args.gn
gn gen out/thorium
gn args out/thorium --list > /tmp/dvnex-gn-args.txt
grep -E 'target_os|target_cpu|is_official_build|is_debug' out/thorium/args.gn || true
df -h /

echo "=== Select safe parallelism from runner RAM ==="
MEM_KB="$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)"
BUILD_JOBS=2
if (( MEM_KB >= 14 * 1024 * 1024 )); then
  BUILD_JOBS=4
fi
echo "Runner RAM: $((MEM_KB / 1024 / 1024)) GiB; Ninja jobs: $BUILD_JOBS"

echo "=== Compile only the Thorium browser APK (skip Content Shell and WebView) ==="
cd "$THOR_DIR"
python3 build.py --expect-os android --expect-cpu arm64 --target chrome_public_apk -j "$BUILD_JOBS"

echo "=== APK outputs ==="
if [ -d "$CR_DIR/out/thorium" ]; then
  find "$CR_DIR/out/thorium" -type f -name '*.apk' -print || true
else
  echo "Chromium build directory does not exist: $CR_DIR"
fi
df -h /
