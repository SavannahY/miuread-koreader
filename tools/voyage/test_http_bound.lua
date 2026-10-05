local empty={}
for _,k in ipairs({'ltn12','socket.http','ssl.https','socket.url','lfs','miuread.config','miuread.network_policy','miuread.cookies','miuread.protocol'}) do package.loaded[k]={} end
package.loaded['socket']={gettime=os.clock}
package.loaded['socketutil']={set_timeout=function()end,reset_timeout=function()end}
package.loaded['miuread.json']={decode=function()return {}end}
package.loaded['miuread.util']={}
package.loaded['miuread.network_health']={}
package.loaded.logger=setmetatable({},{__index=function()return function()end end})
package.loaded['ssl.https'].request=function()end
local H=dofile(arg[1])
local function run(chunks,limit)
 local h=H:new{auth=function()return {}end}
 function h:_jar()return {}end
 function h:_pace()end
 function h:_keepalive_begin()return nil end
 function h:_keepalive_finish()end
 local delivered=0
 function h:_transport_request(transport,request)
  for _,v in ipairs(chunks) do
   delivered=delivered+1
   local ok,err=request.sink(v)
   if not ok then return true,nil,nil,{},err end
  end
  request.sink(nil);return true,1,200,{},'OK'
 end
 local body,code,_,_,err=h:_request_once{url='https://weread.qq.com/web/book/readReviews',auth=false,max_response_bytes=limit}
 return body,code,err,delivered
end
local body,code,err,n=run({'1234','5678','never retained'},6)
assert(body=='1234' and code==nil and err:find('size limit') and n==2)
print('PASS real HTTP sink aborts oversized response before retaining offending chunk')
body,code,err,n=run({'123','456'},6);assert(body=='123456' and code==200 and err==nil)
print('PASS exact response boundary accepted')
body,code,err=run({'123','456'},nil);assert(body=='123456' and code==200)
print('PASS existing unbounded callers unchanged')
