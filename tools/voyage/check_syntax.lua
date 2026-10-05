-- Parse files without executing plugin code or requiring KOReader dependencies.
for _,path in ipairs(arg) do assert(loadfile(path)) end
