local script=arg and arg[0] or ""
local root=script:match("^(.*)/tools/[^/]+$") or "."
local function read(path)
    local f=assert(io.open(root.."/"..path,"rb")); local s=f:read("*a"); f:close(); return s
end
local main=read("miuread.koplugin/main.lua")
local sync=read("miuread.koplugin/miuread/sync.lua")
local source=read("miuread.koplugin/miuread/source_position.lua")
local precise=read("miuread.koplugin/miuread/precise_position.lua")
local resolution=read("miuread.koplugin/miuread/position_resolution.lua")
local config=read("miuread.koplugin/miuread/config.lua")

assert(config:find('VERSION = "5.9.0-beta.13"',1,true),"beta.13 version")
assert(config:find('REMOTE_VERIFIED_NEAR_CO_MAX = 256',1,true),"verified-near co guard")
assert(config:find('LAST_EXACT_POSITION_REFRESH_DELAY_SECONDS = 1.4',1,true),"last exact refresh delay")

local function slice(text,a,b)
    local i=assert(text:find(a,1,true),"missing "..a)
    local j=b and text:find(b,i+1,true) or nil
    return text:sub(i,(j and j-1) or #text)
end

-- Preserve the strict authoritative coordinate tolerance. beta.13 does not
-- simply widen exact equality to make failures disappear.
assert(resolution:find('return math.abs(ao-bo)<=tolerance(a,b)',1,true),"strict same-position check retained")
assert(resolution:find('return 16',1,true),"native wr_data_co exact tolerance retained")

-- Candidate XPointers can be mapped without changing the visible Reader page.
assert(precise:find('function M.captureAt(ui, record, catalog, xp)',1,true),"captureAt missing")
assert(sync:find('PrecisePosition.captureAt(ui,record,self:_precision_catalog(record),options.xpointer)',1,true),"async mapper cannot capture candidate xpointer")
assert(sync:find('remote_anchor_short_prefix',1,true),"remote-to-local short-prefix anchor recovery missing")
assert(sync:find('options.skip_inverse_mapping==true and U.copy(value)',1,true),"candidate verification must not remap current page")

-- Long anchors remain first choice; unique edge-short recovery is bounded.
assert(source:find('local function locate_anchor_with_recovery(map, anchor)',1,true),"anchor recovery missing")
assert(source:find('recovery_strategy="long_exact"',1,true),"long exact anchor is not first-class")
assert(source:find('"multi_short_edge" or "short_edge_unique"',1,true),"short edge recovery missing")
assert(source:find('anchor_recovery_strategy = tostring(located.recovery_strategy or "long_exact")',1,true),"recovery diagnostics missing")
assert(source:find('[MiuRead][ProgressSourceRecovery]',1,true),"recovery success log missing")

-- Remote application is preflight-first. The visible jump is allowed only
-- after the candidate's chapter/co has been source-mapped and accepted.
local use_remote=slice(main,'function Plugin:_use_remote_position','function Plugin:on_remote_source_conflict')
local candidate=assert(use_remote:find('resolve_remote_candidate_xpointer',1,true),"candidate resolver missing")
local verify=assert(use_remote:find('resolve_xpointer_progress',candidate,true),"candidate preflight missing")
local jump=assert(use_remote:find('jump_xpointer(candidate_xp)',verify,true),"verified jump missing")
assert(candidate < verify and verify < jump,"visible jump occurs before preflight")
assert(not use_remote:find('_restore_position_rollback',1,true),"automatic jump rollback still present")
assert(use_remote:find('quality=matched and "exact" or (near and "verified_near" or "unresolved")',1,true),"three-level precision state missing")
assert(use_remote:find('user_interacted_during_preflight',1,true),"late user interaction cancellation missing")
assert(use_remote:find('remote.canonical_progress or remote.calculated_percent',1,true),"canonical remote progress missing")

-- Preflight must not hide genuine page turns; only the final verified jump is
-- wrapped by the apply guard.
local remote_branch=slice(main,'local function apply_remote(resolved_remote)','local basis=tostring(remote')
assert(not remote_branch:find('self._position_resolution_applying=true',1,true),"preflight wrongly suppresses user interaction")
assert(use_remote:find('self._position_resolution_applying=true',1,true),"verified jump apply guard missing")

-- User interaction and soft-timeout late results remain fail-closed.
local on_remote=slice(main,'function Plugin:on_remote_progress','function Plugin:_use_remote_position')
assert(on_remote:find('local interacted=self._open_sync_user_interacted==true or self._auto_position_check_user_interacted==true',1,true),"ordinary interaction late guard missing")
assert(on_remote:find('remote_newer_pending',1,true),"late remote pending state missing")

-- Last exact chapter/co + XPointer is persisted during idle page settling and
-- reused only when the close-time XPointer is exactly the same.
assert(resolution:find('"source_xpointer"',1,true),"source_xpointer is not persisted")
assert(sync:find('patch.last_exact_position=U.copy(snapshot)',1,true),"last exact cache missing")
assert(main:find('function Plugin:_schedule_last_exact_position_refresh()',1,true),"idle exact refresh missing")
assert(main:find('same_xpointer=type(xpointer_snapshot)=="string"',1,true),"reading-end xpointer cache guard missing")
assert(main:find('[MiuRead][ReadingEnd] reused last exact position',1,true),"reading-end exact-cache reuse log missing")

-- Raw WeRead percentage remains protocol metadata; beta.13 candidate generation
-- never uses it as a jump seed.
assert(sync:find('remote.protocol_percent=tonumber(remote.protocol_percent or remote.raw_percent)',1,true),"protocol percent marker missing")
local candidate_fn=slice(sync,'function Sync:resolve_remote_candidate_xpointer','function Sync:resolve_xpointer_progress')
assert(candidate_fn:find('remote.canonical_progress or remote.calculated_percent',1,true),"canonical candidate fallback missing")
assert(not candidate_fn:find('remote.percent',1,true),"raw percent can still drive candidate jump")

-- beta.12 source refresh and writer completion safeguards stay intact.
assert(source:find('reason=force_source_refresh',1,true),"beta.12 forced source refresh removed")
assert(sync:find('FFIUtil.isSubProcessDone,pid,false',1,true),"beta.12 writer completion guard removed")

print("beta13 sync contract: PASS")
