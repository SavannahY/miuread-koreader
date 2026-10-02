-- beta.26 long-book contract: percentage navigates, chapter+co verifies.
local main=assert(io.open('miuread.koplugin/main.lua','rb')):read('*a')
assert(main:find('mapped_percent_equivalent',1,true)==nil,'percent equivalence cannot verify exact mismatch')
assert(main:find('chapter_offset_mismatch',1,true) and main:find('co_tolerance',1,true),'chapter+co exact verification retained')
assert(main:find('chapter_anchor_rescue',1,true) or main:find('chapter anchor',1,true),'chapter rescue retained')
assert(main:find('第 "..tostring(local_ordinal).." 章',1,true),'conflict UI shows local chapter')
assert(main:find('第 "..tostring(remote_ordinal).." 章',1,true),'conflict UI shows remote chapter')
print('long book anchor: PASS')
