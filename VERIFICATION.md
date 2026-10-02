# 5.9.0-beta.4 Verification

## Real-device failure addressed

The uploaded Kindle log reproduced two independent 5.9 sync faults: a cyclic remote `sources` graph persisted into `position_state` could later make `U.merge()` recurse until LuaJIT stack overflow, and a freshly observed cloud position could be mistaken for the historical verified anchor during first reconciliation. beta.4 fixes both paths and adds startup repair for beta.1–beta.3 state already written to disk.

## Automated results

- Runtime Lua syntax: **139 / 139 PASS** (`texluac -p`).
- beta.4 hotfix verifier: **30 checks / 0 failures** (`tools/verify_590_beta4.py`).
- Extension Center UX contract: **24 checks / 0 failures** (`tools/test_extension_center_ux.py`).
- Critical portable regressions all PASS: position-state hotfix, position resolution, Store repair/shared persistence, clipboard, percent conversion, title metadata, internal links, opening-sync contract, cloud freshness, Schema 136, and terminal-progress guard.
- Full host `texlua` sweep: **26 PASS / 4 environment-limited**. The four non-runnable tests require LuaJIT `bit` or Lua 5.1 `newproxy` (`test_reader_context.lua`, `test_translation.lua`, `test_translation_fetch.lua`, `test_translation_generation.lua`); no product assertion was reached. GitHub Release CI installs Lua 5.1/LuaJIT and runs these core translation/context regressions before packaging.
- Optional Python translation harnesses could not run in this container because `lupa` is not installed.
- Installer ZIP integrity: **PASS**, 261 entries, only `miuread.koplugin/` at the root.

## Hotfix invariants

- Durable `position_state` stores scalar coordinate snapshots only; runtime `sources` graphs cannot be persisted.
- `Store:save_session()` compacts both current and incoming state before recursive merge.
- Startup repair compacts beta.1–beta.3 nested/cyclic position snapshots without changing Schema 136.
- `remote_observed` is never a verified common anchor. Only durable verified/aligned coordinates can become the reconciliation anchor.
- Resolution context is frozen before the cloud fetch so the just-fetched remote cannot masquerade as history.
- First reconciliation with no trusted anchor and no durable local event can select a newer timestamped cloud position.
- Opening soft fallback is **6 seconds**; hard timeout remains 8 seconds, and late-remote user-interaction protection remains enabled.
- `chapter_uid + co` remains the final success criterion; percent-equivalent success remains disabled.
- beta.3 translation, Extension Center UX, #117 and #118 protections remain present.

## Package

- Package: `miuread-v5.9.0-beta.4-full.zip`
- Size: **2,012,490 bytes**
- SHA-256: `672b252a39baeec8150670528fa321b014be37c0ddffef09b28ad83c77f5f92d`
