local root=arg[1];package.path=root..'/miuread.koplugin/?.lua;'..package.path
local function copy(v)if type(v)~='table' then return v end;local o={};for k,x in pairs(v)do o[k]=copy(x)end;return o end
package.loaded.logger=setmetatable({},{__index=function()return function()end end})
package.loaded['miuread.util']={copy=copy,first_line=tostring}
package.loaded['miuread.protocol']={SKILL_VERSION='1.0.5',reader_url=function()return 'https://weread.qq.com/'end}
package.loaded['miuread.codec']={}
package.loaded['miuread.http']={is_auth_error=function()return false end,auth_error_code=function()return nil end}
local Api=require('miuread.api')
local calls={};local web_fail=false
local h={post_json=function(_,url,payload,opt)
 calls[#calls+1]={url=url,payload=payload,opt=opt}
 if url:find('/web/') and web_fail then error('timeout')end
 return {reviews={}}
end}
local a=Api:new(h,{auth=function()return {api_key='inert-test-key'}end},nil)
local batch={{range='1-3',count=5,maxIdx=5,synckey=2}}
local limits={max_response_bytes=524288,retries=0,timeout={5,8}}
a:readreviews('b','1',batch,limits)
assert(#calls==1 and calls[1].opt.max_response_bytes==524288 and calls[1].opt.retries==0)
assert(calls[1].opt.min_interval==0.45 and calls[1].payload.reviews[1].maxIdx==5)
print('PASS bounded page request preserves Web pacing, range and cursor')
web_fail=true;calls={};a:readreviews('b','1',batch,limits)
local last=calls[#calls];assert(last.url:find('/agent/gateway') and last.opt.max_response_bytes==524288)
assert(last.opt.min_interval==4.25 and last.payload.reviews[1].count==5 and last.payload.reviews[1].synckey==2)
print('PASS fallback preserves bounded page and existing Agent rate limit')
web_fail=false;calls={};a:readreviews('b','1',batch)
assert(calls[1].opt.max_response_bytes==nil and calls[1].opt.retries==1)
print('PASS existing eager callers retain original options')
