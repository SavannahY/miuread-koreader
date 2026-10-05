-- SavannahY Voyage fork modifications, 2026-10-05. AGPL-3.0-only.
-- Display-only fallback for old e-ink font stacks. Stored names/text stay intact.
local M={}
local named={ [0x1F602]='[笑哭]',[0x1F923]='[笑哭]',[0x1F60A]='[微笑]',[0x1F44D]='[赞]',[0x2764]='[爱心]',[0x1F525]='[火]',[0x1F389]='[庆祝]' }
local function decode(s,i)
 local a=s:byte(i);local n,cp
 if a<0x80 then return a,1 end
 if a>=0xC2 and a<=0xDF then n=2;cp=a-0xC0
 elseif a>=0xE0 and a<=0xEF then n=3;cp=a-0xE0
 elseif a>=0xF0 and a<=0xF4 then n=4;cp=a-0xF0
 else return nil,1 end
 for j=1,n-1 do local c=s:byte(i+j);if not c or c<0x80 or c>0xBF then return nil,1 end;cp=cp*64+c-0x80 end
 if (n==2 and cp<0x80) or (n==3 and cp<0x800) or (n==4 and cp<0x10000) or cp>0x10FFFF or (cp>=0xD800 and cp<=0xDFFF) then return nil,1 end
 return cp,n
end
function M.safe(value)
 local s=type(value)=='string' and value or '';local out={};local i=1;local in_cluster=false
 while i<=#s do
  local cp,n=decode(s,i)
  if not cp then out[#out+1]='?';in_cluster=false
  elseif cp==0x200D or cp==0xFE0F or cp==0xFE0E or cp==0x20E3 or (cp>=0xE0020 and cp<=0xE007F) or (cp>=0x1F3FB and cp<=0x1F3FF) then
   -- Variation selectors, joiners and modifiers have no standalone glyph.
  elseif (cp>=0x1F000 and cp<=0x1FAFF) or (cp>=0x2600 and cp<=0x27BF) then
   if not in_cluster then out[#out+1]=named[cp] or '[表情]' end;in_cluster=true
  elseif cp==0 or (cp<0x20 and cp~=9 and cp~=10 and cp~=13) then
   in_cluster=false
  else out[#out+1]=s:sub(i,i+n-1);in_cluster=false end
  i=i+n
 end
 return table.concat(out)
end
return M
