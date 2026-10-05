local root=arg[1];local f=assert(io.open(root..'/miuread.koplugin/miuread/on_demand_popup.lua'));local source=f:read('*a');f:close()
local NativePopup={}
local function extract(name)
 local start=assert(source:find('function NativePopup:'..name..'(',1,true))
 local finish=assert(source:find('\nfunction ',start+1,true))
 local chunk=assert(loadstring(source:sub(start,finish-1)))
 setfenv(chunk,setmetatable({NativePopup=NativePopup,Screen={scaleBySize=function(_,v)return v end},make_face=function(name,size,fallback)return {name=name,size=size,fallback=fallback}end},{__index=_G}));chunk()
end
extract('_layout_metrics');extract('onTapPage')
local metrics=NativePopup._layout_metrics({font_name='serif'},28)
assert(metrics.body_size==28 and metrics.meta_size==20 and metrics.meta_face.name==nil and metrics.body_face.name=='serif')
print('PASS real native metrics separate author UI font and smaller size from selected body font')
local calls=0;local button={dimen={x=20,y=80,w=80,h=20},onTapSelectButton=function()calls=calls+1 end}
local p={popup_dimen={x=0,y=0,w=200,h=120},batch_table={buttons_layout={{button}}},_change_page=function()error('batch tap must not turn comment page')end}
local pos={x=30,y=90,notIntersectWith=function(self,r)return self.x<r.x or self.y<r.y or self.x>=r.x+r.w or self.y>=r.y+r.h end}
assert(NativePopup.onTapPage(p,nil,{pos=pos}) and calls==1)
print('PASS touch Kindle footer uses ButtonTable.buttons_layout and the real KOReader Button activation method')
local closed=0;p._close=function()closed=closed+1;return true end;pos.x=250
assert(NativePopup.onTapPage(p,nil,{pos=pos}) and closed==1)
print('PASS native outside-tap still closes the popup')
