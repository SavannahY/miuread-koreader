from pathlib import Path
import sys
root=Path(__file__).resolve().parents[1]
main=(root/'miuread.koplugin/main.lua').read_text(encoding='utf-8')
sync=(root/'miuread.koplugin/miuread/sync.lua').read_text(encoding='utf-8')
source=(root/'miuread.koplugin/miuread/source_position.lua').read_text(encoding='utf-8')
precise=(root/'miuread.koplugin/miuread/precise_position.lua').read_text(encoding='utf-8')
resolution=(root/'miuread.koplugin/miuread/position_resolution.lua').read_text(encoding='utf-8')
config=(root/'miuread.koplugin/miuread/config.lua').read_text(encoding='utf-8')
meta=(root/'miuread.koplugin/_meta.lua').read_text(encoding='utf-8')
ch=(root/'CHANGELOG.md').read_text(encoding='utf-8')
workflow=(root/'.github/workflows/release-beta.yml').read_text(encoding='utf-8')
checks=[]
def ok(cond,msg): checks.append((bool(cond),msg))

def block(text,start,end=None):
    a=text.find(start)
    if a<0: return ''
    b=text.find(end,a+len(start)) if end else -1
    return text[a:b if b>=0 else None]

ok('VERSION = "5.9.0-beta.13"' in config,'config version beta.13')
ok('version = "5.9.0-beta.13"' in meta,'metadata version beta.13')
ok(ch.startswith('## 5.9.0-beta.13'),'beta.13 changelog is first')

# New position mapping contract.
ok('function M.captureAt(ui, record, catalog, xp)' in precise,'arbitrary XPointer capture exists')
ok('remote_anchor_short_prefix' in sync,'remote-to-local short-prefix anchor recovery exists')
ok('local function locate_anchor_with_recovery(map, anchor)' in source,'anchor recovery exists')
ok('multi_short_edge' in source and 'short_edge_unique' in source,'bounded short-anchor recovery exists')
ok('[MiuRead][ProgressSourceRecovery]' in source,'anchor recovery is diagnosable')
ok('source_xpointer = tostring(anchor.xpointer or "")' in source,'mapped position carries source XPointer')
ok('"source_xpointer"' in resolution,'position snapshots retain source XPointer')

# Preflight-before-jump contract.
use=block(main,'function Plugin:_use_remote_position','function Plugin:on_remote_source_conflict')
a=use.find('resolve_remote_candidate_xpointer')
b=use.find('resolve_xpointer_progress')
c=use.find('jump_xpointer(candidate_xp)')
ok(a>=0 and b>a and c>b,'remote candidate is mapped before visible jump')
ok('_restore_position_rollback' not in use,'automatic failed preflight does not visibly rollback')
ok('verified_near' in use and 'unresolved' in use,'exact/verified_near/unresolved states exist')
ok('user_interacted_during_preflight' in use,'preflight cancels on late user interaction')
ok('remote.canonical_progress or remote.calculated_percent' in use,'remote UI/apply path prefers canonical percent')

# Applying guard must wrap only actual jump, not async preflight.
apply=block(main,'local function apply_remote(resolved_remote)','local basis=tostring(remote')
ok('self._position_resolution_applying=true' not in apply,'preflight leaves page-turn detection active')
ok('self._position_resolution_applying=true' in use and 'self._position_resolution_applying=false' in use,'actual verified jump is guarded')

# Late remote protection and exact close cache.
on_remote=block(main,'function Plugin:on_remote_progress','function Plugin:_use_remote_position')
ok('local interacted=self._open_sync_user_interacted==true or self._auto_position_check_user_interacted==true' in on_remote,
   'late automatic result respects ordinary user interaction')
ok('patch.last_exact_position=U.copy(snapshot)' in sync,'last exact position persisted')
ok('function Plugin:_schedule_last_exact_position_refresh()' in main,'last exact cache refreshed after page settling')
ok('reused last exact position' in main,'reading end reuses matching exact cache')

# Raw percent must not drive new preflight candidate generation.
candidate=block(sync,'function Sync:resolve_remote_candidate_xpointer','function Sync:resolve_xpointer_progress')
ok('remote.canonical_progress or remote.calculated_percent' in candidate,'candidate percent fallback is canonical only')
ok('remote.percent' not in candidate,'raw remote percent excluded from beta.13 preflight')
ok('remote.protocol_percent=tonumber(remote.protocol_percent or remote.raw_percent)' in sync,'protocol percent is explicitly labeled')

# Strict exact tolerance and beta.12 safety remain.
ok('return 16' in resolution and 'math.abs(ao-bo)<=tolerance(a,b)' in resolution,'strict exact co tolerance retained')
ok('reason=force_source_refresh' in source,'beta.12 force-refresh recovery retained')
ok('FFIUtil.isSubProcessDone,pid,false' in sync,'beta.12 writer completion guard retained')

# Release pipeline uses current regression contract before tag creation.
ok('lua5.1 tools/test_beta13_sync_contract.lua' in workflow,'release workflow runs beta.13 contract')
ok('python3 tools/verify_590_beta13.py' in workflow,'release workflow runs beta.13 verifier')
test_step=workflow.find('- name: Run Lua syntax checks and release regression verifier')
tag_step=workflow.find('- name: Ensure release tag')
ok(test_step>=0 and tag_step>=0 and test_step<tag_step,'release tests still run before tag creation')

failed=[m for c,m in checks if not c]
for c,m in checks: print(('PASS' if c else 'FAIL')+': '+m)
print(f'checks={len(checks)} failures={len(failed)}')
if failed: sys.exit(1)
