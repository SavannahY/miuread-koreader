-- Offline behavioral regressions using actual functions extracted from main.lua.
-- Loads the actual background scheduler with inert UI/time/memory dependencies.
local candidate=assert(arg[1],'main.lua path required')
local scheduler_path=assert(arg[2],'background scheduler path required')
local file=assert(io.open(candidate,'rb')); local source=file:read('*a'); file:close()
local now,queue,passed=10000,{},0
local UIManager={scheduleIn=function(_,delay,fn) queue[#queue+1]={delay=delay,fn=fn} end,
 unschedule=function() end,setDirty=function() end}
local Config={HOME_FOREGROUND_BARRIER_SECONDS=.9,BACKGROUND_SERIAL_GAP_SECONDS=.35}
local RuntimePressure={memory_snapshot=function() return {level='normal',available_kb=270000} end,
 active=function() return false end,note_worker_failure=function() end}
local logger={info=function() end,warn=function() end}
package.loaded['miuread.config']=Config
package.loaded['miuread.runtime_pressure']=RuntimePressure
package.loaded['ui/uimanager']=UIManager
package.loaded['logger']=logger
package.loaded['socket']={gettime=function() return now end}
os.time=function() return now end
local Scheduler=dofile(scheduler_path)
local Plugin={}
local env=setmetatable({Plugin=Plugin,Config=Config,RuntimePressure=RuntimePressure,UIManager=UIManager,logger=logger,
 U={atomic_write=function() error('unexpected write') end},
 HomeView={is_shown=function() return true end},
 HOME_SESSION={},HOME_EXITING=false,
 HEAVY_BACKGROUND_KEYS={home_shelf=true,home_scan=true,home_metadata=true,home_cover_render=true},
 UnifiedLibrary={invalidate_external_cache=function() end},
 PowerState={state=function() return 'NORMAL' end},
 monotonic_wall_time=function() return now end,
 reader_close_active=function() return false end,reader_rebuild_active=function() return false end,
 LocalAnnotationDatabase={global_summary=function() error('worker must not run on UI thread') end},
 SHELF_CACHE_TTL=300,HOME_SHELF_REFRESH_TTL=300,HOME_REMOTE_AUTO_RETRY=60,
},{__index=_G})
local functions={'_home_complete_refresh','_home_refresh_remote','_background_claim','_background_release',
 '_background_block_reason','_home_background_blocked','_home_ui_busy','_background_cancel_worker','_home_note_interaction',
 '_schedule_home_annotation_summary_refresh','_home_sync_summary','_home_sync_status_label_from_summary',
 '_home_sync_status_label_cached'}
for _,name in ipairs(functions) do
 local body=assert(source:match('(function Plugin:'..name..'%b().-\nend)'),name..' not found')
 local f=assert(loadstring(body,'@'..candidate..':'..name)); setfenv(f,env);f()
end
local function nop() end
local function fixture()
 now=10000 queue={}; env.HOME_SESSION={}
 local p=setmetatable({starts=0,cancels=0,applied=0,toasts={},scan_starts=0,notices={},summary_runs=0,
  preferences={},sessions={},local_library={}}, {__index=Plugin})
 p.store={reload=nop,prune_missing_files=nop}
 p.library={cached=function() return {},{},0 end}
 p.background_scheduler=Scheduler:new()
 p.shelf_async={available=function() return true end,cancel=function() p.cancels=p.cancels+1 end}
 p.sync_summary_async={available=function() return true end,busy=function(s) return s.job~=nil end,
  run=function(s,label,worker,callback,timeout)
   p.summary_runs=p.summary_runs+1
   s.job={label=label,worker=worker,callback=callback,timeout=timeout};return true
  end,cancel=function(s) s.job=nil end}
 function p:_active_reader_ui() return false end
 function p:_page_transition_active() return false end
 function p:_home_modal_surface_active() return false end
 function p:_network_background_ready() return true end
 function p:_network_radio_hint() return true end
 function p:_lightweight_enabled() return false end
 function p:logged_in() return true end
 function p:is_online() return true end
 function p:toast(s) self.toasts[#self.toasts+1]=s end
 function p:_friendly_remote_error(s) return s end
 function p:_refresh_shelf_async(callback,silent,options)
  self.starts=self.starts+1;self.shelf_callback=callback;self.shelf_options=options;return true
 end
 function p:_home_apply_remote_cache_snapshot() self.applied=self.applied+1 end
 function p:_home_clear_lockscreen_visual_hold() self._home_lockscreen_visual_hold=false end
 function p:_home_bump_interaction_generation() self.interaction=(self.interaction or 0)+1 end
 p._home_resume_visible_work_after_idle=nop
 p._home_reset_local_metadata=nop;p._home_schedule_device_state_probe=nop
 p._home_scan_local=nop;p._home_relink_generated_files=nop
 p._show_miuread_home_now=nop;p._flush_home_preferences=function() return true end
 function p:_home_unschedule_task(field) self[field]=nil end
 function p:_persisted_sessions() return self.sessions end
 function p:_persisted_library() return self.local_library end
 function p:_progress_snapshot_replayable() return false end
 function p:_notify_home_data_changed(kind)
  self.notices[#self.notices+1]={kind=kind,label=self:_home_sync_status_label_cached()}
 end
 return p
end
local function finish_summary(p,value)
 local job=assert(p.sync_summary_async.job,'summary job not started')
 p.sync_summary_async.job=nil -- actual Async clears its job before callback.
 job.callback{ok=true,value=value or {}}
end
local failed=0
local function test(name,fn)
 local ok,err=pcall(fn)
 if not ok then failed=failed+1; print('FAIL '..name..': '..tostring(err))
 else passed=passed+1; print('PASS '..name) end
end
test('manual refresh starts despite its triggering gesture barrier',function()
 local p=fixture();p:_home_note_interaction(true,'gesture');p:_home_complete_refresh(true)
 assert(p.starts==1,'manual refresh remained parked')
 assert(p.background_scheduler.active.key=='home_shelf' and p.background_scheduler.active.user_requested)
 assert(p.shelf_options.skip_online_probe==false)
end)
test('later home gestures preserve explicit shelf refresh',function()
 local p=fixture();p:_home_complete_refresh(true);p:_home_note_interaction(true,'gesture')
 assert(p.cancels==0 and p._home_remote_refreshing==true)
 assert(p.background_scheduler.active and p.background_scheduler.active.key=='home_shelf')
 p.shelf_callback({}, {}, nil)
 assert(p.applied==1 and p._home_remote_refreshing==false and p.background_scheduler.active==nil)
 assert(p.toasts[#p.toasts]=='书架已刷新')
end)
test('automatic shelf refresh remains cancellable by interaction',function()
 local p=fixture();assert(p:_home_refresh_remote(true,false));p:_home_note_interaction(true,'gesture')
 assert(p.cancels==1 and p._home_remote_refreshing==false and p.background_scheduler.active==nil)
end)
test('automatic refresh still waits for foreground to settle',function()
 local p=fixture();p:_home_note_interaction(true,'gesture');p:_home_refresh_remote(true,false)
 assert(p.starts==0 and p.background_scheduler.parked.home_shelf)
end)
test('manual refresh preempts automatic metadata',function()
 local p=fixture();p.home_metadata_async={cancel=function() p.metadata_cancelled=true end}
 assert(p.background_scheduler:claim('home_metadata',{user_requested=false,heavy=true}))
 p:_home_complete_refresh(true)
 assert(p.metadata_cancelled and p.starts==1 and p.background_scheduler.active.user_requested)
end)
test('explicit refresh preserves lifecycle suspension guard',function()
 local p=fixture();p._home_suspended=true;p:_home_complete_refresh(true)
 assert(p.starts==0 and p._home_resume_pending_work.remote==true)
end)
test('summary completion immediately repaints cached success without new worker',function()
 local p=fixture();p:_schedule_home_annotation_summary_refresh(false);assert(p._home_sync_summary_task)()
 assert(p.summary_runs==1 and p.sync_summary_async.job.timeout==20)
 finish_summary(p,{})
 assert(p._home_sync_summary_cache and p._home_sync_summary_cache.checking==false)
 assert(p.notices[#p.notices].kind=='header' and p.notices[#p.notices].label=='已同步')
 assert(p.summary_runs==1 and p._home_sync_summary_task==nil,'completion requeued another scan')
end)
test('summary refresh cannot keep obsolete checking snapshot',function()
 local p=fixture();p._home_sync_summary_cache={checking=true}
 p:_schedule_home_annotation_summary_refresh(true);assert(p._home_sync_summary_task)();finish_summary(p,{})
 assert(p:_home_sync_status_label_cached()=='已同步')
end)
test('summary completion preserves real pending annotation failures',function()
 local p=fixture();p:_schedule_home_annotation_summary_refresh(true);assert(p._home_sync_summary_task)()
 finish_summary(p,{highlight=2,pending=2,failed=2})
 assert(p.notices[#p.notices].label=='同步失败 2')
end)
test('initial missing summary still shows checking until result exists',function()
 local p=fixture();assert(p:_home_sync_status_label_cached()=='同步检查中')
 p:_home_sync_summary(false);assert(p:_home_sync_status_label_cached()=='同步检查中')
end)
print(string.format('Home regressions: %d passed, %d failed',passed,failed))
if failed>0 then os.exit(1) end
