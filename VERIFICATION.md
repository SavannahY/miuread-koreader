# 5.9.0-beta.11 Verification

- beta.11 unified manual sync/wake readiness contract: `tools/test_beta11_sync_contract.lua`.
- beta.10 translation dependency contract retained: `tools/test_beta10_translation_dependency_contract.lua`.
- beta.11 static verifier: `tools/verify_590_beta11.py`.
- Home quick Sync, Sync Status all-retry and Progress all-retry share `_sync_progress_full_recovery()` after login/radio gates.
- `network_restored` and `resume_recheck` wait for online-ready state before automatic progress reconciliation.
- Translation module remains top-level independent of `miuread.util`.
- Release workflow still runs Lua/LuaJIT regressions before `Ensure release tag`.
- `miuread/sync.lua` remains byte-identical to beta.10/beta.8; time-writer detach is intentionally not adopted.
