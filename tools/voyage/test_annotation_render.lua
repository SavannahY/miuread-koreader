local candidate=assert(arg[1]);local upstream=assert(arg[2])
local function renderer(name)
 local f=assert(io.open(name));local s=f:read('*a');f:close()
 local block=assert(s:match('(local function render_text_token.-)\nlocal function inject'))
 local loader=assert(loadstring(block..'\nreturn render_text_token'))
 local function key(a,b,c) return tostring(a)..':'..tostring(b)..':'..tostring(c) end
 setfenv(loader,setmetatable({Thoughts={href=key,mark_class=key,anchor=key}},{__index=_G}))
 return loader()
end
local old=renderer(upstream)
local new=renderer(candidate)
local d={book_id='test',chapter_uid='1'}
math.randomseed(4817)
for case=1,1200 do
 local marks={};local pos=math.random(0,5)
 for i=1,math.random(0,120) do
  pos=pos+math.random(0,8)
  local last=pos+math.random(1,15)
  marks[#marks+1]={a=pos,b=last,key=pos..'-'..last,thought=math.random(0,1)==1};pos=last
 end
 local aa,bb={},{}
 for t=1,math.random(1,15) do
  local units={};for i=1,math.random(0,100) do units[i]=({'a','中','&amp;','😀'})[math.random(1,4)] end
  local token={start=math.random(0,pos+30),units=units,raw=table.concat(units),skip=math.random(1,9)==1,inside_anchor=math.random(0,1)==1}
  assert(old(token,marks,d,aa)==new(token,marks,d,bb),'output mismatch '..case)
 end
 for k,v in pairs(aa) do assert(bb[k]==v) end
 for k,v in pairs(bb) do assert(aa[k]==v) end
end
print('PASS 1200 randomized multi-token equivalence cases: Unicode, gaps, endpoints, skipped tokens, existing links and shared anchors')
local marks={};for i=1,1000 do marks[i]={a=i*20,b=i*20+8,key=tostring(i),thought=i%2==0} end
local units={};for i=1,22000 do units[i]='中' end
local token={start=0,units=units,raw=table.concat(units)}
local t=os.clock();local a=old(token,marks,d,{});local before=os.clock()-t
t=os.clock();local b=new(token,marks,d,{});local after=os.clock()-t
assert(a==b)
print(string.format('Synthetic rendering only: original %.4fs optimized %.4fs speedup %.1fx',before,after,before/math.max(after,0.000001)))
