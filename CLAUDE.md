# CLAUDE.md

Personal technical notes (Markdown) on embedded Linux, Android/AOSP, and boards
(RK3566, Raspberry Pi, Orange Pi, Jetson, STM32). No code is built here; the
"product" is accurate, readable notes.

## Layout
- `Android/`: AOSP, AIDL/HIDL/HAL, Binder, SELinux, VINTF, JNI, apps, signing
- `Linux/`: kernel, device tree, drivers, GPIO, tools
- `shellScript/`: Bash scripting notes (basics, brackets, quoting, recipes), regular expressions, text tools (grep, sed, awk), Linux command cheat sheet, small scripts
- top level: misc topics (protocols, boards, RF, math, ...)
- Some topics exist in both folders (e.g. `Linux/HAL_intro.md` vs `Android/HAL_intro.md`,
  libgpiod notes). Check both before writing, so they don't contradict each other.

## Typical task: "review <prefix>_* files, correct and refactor"
1. Read every file in the set **and** the closely related notes, and grep for
   links to them (`grep -rn "<name>" --include=*.md .`).
2. Fix technical errors first. Then refactor:
   - Merge files that substantially overlap (git mv / git rm). Each remaining file
     covers one topic.
   - Rename files whose name doesn't match the content.
   - Fix every link to renamed/removed files.
3. Flag related files outside the requested set; don't edit them without asking.
4. Verify:
   - all relative `](x.md)` links resolve
   - every code fence is closed and has a language tag
   - names are consistent across a note (package ↔ lib ↔ include ↔ instance name)
5. Do **not** commit unless asked.

## Note style
- `#` title, numbered `## 1. ...` sections, `+` bullets, tables for comparisons.
- Prose is ordinary paragraphs. Don't use the old trailing-two-space line breaks.
- Code fences always tagged: `c`, `c++`, `java` (for .aidl), `kotlin`, `xml`,
  `bp` (Android.bp), `dts`, `shell`, `text` (diagrams, .rc, sepolicy).
  ASCII diagrams go inside ```text fences.
- End each note with `## Related notes` (relative links to siblings) and
  `## Reference` (official docs: developer.android.com, source.android.com,
  docs.kernel.org, vendor docs).
- Remove chat leftovers ("Since you were just looking at...").
- English; they/them for people.

## Technical conventions for examples
- C++ AIDL: use the **NDK backend** (`libbinder_ndk`, `ndk::ScopedAStatus`,
  `<aidl/...>` headers, `SharedRefBase::make`, `AServiceManager_*`). Never mix it
  with CPP-backend types (`android::sp`, `binder::Status`, `defaultServiceManager`).
  - `AServiceManager_addService` returns `binder_exception_t`; check it against `EX_NONE`.
  - `#define LOG_TAG` before includes; use `<log/log.h>` + `liblog`.
- HALs: stable AIDL (`@VintfStability`, `stability: "vintf"`, frozen versions),
  package `vendor.<company>.hardware.*` (`android.hardware.*` is reserved for Google),
  NDK backend, `/vendor/bin/hw/` (`relative_install_path: "hw"`), VINTF manifest +
  compatibility matrix, explicit SELinux (`hal_attribute`, `hal_server_domain`,
  `hal_client_domain`, `service_contexts`).
- App ↔ service and service ↔ HAL calls go through Binder, not JNI.
  3rd-party apps reach hardware only through a system app (bound service).
  Never suggest `allow untrusted_app <device>` rules.
- GPIO: character device (`/dev/gpiochipN`) + libgpiod. The notes use the
  **libgpiod v1** API (`gpiod_line_*`); say so, and note that v2 differs.
  libgpiod is user-space and not part of AOSP. sysfs GPIO is deprecated.
  Keep output lines requested; don't re-request an output line as input.
  Device permissions via `ueventd.rc`, not root.
- RK3566 pin math: `GPIO<bank>_<group><n>` → `gpiochip<bank>`, offset = group*8 + n
  (A=0..D=3).
- Prefer cautious, verifiable version claims (e.g. "HIDL deprecated in Android 10,
  AIDL HALs since Android 11"). Don't invent APIs or links. If unsure, link the
  overview page.

## Git
- Branch: `master`. Commit only when asked.
- Message style: short lowercase summary ending with a period, e.g.
  `correct and refactor HAL notes with Claude Code.`, then optional
  `- file: change` bullets, then the Co-Authored-By trailer.
- Large rewrites show as delete+add; mention `git log --follow` for renamed files.
