local root=arg[1];package.path=root..'/miuread.koplugin/?.lua;'..package.path
local function copy(v) if type(v)~='table' then return v end;local o={};for k,x in pairs(v)do o[k]=copy(x)end;return o end
package.loaded.logger=setmetatable({},{__index=function()return function()end end})
package.loaded['miuread.util']={copy=copy,first_line=tostring}
package.loaded['miuread.protocol']={SKILL_VERSION='1.0.5',reader_url=function()return 'https://weread.qq.com/'end}
package.loaded['miuread.codec']={}
package.loaded['miuread.http']={is_auth_error=function()return false end,auth_error_code=function()return nil end}
local Api=require('miuread.api');local M=require('miuread.on_demand_thoughts')
local calls=0
local api=Api:new({post_json=function(_,url,payload,opt)
 calls=calls+1
 assert(url=='https://i.weread.qq.com/api/agent/gateway' and payload.api_name=='/book/readreviews')
 assert(payload.reviews[1].count==5 and payload.reviews[1].synckey==0)
 assert(opt.min_interval==4.25 and opt.shared_pacing and opt.max_response_bytes==524288 and opt.retries==0)
 local rows={};for i=1,5 do rows[i]={reviewId='r'..i,review={reviewId='r'..i,content='text'..i,author={nick='author'},abstract='quote'}}end
 return {data={reviews={{range='1-5',pageReviews=rows,maxIdx=5,hasMore=1,synckey=123}}}}
end},{auth=function()return {api_key='inert-test-key'}end},nil)
local p=M.fetch(api,{book_id='b',chapter_uid='1',range='1-5'},0,123)
assert(calls==1 and #p.items==5 and p.more and p.next_cursor==5 and p.items[1].content=='text1')
print('PASS actual controller + actual Api uses only bounded Agent route and parses the real response shape')
