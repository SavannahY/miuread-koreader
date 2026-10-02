# 5.9.0-beta.2 Verification

## Result

- `tools/verify_590_beta2.py`: **19 checks / 0 failures**.
- Runtime Lua syntax: **137 / 137 files passed** with `texluac -p`.
- Portable `tools/test_*.lua`: **24 passed**.
- `tools/test_reader_context.lua`: **environment skip** in this container because the plain LuaTeX runtime does not provide KOReader/LuaJIT's `bit` module; it exits while loading `miuread/protocol.lua`, before assertions execute.
- Release CHANGELOG parser: **PASS** for `## 5.9.0-beta.2` and 5 bullet items.
- `.github/workflows/release-beta.yml`: YAML parse **PASS**.

## beta.2-specific invariants

1. Technical page capture does not create freshness. Runtime resolution no longer falls back from `updated_at` to `captured_at` merely because an EPUB was opened or inspected.
2. Shelf and Reader use event-level `updated_at` consistently for local freshness.
3. `prefer_nonstale_remote()` keeps a stored cloud position when a later-arriving response is provably older by server timestamp and differs in exact position.
4. Timestamp-less cloud responses are not guessed stale; the guard only rejects observations whose older age can be demonstrated.
5. beta.1 protections remain: latest-wins is not max-percent, user interaction blocks late automatic jumps, remote auto-jump requires exact coordinates, exact verification failure rolls back, and percent-equivalent success remains removed.
6. Beta Release now runs position/freshness regression tests and `verify_590_beta2.py` before packaging.
7. CHANGELOG version sections are standardized as `## <version>`; a mistaken `# <version>` produces an actionable workflow error before release creation.

## Portable regression set

Passed in this container:

- clipboard
- cloud freshness contract
- cloud mirror contract
- cloud shelf sort
- digest stream
- download safety
- extension catalog/download/install
- finished resolution
- generated relink
- HTTP Keep-Alive
- long-book anchor
- online comment likes
- opening sync contract
- position resolution
- progress ratio
- reading-time recovery
- schema 136 contract
- shelf group recovery
- Store repair/shared
- terminal progress guard
- title metadata

## Remaining real-device validation

Automated checks cannot prove Kindle/KOReader touch timing or WeRead's real multi-device server ordering. beta.2 should still be tested with: phone-newer, Kindle-newer, network timeout + late response, re-reading after 100%, long-book cross-device resume, and PW5 low-memory/background-download scenarios.
