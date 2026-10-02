local f=assert(io.open("miuread.koplugin/main.lua","rb")); local s=f:read("*a"); f:close()
for _,needle in ipairs{
    "正在同步最新阅读位置…","OPEN_SYNC_SOFT_TIMEOUT_SECONDS","LATE_REMOTE_APPLY_WINDOW_SECONDS",
    "late_remote_after_user_interaction","_show_position_undo","自动同步最新阅读位置",
    "_G.__MIUREAD_POSITION_RESOLUTION.decide","onNetworkConnected","remote position verified",
    "remote_exact_coordinate_missing_local_safe","remote_verification_failed_rollback","未覆盖云端",
    "blocking surface and restarting",
} do assert(s:find(needle,1,true),needle) end
assert(not s:find('text="使用云端位置"',1,true),"old local/cloud choice must be gone")
assert(not s:find('text="使用本机位置并上传"',1,true),"old local/cloud choice must be gone")
print("open sync contract: PASS")
