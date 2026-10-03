local f=assert(io.open("miuread.koplugin/main.lua","rb")); local s=f:read("*a"); f:close()
for _,needle in ipairs{
    "正在后台确认云端位置", "OPEN_SYNC_SOFT_TIMEOUT_SECONDS", "LATE_REMOTE_APPLY_WINDOW_SECONDS",
    "OPEN_SYNC_READ_DEBOUNCE_SECONDS", "_show_position_undo", "_G.__MIUREAD_POSITION_RESOLUTION.decide",
    "self._progress_write_fences", "remote_newer_pending", "remote_exact_unresolved",
    "resolve_remote_candidate_xpointer", "ProgressPreflight", "未覆盖云端",
} do assert(s:find(needle,1,true),needle) end
assert(not s:find("progress_write_blocked=true",1,true),"write fence must not be persisted")
assert(not s:find("automatic_check_after_user_interaction",1,true),"user interaction must not force local wins")
assert(not s:find("late_remote_after_user_interaction",1,true),"late interaction must not force local wins")
assert(not s:find('text="使用云端位置"',1,true),"old local/cloud choice must be gone")
assert(not s:find('text="使用本机位置并上传"',1,true),"old local/cloud choice must be gone")
-- beta.13: failed automatic remote mapping is invisible; it must not restore a
-- page that was already made visible as a speculative jump.
local a=assert(s:find('function Plugin:_use_remote_position',1,true))
local b=assert(s:find('function Plugin:on_remote_source_conflict',a+1,true))
local use=s:sub(a,b-1)
assert(not use:find('_restore_position_rollback',1,true),"automatic preflight failure must not visibly rollback")
print("open sync contract: PASS")
