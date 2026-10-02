# 5.8.0-beta.26 Verification

## Automated verifier

`python tools/verify_beta26.py`

Result: **337 checks, 0 failures**.

Coverage includes the inherited beta.25 synchronization/precision invariants plus beta.26 regressions for:

- #111 plain-function clipboard calls in comments and excerpt cards.
- #115 0–100 WeRead percent vs 0–1 ratio separation and 100% terminal guard.
- #107 numeric XML entities, CDATA, protected identity fields, and refresh-time generated-book relink.
- #114 strict chapter/co verification and chapter-aware multi-device conflict display.
- #116 sustained low-memory checkpoint/hibernate guard for heavy downloads.

## Portable Lua regression tools

All portable `tools/test_*.lua` tests passed under `texlua`, including the new beta.26 tests:

- `test_clipboard.lua`
- `test_progress_ratio.lua`
- `test_title_metadata.lua`
- `test_generated_relink.lua`
- `test_download_safety.lua`
- `test_terminal_progress_guard.lua`
- `test_long_book_anchor.lua`

`test_reader_context.lua` cannot start in this container because stock `texlua` does not provide KOReader/LuaJIT's `bit` module. The failure occurs during module loading, before any assertion runs; it is therefore recorded as an **environment limitation**, not a passing test and not a beta.26 assertion failure.

## Lua syntax

All shipped Lua sources parsed successfully through the verifier's syntax pass.
