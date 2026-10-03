# 5.9.0-beta.9 Verification

- All plugin Lua files: **syntax PASS** with `texluac -p` in the build environment; release CI still uses `luac5.1 -p`.
- beta.8 Home/translation contract: **PASS** (`tools/test_beta8_home_translation_contract.lua`).
- beta.9 Home Sync entry contract: **PASS** (`tools/test_beta9_home_sync_contract.lua`).
- beta.9 static verifier: **17 / 17 PASS** (`tools/verify_590_beta9.py`).
- Extension Center UX regression: **24 / 24 PASS** (`tools/test_extension_center_ux.py`).
- `miuread.koplugin/miuread/sync.lua` remains byte-identical to beta.8: `ed10bf4829d4bdc3034117b703333bcff9b5d802594baa29da6fb07cbd41cd5c`.
- Full package ZIP integrity: **PASS**; required files present and forbidden source-only files absent.
- Schema remains 136.
