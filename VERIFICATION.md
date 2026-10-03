# 5.9.0-beta.5 Verification

## Scope

beta.5 is a synchronization-correctness release based on the uploaded beta.4 source and real-device log. It keeps the beta.4 cyclic `position_state` repair, then changes opening reconciliation, cloud-write authorization, canonical progress handling, exact remote positioning, and reading-time retry policy.

## Automated results

- Runtime Lua syntax: **139 / 139 PASS** (`texluac -p`).
- beta.5 static verifier: **37 checks / 0 failures** (`tools/verify_590_beta5.py`).
- Extension Center UX contract: **24 checks / 0 failures**.
- Portable Lua regression sweep in this container: **27 PASS / 4 environment-limited**. The four non-runnable tests require LuaJIT `bit` or Lua 5.1 `newproxy` (`test_reader_context.lua`, `test_translation.lua`, `test_translation_fetch.lua`, `test_translation_generation.lua`). GitHub release CI installs Lua 5.1/LuaJIT and retains those tests.
- Critical beta.5 regressions PASS: position resolver, position-state hotfix, Store repair, cloud freshness, cloud mirror, long-book anchor, nonblocking opening sync, beta.5 write-fence/raw-percent contract, terminal progress guard, finished resolution, read-time recovery compatibility, and Schema 136.
- Installer ZIP integrity: **PASS**.

## beta.5 invariants

- Opening a book is nonblocking: the local page is immediately usable; cloud reconciliation is background work.
- `open_local_snapshot` is frozen before the remote observation arrives. User interaction does not become a freshness winner.
- A first restored `PageUpdate` is only a baseline. Later real page movement records local event freshness even if reading-time sync is disabled.
- `LOCAL_NEWER / REMOTE_NEWER / ALIGNED / CONFLICT` is decided by trusted common-anchor history plus reading-event timestamps; ambiguous close clocks do not authorize an overwrite.
- Any unresolved/newer remote state holds a persistent progress write fence across automatic submit paths.
- A 60-second read debounce is accepted only for an already exact-aligned cached coordinate and cannot authorize a cloud write.
- `server_raw_percent` is diagnostic only. Exact chapter/co mapping supplies canonical progress; raw 100 cannot create a finished state or poison ReadReport position context.
- Remote exact positioning prefers a verified XPointer cache, then content-anchor XPointer rescue; percentage correction is bounded to one fallback.
- Reading time is best-effort: no persistent retry debt across restart, no home failure item, and repeated runtime failure is dropped after the configured two-attempt budget.
- Schema remains 136 and beta.4 startup compaction of old/cyclic position snapshots is retained.

## Real-device validation still required

Automated tests cannot prove network timing and CREngine landing behavior on a Kindle. The next real-device pass should specifically reproduce the beta.4 cases: slow remote return while the user turns pages, remote-newer vs local-newer switching, fake `raw_percent=100`, offline dual-device reading, and the `co=45196` long-book positioning case.

## Package

- Package: `miuread-v5.9.0-beta.5-full.zip`
- Size: **2,018,483 bytes**
- SHA-256: `719da2e69f07431bfe570a41b443e0baeaa78597842ce66d0d8cd9539defb9f3`
