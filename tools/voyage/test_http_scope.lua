-- Offline regressions: real Http:request + persisted cooldown handling.
-- Transport, time and persistence are inert; no network or device files touched.
local candidate=assert(arg[1], 'auth candidate path required')
local now,files,records,serial=10000,{}, {},0
local function copy(t)
 if type(t)~='table' then return t end
 local out={} for k,v in pairs(t) do out[k]=copy(v) end return out
end
local Json={encode=function(t) serial=serial+1 local key='json:'..serial records[key]=copy(t) return key end,
 decode=function(key) assert(records[key], 'invalid JSON fixture') return copy(records[key]) end}
local Util={read_file=function(p) return files[p] end, atomic_write=function(p,s) files[p]=s return true end,
 redact_url=function(u) return u end}
for _,name in ipairs({'ltn12','socketutil','socket.http','ssl.https','socket.url','lfs','miuread.config','miuread.network_policy','miuread.cookies','miuread.protocol'}) do package.loaded[name]={} end
package.loaded['socket']={gettime=function() return now end,sleep=function(s) error('unexpected real sleep: '..s) end}
package.loaded['miuread.json']=Json
package.loaded['miuread.util']=Util
package.loaded['miuread.network_health']={note_success=function() end,note_failure=function() end}
package.loaded['logger']={warn=function() end,info=function() end,dbg=function() end,err=function() end}
os.time=function() return now end
os.remove=function(p) files[p]=nil return true end
local Http=dofile(candidate)
local GOOGLE='https://www.googleapis.com/books/v1/volumes?q=fixture'
local WEREAD='https://weread.qq.com/r/weread-skills'
local API='https://weread.qq.com/api/auth/getLoginUid'
local OPEN='https://openlibrary.org/search.json?q=fixture'
local function fixture()
 now=10000 files={} records={} serial=0
 local h=Http:new{data_dir='/inert-fixture'}
 h.rate_limit_retries=0 h.waits={} h.calls=0
 function h:_request_once(opt) self.calls=self.calls+1 return 'ok',self.next_status or 200,{},opt.url end
 function h:_wait_rate_limit(s) self.waits[#self.waits+1]=s now=now+s end
 return h
end
local function request(h,url,scope,status,extra)
 local opt={url=url,retries=0,rate_limit_retries=0,rate_limit_scope=scope}
 for k,v in pairs(extra or {}) do opt[k]=v end
 h.next_status=status or 200
 return pcall(h.request,h,opt)
end
local function limited(h,url,scope)
 local ok,err=request(h,url,scope,429)
 assert(not ok and tostring(err):find('MiuReadRateLimit',1,true),'expected429')
end
local function legacy(h,source,scope)
 files[h:_rate_limit_path(scope or 'global')]=Json.encode{until_at=now+293,code='429',source=source,scope=scope or 'global'}
end
local count=0
local function test(name,fn)
 local ok,err=pcall(fn)
 if not ok then io.stderr:write('FAIL '..name..': '..tostring(err)..'\n') os.exit(1) end
 count=count+1 print('PASS '..name)
end
test('new Google429 never delays WeRead',function()
 local h=fixture() limited(h,GOOGLE)
 assert(files[h:_rate_limit_path('global')]==nil)
 assert(request(h,WEREAD)) assert(#h.waits==0)
 assert(request(h,API)) assert(#h.waits==0)
end)
test('same external service preserves its cooldown',function()
 local h=fixture() limited(h,GOOGLE) assert(request(h,GOOGLE))
 assert(#h.waits==1 and h.waits[1]==300)
end)
test('external services have isolated cooldowns',function()
 local h=fixture() limited(h,GOOGLE) assert(request(h,OPEN)) assert(#h.waits==0)
end)
test('WeRead429 retains global cooldown across endpoints',function()
 local h=fixture() limited(h,API)
 assert(files[h:_rate_limit_path('global')])
 assert(request(h,'https://i.weread.qq.com/web/fixture'))
 assert(#h.waits==1 and h.waits[1]==300)
end)
test('WeRead explicit scope name and separation preserved',function()
 local h=fixture() limited(h,API,'annotation')
 assert(files[h:_rate_limit_path('annotation')])
 assert(request(h,API)) assert(#h.waits==0)
 assert(request(h,API,'annotation')) assert(h.waits[1]==300)
end)
test('external explicit scope remains separated and namespaced',function()
 local h=fixture() limited(h,GOOGLE,'annotation')
 assert(files[h:_rate_limit_path('annotation')]==nil)
 assert(request(h,API,'annotation')) assert(request(h,GOOGLE)) assert(#h.waits==0)
 assert(request(h,GOOGLE,'annotation')) assert(h.waits[1]==300)
end)
test('legacy Google global state ignored by WeRead but retained',function()
 local h=fixture() legacy(h,GOOGLE)
 local old=files[h:_rate_limit_path('global')]
 assert(request(h,WEREAD,nil,200,{rate_limit_fail_fast=true})) assert(#h.waits==0)
 assert(files[h:_rate_limit_path('global')]==old)
 assert(request(h,GOOGLE)) assert(#h.waits==1 and h.waits[1]==293)
end)
test('legacy WeRead global state still applies',function()
 local h=fixture() legacy(h,API)
 assert(request(h,WEREAD)) assert(h.waits[1]==293)
end)
test('legacy unknown source remains conservative for WeRead',function()
 local h=fixture() legacy(h,nil)
 assert(request(h,WEREAD)) assert(h.waits[1]==293)
end)
test('legacy WeRead state does not leak to metadata',function()
 local h=fixture() legacy(h,API)
 assert(request(h,GOOGLE)) assert(#h.waits==0)
end)
test('external default port and hostname case normalize',function()
 local h=fixture() limited(h,GOOGLE)
 assert(request(h,'https://WWW.GOOGLEAPIS.COM:443/books/v1/volumes')) assert(h.waits[1]==300)
end)
test('genuine WeRead fail fast still prevents transport',function()
 local h=fixture() limited(h,API) local calls=h.calls
 local ok,err=request(h,WEREAD,nil,200,{rate_limit_fail_fast=true})
 assert(not ok and tostring(err):find('MiuReadRateLimit',1,true)) assert(h.calls==calls and #h.waits==0)
end)
print(string.format('HTTP scope tests: %d passed',count))
