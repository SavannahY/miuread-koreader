-- SavannahY Voyage fork modifications, 2026-10-05. AGPL-3.0-only.
-- Bounded, read-only comments. No automatic prefetch and no durable comment cache.
local logger=require("logger")
local M={PAGE_SIZE=5,MAX_RESPONSE_BYTES=512*1024,MAX_PAGE_BYTES=96*1024,MAX_CACHE_BYTES=192*1024}
local function scalar(v) return (type(v)=="string" or type(v)=="number") and tostring(v) or "" end
local function truth(v) return v==true or v==1 end
local function rows_of(v,names)
    if type(v)~="table" then return {} end
    for _,k in ipairs(names) do if type(v[k])=="table" then return v[k] end end
    return v
end
function M.normalize(response,range,cursor)
    local groups=rows_of(response,{"reviews","updated"})
    local group
    for _,g in ipairs(groups) do
        if type(g)=="table" and scalar(g.range or g.markRange or g.bookmarkRange)==range then group=g;break end
    end
    if not group then error("没有返回对应划线的想法，请稍后重试") end
    local raw=rows_of(group,{"pageReviews","reviews","updated"})
    if #raw>M.PAGE_SIZE then error("服务器返回超出单批限制的想法，已停止加载") end
    local items,seen,bytes={}, {},0
    local source=""
    for _,page in ipairs(raw) do
        if type(page)=="table" then
            local r=type(page.review)=="table" and page.review or page
            local content=scalar(r.content or r.text)
            local author=type(r.author)=="table" and scalar(r.author.nick or r.author.name) or scalar(r.authorName)
            local id=scalar(r.reviewId or r.id)
            local quote=scalar(r.abstract or r.contextAbstract or r.markText)
            if source=="" then source=quote end
            local key=id~="" and id or (author.."\0"..content)
            if content~="" and not seen[key] then
                bytes=bytes+#content+#author+#quote+#id
                if bytes>M.MAX_PAGE_BYTES then error("这批想法内容过大，已停止加载以保护内存") end
                seen[key]=true
                items[#items+1]={content=content,author=author,review_id=id}
            end
        end
    end
    cursor=tonumber(cursor) or 0
    local next_cursor=tonumber(group.maxIdx)
    local more=truth(group.hasMore)
    if more and (not next_cursor or next_cursor<=cursor or next_cursor~=math.floor(next_cursor) or #raw==0) then
        error("想法分页游标无效，已停止重复请求")
    end
    if #raw>0 and #items==0 then error("这批想法暂时无法解析，请稍后重试") end
    return {items=items,source=source,more=more,next_cursor=next_cursor,
        synckey=tonumber(group.synckey) or 0,bytes=bytes,cursor=cursor}
end
function M.fetch(api,info,cursor,synckey)
    -- synckey is a delta-sync timestamp, not a pagination token.
    -- Keep it zero when fetching older pages; maxIdx alone advances the page.
    local batch={{range=info.range,maxIdx=cursor or 0,count=M.PAGE_SIZE,synckey=0}}
    -- The authenticated Skill Gateway is verified for bounded read-only pages.
    -- Do not spend the popup deadline probing expired web cookies first.
    local response=api:_agent_readreviews(info.book_id,tonumber(info.chapter_uid) or info.chapter_uid,batch,{
        retries=0,timeout={5,8},max_response_bytes=M.MAX_RESPONSE_BYTES,
        rate_limit_retries=0,rate_limit_fail_fast=true,
    })
    return M.normalize(response,info.range,cursor)
end
function M.new_cache() return {entries={},order={},bytes=0} end
function M.cache_get(c,key)
    local e=c.entries[key]
    if not e then return nil end
    for i=#c.order,1,-1 do if c.order[i]==key then table.remove(c.order,i) end end
    c.order[#c.order+1]=key
    return e
end
function M.cache_put(c,key,page)
    if page.cursor~=0 or page.bytes>M.MAX_PAGE_BYTES then return end
    if c.entries[key] then c.bytes=c.bytes-c.entries[key].bytes end
    for i=#c.order,1,-1 do if c.order[i]==key then table.remove(c.order,i) end end
    c.entries[key]=page;c.order[#c.order+1]=key;c.bytes=c.bytes+page.bytes
    while #c.order>2 or c.bytes>M.MAX_CACHE_BYTES do
        local k=table.remove(c.order,1);c.bytes=c.bytes-c.entries[k].bytes;c.entries[k]=nil
    end
end
local function identity(plugin)
    local a=plugin.store:auth() or {}
    return scalar((a.account or {}).vid or (a.cookies or {}).wr_vid)..":"..scalar(a.login_session_id)
end
local function close_widget(session)
    local w=session.widget
    session.widget=nil
    if w then
        w.close_callback=nil;w.tap_close_callback=nil;w.on_close_callback=nil;w.on_error_callback=nil
        require("ui/uimanager"):close(w)
        -- UIManager disposes its native text buffers; drop the Lua content too.
        w.text=nil;w.buttons_table=nil
        if w._miuread_on_demand_native then require("miuread.on_demand_popup").cleanup() end
    end
end
function M.cancel(plugin,clear_cache)
    local s=plugin._on_demand_session
    plugin._on_demand_session=nil
    if s then
        s.cancelled=true
        if s.async then s.async:cancel("thought window closed") end
        if plugin._thought_popup==s.widget then plugin._thought_popup=nil end
        close_widget(s)
        s.page=nil;s.info=nil;s.async=nil
    end
    if clear_cache then plugin._on_demand_cache=nil;plugin._on_demand_identity=nil end
end
function M.open(plugin,info,generation)
    M.cancel(plugin,false)
    local Async=require("miuread.async")
    local UIManager=require("ui/uimanager")
    local ButtonDialog=require("ui/widget/buttondialog")
    local Popup=require("miuread.on_demand_popup")
    local Display=require("miuread.thought_display_text")
    local U=require("miuread.util")
    local who=identity(plugin)
    if plugin._on_demand_identity~=who then
        plugin._on_demand_cache=M.new_cache();plugin._on_demand_identity=who
    end
    plugin._on_demand_cache=plugin._on_demand_cache or M.new_cache()
    local cache=plugin._on_demand_cache
    local key=table.concat({info.book_id,info.chapter_uid,info.range},"|")
    local s={info=info,generation=generation,context=plugin:_interactive_network_context(),identity=who,
        async=Async:new(plugin.store,{disable_fallback=true,allow_android=true})}
    plugin._on_demand_session=s
    local function current()
        return plugin._on_demand_session==s and not s.cancelled
            and generation==plugin._thought_popup_generation and identity(plugin)==who
            and plugin:_interactive_network_context_valid(s.context)
    end
    local function finish()
        if plugin._on_demand_session~=s then return end
        M.cancel(plugin,false)
        plugin:_finish_thought_popup(generation)
    end
    local function show_widget(w)
        if w.tap_close_callback then
            w.tap_close_callback=function()
                if s.widget==w then s.widget=nil end
                finish()
            end
        end
        close_widget(s);s.widget=w;plugin._thought_popup=w;UIManager:show(w)
    end
    local request,render
    local function failure(message,cursor,synckey)
        if not current() then finish();return end
        show_widget(ButtonDialog:new{title=message,buttons={
            {{text="重试",callback=function() request(cursor,synckey) end},
             {text="关闭",callback=finish}},
        },tap_close_callback=finish})
    end
    render=function(page)
        if not current() then finish();return end
        s.page=page
        local comments={}
        for _,item in ipairs(page.items) do
            comments[#comments+1]={author=Display.safe(item.author),content=Display.safe(item.content),review_id=item.review_id}
        end
        if #comments==0 then comments[1]={author="微信读书",content="这处划线暂时没有想法。"} end
        local buttons={}
        if page.cursor~=0 then buttons[#buttons+1]={text="回到首批",callback=function() request(0,0) end} end
        if page.more then buttons[#buttons+1]={text="下一批",callback=function() request(page.next_cursor,page.synckey) end} end
        buttons[#buttons+1]={text="关闭",callback=finish}
        local prefs=plugin.store:preferences().thoughts or {}
        local size=plugin:_thought_font_size(plugin:_thought_font_size_value(prefs))
        close_widget(s)
        local viewer
        viewer=Popup.show{source_text=Display.safe(page.source),comments=comments,
            font_size=size,font_name=plugin:_thought_font_name(prefs),batch_buttons=buttons,
            online_likes_enabled=false,on_close=function()
                if s.widget==viewer then s.widget=nil end
                finish()
                Popup.cleanup()
            end,on_error=function()
                finish();Popup.cleanup()
                plugin:info("想法显示失败，请重试；如果仍有问题，请连接电脑检查日志。")
            end}
        viewer._miuread_on_demand_native=true
        s.widget=viewer;plugin._thought_popup=viewer

    end
    request=function(cursor,synckey)
        if not current() then finish();return end
        if s.async:busy() then return end
        if cursor==0 then
            local cached=M.cache_get(cache,key)
            if cached then render(cached);return end
        end
        if plugin:_network_radio_hint()==false then failure("当前未联网，请连接 Wi-Fi 后重试。",cursor,synckey);return end
        if not s.async:available() then failure("后台请求暂不可用，请重新打开阅读器后重试。",cursor,synckey);return end
        s.page=nil
        show_widget(ButtonDialog:new{title="正在加载这处划线的想法…",buttons={
            {{text="取消",callback=finish}},
        },tap_close_callback=finish})
        local auth=U.copy(plugin.store:auth())
        local data_dir,temp_dir=plugin.store.data_dir,plugin.store.temp_dir
        local selected=U.copy(info)
        local started=s.async:run("on-demand-thoughts",function()
            local Http=require("miuread.http")
            local Api=require("miuread.api")
            local store={data_dir=data_dir,temp_dir=temp_dir}
            local changed=false
            function store:auth() return U.copy(auth) end
            function store:save_auth(value) auth=U.copy(value);changed=true;return true end
            local api=Api:new(Http:new(store),store,nil)
            local page=M.fetch(api,selected,cursor,synckey)
            return {page=page,auth=changed and auth or nil,changed=changed}
        end,function(result)
            if not current() then finish();return end
            if result and result.ok==true and type(result.value)=="table" then
                local payload=result.value
                if payload.changed==true then plugin:_apply_interactive_auth(payload) end
                local page=payload.page
                if type(page)~="table" or type(page.items)~="table" then
                    failure("想法返回数据异常，请稍后重试。",cursor,synckey);return
                end
                M.cache_put(cache,key,page)
                logger.info("[MiuRead][OnDemandThoughts] page ready","count=",#page.items,"cursor=",page.cursor,"more=",page.more)
                local displayed,display_error=pcall(render,page)
                if not displayed then
                    logger.warn("[MiuRead][OnDemandThoughts] render failed",tostring(display_error):match("[^\n]+"))
                    finish()
                    plugin:info("想法显示失败，窗口已关闭，可以继续阅读。")
                end
            else
                local err=tostring(result and result.error or "")
                local diagnostic=err:match("attempt to [^\n]+") or err:match("error_code=[%-]?%d+") or (err:find("timeout",1,true) and "timeout") or (err:find("size limit",1,true) and "response_size_limit") or (err:find("游标",1,true) and "invalid_cursor") or (err:find("没有返回对应划线",1,true) and "range_missing") or "request_or_parse_failed"
                logger.warn("[MiuRead][OnDemandThoughts] request failed",diagnostic)
                local message="想法加载失败或超时，请稍后重试。"
                if require("miuread.http").is_auth_error(err) then message="想法接口的登录授权已失效，请在觅阅中重新登录。"
                elseif err:find("size limit",1,true) or err:find("过大",1,true) then message="这批想法内容过大，已停止加载以保护内存。"
                elseif err:find("游标",1,true) then message="分页信息异常，已停止重复请求。"
                elseif err:find("RateLimit",1,true) or err:find("429",1,true) then message="微信读书暂时限制请求，请稍后再试。" end
                failure(message,cursor,synckey)
            end
        end,20)
        if not started then logger.warn("[MiuRead][OnDemandThoughts] worker start failed");failure("后台任务未能启动，请稍后重试。",cursor,synckey) end
    end
    request(0,0)
    return true
end
return M
