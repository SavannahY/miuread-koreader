local root=arg[1]
package.path=root..'/miuread.koplugin/?.lua;'..package.path
local passed=0
local function test(name,fn) local ok,err=pcall(fn);if not ok then error(name..': '..tostring(err)) end;passed=passed+1;print('PASS '..name) end
package.loaded.logger=setmetatable({},{__index=function()return function()end end})
local M=require('miuread.on_demand_thoughts')
local Display=require('miuread.thought_display_text')
local function response(n,cursor,more,range)
 local rows={};for i=1,n do rows[i]={review={content='内容'..i,author={nick='作者'},reviewId='r'..i,abstract='引文'}} end
 return {reviews={{range=range or '1-5',pageReviews=rows,maxIdx=cursor,hasMore=more,synckey=123}}}
end
test('server cursor and synckey preserved',function()
 local p=M.normalize(response(5,17,1),'1-5',12)
 assert(#p.items==5 and p.more and p.next_cursor==17 and p.synckey==123)
end)
test('terminal empty page and no false next button',function()
 local p=M.normalize(response(0,5,0),'1-5',5);assert(#p.items==0 and not p.more)
end)
test('reject mismatched range',function() assert(not pcall(M.normalize,response(2,5,0,'9-10'),'1-5',0)) end)
test('reject oversized page rather than silently discard comments',function() assert(not pcall(M.normalize,response(6,6,1),'1-5',0)) end)
test('reject stale and missing pagination cursor',function()
 for _,x in ipairs({0,4,-1,2.5}) do assert(not pcall(M.normalize,response(5,x,1),'1-5',4)) end
 assert(not pcall(M.normalize,response(5,nil,1),'1-5',4))
end)
test('reject excessive content bytes',function()
 local r=response(1,1,0);r.reviews[1].pageReviews[1].review.content=string.rep('a',M.MAX_PAGE_BYTES+1)
 assert(not pcall(M.normalize,r,'1-5',0))
end)
test('only requested range and five entries sent',function()
 local api={_agent_readreviews=function(_,b,c,batch,opt)
  assert(b=='b' and c=='c' and #batch==1 and batch[1].count==5 and batch[1].maxIdx==15 and batch[1].synckey==0)
  assert(opt.max_response_bytes==512*1024 and opt.retries==0 and opt.rate_limit_fail_fast)
  return response(5,20,1)
 end}
 assert(M.fetch(api,{book_id='b',chapter_uid='c',range='1-5'},15,77).next_cursor==20)
end)
test('cache LRU retains only two first batches and respects byte budget',function()
 local c=M.new_cache();local p=M.normalize(response(5,5,1),'1-5',0)
 M.cache_put(c,'a',p);M.cache_put(c,'b',p);M.cache_get(c,'a');M.cache_put(c,'c',p)
 assert(c.entries.a and c.entries.c and not c.entries.b and #c.order==2 and c.bytes<=M.MAX_CACHE_BYTES)
 local nextpage=M.normalize(response(5,10,1),'1-5',5);M.cache_put(c,'d',nextpage);assert(not c.entries.d)
end)
local function copy(v) if type(v)~='table' then return v end;local o={};for k,x in pairs(v) do o[k]=copy(x) end;return o end
package.loaded.logger=setmetatable({},{__index=function() return function() end end})
package.loaded['miuread.util']={copy=copy}
package.loaded['miuread.json']={}
package.loaded['miuread.thought_database']={}
package.loaded['libs/libkoreader-lfs']={}
local Thoughts=require('miuread.thoughts')
test('old and new links decode independently',function()
 local old=Thoughts.parse_href(Thoughts.href('book','10','1-5'));assert(not old.on_demand and old.range=='1-5')
 local new=Thoughts.parse_href(Thoughts.href('book','10','ondemand:1-5'));assert(new.on_demand and new.range=='1-5')
 assert(not Thoughts.parse_href('https://unrelated'))
end)
package.loaded['miuread.http']={is_auth_error=function()return false end,is_rate_limit_error=function()return false end,is_forbidden_error=function()return false end}
package.loaded['miuread.annotation_coord']={}
package.loaded['miuread.annotations.posmap']={}
package.loaded['miuread.annotations.range']={}
package.loaded['miuread.annotation_style']={CSS='test'}
local A=require('miuread.annotations')
local review_calls=0
local api={underlines=function()return {underlines={{range='0-2',markText='ab'},{range='3-5',markText='de'}}} end,
 review_batches=function()error('on-demand download must not request review batches')end,
 readreviews=function()review_calls=review_calls+1;error('unexpected reviews')end}
local a=A:new(api)
test('download retrieves positions only, never reviews',function()
 local d=a:fetch_chapter('b','c',nil,{on_demand=true});assert(d.complete and d.on_demand and d.underline_count==2 and d.thought_entry_count==0 and review_calls==0)
 local cached=a:from_cache(a:to_cache(d));assert(cached.on_demand and cached.complete and cached.underline_count==2)
 local html=a:apply('<p>abcdef</p>',cached)
 assert(html:find('miu%-thought%-link') and html:find('6f6e64656d616e643a'))
 local info=Thoughts.parse_href(html:match('href="([^"]+)"'));assert(info.on_demand and info.range=='0-2')
end)
test('lazy mode does not inherit thousands of cached thoughts',function()
 local prior={complete=true,review_map={['0-2']={{content='old'}}},on_demand=nil}
 local d=a:fetch_chapter('b','c',nil,{on_demand=true,previous=prior})
 local merged=a:merge(prior,d);assert(merged.on_demand and #merged.review_groups==0 and next(merged.review_map)==nil)
end)
test('full mode does not reuse lazy completeness as fetched reviews',function()
 local called=false
 local full=A:new({underlines=api.underlines,review_batches=function()called=true;return {} end})
 full:fetch_chapter('b','c',nil,{previous=a:fetch_chapter('b','c',nil,{on_demand=true})})
 assert(called)
end)
-- Execute the complete controller against widget and asynchronous boundary doubles.
local UI={shown={},show=function(self,w)self.shown[#self.shown+1]=w;self.last=w end,
 close=function(self,w)w.closed=true;if w.tap_close_callback then w.tap_close_callback() end end}
package.loaded['ui/uimanager']=UI
local widget={new=function(_,v) v.onClose=function(self) UI:close(self);if self.close_callback then self.close_callback() end end;return v end}
package.loaded['ui/widget/buttondialog']=widget;package.loaded['ui/widget/textviewer']=widget
local native_options
package.loaded['miuread.on_demand_popup']={show=function(opts)
 native_options=opts
 local parts={};for _,item in ipairs(opts.comments)do parts[#parts+1]=item.content end
 local w={text=table.concat(parts,'\n'),comments=opts.comments,batch_buttons=opts.batch_buttons,on_close_callback=opts.on_close}
 function w:_close()UI:close(self);if self.on_close_callback then self.on_close_callback()end end
 UI:show(w);return w
end,cleanup=function()end}

local workers={}
package.loaded['miuread.async']={new=function(_,store,options)
 assert(options.disable_fallback)
 local a={running=false,available=function()return true end,busy=function(self)return self.running end,
 cancel=function(self)self.running=false;self.cancelled=true end,
 run=function(self,label,fn,cb,timeout) self.running=true;self.callback=cb;self.worker=fn;assert(timeout==20);return true end}
 workers[#workers+1]=a;return a
end}
local function plugin()
 local p={_thought_popup_generation=1,who='one',valid=true,online=true,finished=0}
 p.store={auth=function()return {account={vid=p.who},login_session_id=p.who}end,preferences=function()return {thoughts={}}end}
 function p:_interactive_network_context()return {}end
 function p:_interactive_network_context_valid()return self.valid end
 function p:_network_radio_hint()return self.online end
 function p:_thought_font_size()return 22 end
 function p:_thought_font_name()return "reading-serif" end
 function p:_thought_font_size_value()return 22 end
 function p:_finish_thought_popup()self.finished=self.finished+1;M.cancel(self,false)end
 return p
end
local info={book_id='b',chapter_uid='c',range='1-5',on_demand=true}
local function deliver(a,page) a.running=false;a.callback({ok=true,value={page=page or M.normalize(response(5,5,1),'1-5',0)}}) end
local function button(text)
 for _,row in ipairs(UI.last.buttons_table or UI.last.buttons or (UI.last.batch_buttons and {UI.last.batch_buttons}) or {}) do for _,b in ipairs(row) do if b.text==text then return b.callback end end end
 error('button missing '..text)
end
test('cancel terminates request and late result does not reopen UI',function()
 local p=plugin();M.open(p,info,1);local w=workers[#workers];button('取消')();local shown=#UI.shown
 deliver(w);assert(#UI.shown==shown and w.cancelled and p._on_demand_session==nil)
end)
test('close preserves only first batch; next requires explicit action',function()
 local p=plugin();M.open(p,info,1);local w=workers[#workers];deliver(w)
 assert(UI.last.text:find('内容') and not w.running)
 button('下一批')();assert(w.running)
 deliver(w,M.normalize(response(2,7,0),'1-5',5));assert(not UI.last.text:find('下一批'))
 button('关闭')();assert(p._on_demand_session==nil and #p._on_demand_cache.order==1)
 M.open(p,info,1);assert(not workers[#workers].running and UI.last.text:find('内容'))
 M.cancel(p,true);assert(p._on_demand_cache==nil)
end)
test('reader switch discards response and releases display',function()
 local p=plugin();M.open(p,info,1);local w=workers[#workers];p.valid=false;local shown=#UI.shown;deliver(w)
 assert(#UI.shown==shown and p._on_demand_session==nil)
end)
test('old callback cannot close a newer popup',function()
 local p=plugin();M.open(p,info,1);local old=workers[#workers]
 p._thought_popup_generation=2;M.open(p,info,2);local new=p._on_demand_session;deliver(old)
 assert(p._on_demand_session==new and not new.cancelled);M.cancel(p,true)
end)
test('account change clears cache and prevents stale display',function()
 local p=plugin();M.open(p,info,1);deliver(workers[#workers]);button('关闭')()
 p.who='two';M.open(p,info,1);assert(#p._on_demand_cache.order==0 and workers[#workers].running);M.cancel(p,true)
end)
test('offline and timeout offer retry without blocking the UI',function()
 local p=plugin();p.online=false;M.open(p,info,1);assert(UI.last.title:find('未联网'));p.online=true;button('重试')()
 package.loaded['miuread.http']={is_auth_error=function()return false end}
 local w=workers[#workers];w.running=false;w.callback({ok=false,error='worker timeout'})
 assert(UI.last.title:find('超时'));button('关闭')();assert(p._on_demand_session==nil)
end)
test('outside tap cancels real ButtonDialog callback contract',function()
 local p=plugin();M.open(p,info,1);local w=workers[#workers]
 assert(type(UI.last.tap_close_callback)=='function')
 UI.last.tap_close_callback();assert(w.cancelled and p._on_demand_session==nil)
end)
test('background worker actually retrieves and displays an authenticated bounded page',function()
 local p=plugin();local agent_calls=0
 package.loaded['miuread.http']={new=function(_,store)assert(store:auth().login_session_id=='one');return {}end,is_auth_error=function()return false end}
 package.loaded['miuread.api']={new=function(_,http,store,reader)
  assert(reader==nil)
  return {_agent_readreviews=function(_,book,chapter,batch,opt)
   agent_calls=agent_calls+1;assert(batch[1].count==5 and batch[1].synckey==0 and opt.max_response_bytes==524288)
   return response(5,5,1)
  end,readreviews=function()error('expired web route must not run')end}
 end}
 M.open(p,info,1);local w=workers[#workers];local payload=w.worker()
 assert(agent_calls==1);w.running=false;w.callback({ok=true,value=payload})
 assert(UI.last.text:find('内容') and type(button('下一批'))=='function')
 button('关闭')();assert(p._on_demand_session==nil)
end)
test('emoji, family sequences, flags and CJK preserve readable names',function()
 assert(Display.safe('张三😊')=='张三[微笑]')
 assert(Display.safe('李👩‍👩‍👧‍👦四')=='李[表情]四')
 assert(Display.safe('A🇯🇵B')=='A[表情]B')
 assert(Display.safe('中文・日本語 café')=='中文・日本語 café')
 assert(Display.safe('赞👍🏽!')=='赞[赞]!')
 assert(Display.safe('心❤️好')=='心[爱心]好')
 assert(Display.safe('坏'..string.char(255)..'名')=='坏?名')
end)
test('author and body remain separate and emoji cannot block a page',function()
 local p=plugin();M.open(p,info,1);local page=M.normalize(response(1,1,0),'1-5',0)
 page.items[1].author='名字😎';page.items[1].content='正文😊';deliver(workers[#workers],page)
 assert(native_options.font_name=='reading-serif' and native_options.font_size==22)
 assert(native_options.comments[1].author=='名字[表情]' and native_options.comments[1].content=='正文[微笑]')
 assert(page.items[1].author=='名字😎' and page.items[1].content=='正文😊')
 assert(not native_options.online_likes_enabled and UI.last.batch_buttons)
 button('关闭')();assert(p._on_demand_session==nil)
end)
print('All '..passed..' on-demand tests passed')
