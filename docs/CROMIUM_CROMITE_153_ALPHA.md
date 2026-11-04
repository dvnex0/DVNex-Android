# DVNex NEW 3 — Chromium/Cromite 153 ARM64 (experimental)

This branch is an isolated prototype for producing a **real Chromium Android browser APK** with the DVNex package ID. It does not use Android WebView or GeckoView.

## Exact source pins

| Component | Pin |
|---|---|
| Cromite patch/configuration repository | `uazo/cromite` |
| Cromite commit | `3724efc6ede3d2d94611c1fe71d1b090ebbb40a7` |
| Chromium tag | `153.0.8010.37` |
| Android target | `arm64` |
| GN target | `chrome_public_apk` |
| Application ID | `com.browser.dvnexnew3` |
| Launcher/application label | `DVNex NEW 3` |

The pins match the Cromite checkout that was inspected for this prototype. The source tree is fetched separately because a Cromite checkout contains its patch series and build configuration, not the complete Chromium source tree.

## Important version warning

**This is a test-only base, not a safe public release base.** On November 4, 2026, Chrome Stable for Android is `157.0.8103.38`; this branch is pinned to Chromium 153 so that the inspected Cromite patch series and its expected source tag remain aligned. Chromium 153 is several milestones behind and does not contain the security fixes shipped in 157.

Do not use an APK from this branch as your everyday browser, for sensitive accounts, or for public distribution. The next release-oriented step is to port and validate the patches against the current Chromium milestone, not to silently change the version pin.

References:
- [Chrome 157 for Android, November 3, 2026](https://chromereleases.googleblog.com/2026/11/chrome-for-android-update.html)
- [Chromium Android build instructions](https://chromium.googlesource.com/chromium/src/+/main/docs/android_build_instructions.md)
- [Cromite build instructions](https://github.com/uazo/cromite/blob/master/docs/HOW_TO_BUILD.md)

## What the build script does

Run `scripts/build-dvnex-cromium-arm64.sh` on a Linux x86_64 host. It:

1. Checks available disk and memory.
2. Clones `depot_tools`.
3. Checks out the exact Cromite commit and Chromium tag listed above.
4. Syncs Chromium DEPS and Android build hooks.
5. Applies the Cromite patch series, with selected branding/updater/UI patches deferred.
6. Sets the DVNex package ID and app label.
7. Generates GN files and builds `chrome_public_apk`.
8. Prints the APK path and SHA-256 hash. Set `INSTALL=1` to install it through ADB after a successful build.

The script stores large checkouts under `.dvnex-build/`. It is ignored by Git.

## Patches intentionally deferred

The first prototype does not apply these patches:

- `Cromite-Branding.patch` and `Cromite-Branding--improve-settings-ui.patch`: Cromite branding and settings must not be shipped as DVNex.
- `Bromite-auto-updater.patch`: the DVNex updater must not point to another project's releases.
- `Android-Toolbar-Scroll-Ablation-setting.patch`: the token lifecycle needs a DVNex-specific review.
- `Restore-adaptive-button-in-top-toolbar-customization.patch`: it forces the adaptive button to display regardless of available screen width and changes unrelated toolbar behavior.
- `Use-list-mode-for-tab-switcher.patch`: large UI/model change; DVNex will own the tab-switcher presentation.
- `Move-navigation-bar-to-bottom.patch`, `Add-option-to-force-tablet-UI.patch`, and `Always-open-browser-controls-in-new-tab.patch`: defer until the core build is validated.

The first APK keeps Chromium's stock icons as placeholders. The logo/adaptive icon replacement and DVNex toolbar/home/tab UI are separate implementation steps.

## Host requirements and build limitations

Use a Linux x86_64 environment with at least 100 GiB free disk and 8 GiB RAM; 16 GiB RAM or more is strongly recommended. Chromium source sync and native compilation are large operations. A standard free GitHub-hosted runner is not a reliable place to compile Chromium: its short-lived disk, memory and job limits are not equivalent to a dedicated Chromium build host.

This branch therefore supplies a reproducible build script, not a precompiled APK. The script has not been executed end-to-end in this chat environment. A successful GN generation and Ninja build must be confirmed on a sufficiently provisioned Linux host.

## Run

From the repository root:

```bash
chmod +x scripts/build-dvnex-cromium-arm64.sh
./scripts/build-dvnex-cromium-arm64.sh
```

To skip the system package installer when the required Linux dependencies are already installed:

```bash
SKIP_BUILD_DEPS=1 ./scripts/build-dvnex-cromium-arm64.sh
```

To install the generated APK on a connected Android device after compilation:

```bash
INSTALL=1 ./scripts/build-dvnex-cromium-arm64.sh
```

If patch application fails partway through, do not rerun against the half-patched checkout. Inspect the first failing patch, then remove the `.dvnex-build` workspace before retrying.

## Licensing

This build combines Chromium, Cromite patches, and other third-party components with different licenses. Preserve all upstream copyright notices, license files, and attribution requirements. Review the license of each imported patch and dependency before distributing a binary.
