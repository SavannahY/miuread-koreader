# 5.9.0-beta.14 Verification

- beta.14 progress stabilization contract: `tools/test_beta14_sync_contract.lua`.
- Generic position/progress/open-sync/store regression tests remain applicable.
- beta.14 static verifier: `tools/verify_590_beta14.py`.
- Release workflow runs syntax/regression verification before tag creation.
- Full package contains only `miuread.koplugin/`; source package retains repository tools and docs.
