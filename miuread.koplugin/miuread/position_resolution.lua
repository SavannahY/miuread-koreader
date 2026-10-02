-- 5.9.0: deterministic latest-wins resolution for local/cloud reading positions.
-- Progress magnitude never determines freshness. Percent is presentation/navigation only.
local M = {}

local function number(v, fallback)
    v=tonumber(v)
    if v==nil then return fallback end
    return v
end

local function uid(p)
    p=type(p)=="table" and p or {}
    return tostring(p.chapter_uid or p.chapterUid or "")
end

local function offset(p)
    p=type(p)=="table" and p or {}
    return tonumber(p.canonical_offset or p.chapter_offset or p.offset or p.chapterOffset)
end

local function basis(p)
    p=type(p)=="table" and p or {}
    return tostring(p.offset_basis or p.position_basis or "")
end

local function tolerance(a,b)
    local ba,bb=basis(a),basis(b)
    if ba=="wr_data_co" or bb=="wr_data_co" or ba=="native_wr_data_co" or bb=="native_wr_data_co" then
        return 16
    end
    return 12
end

function M.same_position(a,b)
    local au,bu=uid(a),uid(b)
    local ao,bo=offset(a),offset(b)
    if au=="" or bu=="" or ao==nil or bo==nil or au~=bu then return false end
    return math.abs(ao-bo)<=tolerance(a,b)
end

local function anchor_position(anchor)
    anchor=type(anchor)=="table" and anchor or {}
    if tostring(anchor.chapter_uid or "")=="" or tonumber(anchor.chapter_offset)==nil then return nil end
    return {
        chapter_uid=anchor.chapter_uid,
        chapter_offset=anchor.chapter_offset,
        offset_basis=anchor.offset_basis or anchor.position_basis,
    }
end

local function changed_from_anchor(position, anchor)
    local ap=anchor_position(anchor)
    if not ap then return nil end
    return not M.same_position(position,ap)
end

-- input:
-- local_position, remote_position, verified_anchor,
-- local_seq, verified_seq, local_updated_at, remote_updated_at,
-- clock_skew_grace (seconds, default 120)
function M.decide(input)
    input=type(input)=="table" and input or {}
    local lp=type(input.local_position)=="table" and input.local_position or nil
    local rp=type(input.remote_position)=="table" and input.remote_position or nil
    if not lp and rp then return {winner="remote",reason="local_missing"} end
    if lp and not rp then return {winner="local",reason="remote_missing"} end
    if not lp and not rp then return {winner="local",reason="positions_missing"} end
    if M.same_position(lp,rp) then return {winner="aligned",reason="exact_position_equal"} end

    local local_seq=number(input.local_seq,0) or 0
    local verified_seq=number(input.verified_seq,0) or 0
    local seq_local_changed=local_seq>verified_seq
    local anchor=anchor_position(input.verified_anchor)
    local local_anchor_changed=changed_from_anchor(lp,input.verified_anchor)
    local remote_anchor_changed=changed_from_anchor(rp,input.verified_anchor)
    local local_changed=seq_local_changed or local_anchor_changed==true
    local remote_changed=remote_anchor_changed==true

    if local_changed and not remote_changed then
        return {winner="local",reason=seq_local_changed and "local_sequence_after_anchor" or "local_changed_after_anchor"}
    end
    if remote_changed and not local_changed then
        return {winner="remote",reason="remote_changed_after_anchor"}
    end

    local lt=number(input.local_updated_at,0) or 0
    local rt=number(input.remote_updated_at,0) or 0
    local grace=math.max(0,number(input.clock_skew_grace,120) or 120)
    if lt>0 and rt>0 and math.abs(lt-rt)>grace then
        if rt>lt then return {winner="remote",reason="remote_newer_timestamp",delta=rt-lt} end
        return {winner="local",reason="local_newer_timestamp",delta=lt-rt}
    end
    if rt>0 and lt<=0 then return {winner="remote",reason="remote_timestamp_only"} end
    if lt>0 and rt<=0 then return {winner="local",reason="local_timestamp_only"} end

    -- With no shared anchor and no durable unsent local generation, this is the
    -- first reconciliation. The account cloud is authoritative even when the
    -- server omitted a modification timestamp; merely opening the local EPUB
    -- must not make its restored position look newer.
    if not anchor and not seq_local_changed and lt<=0 and rt<=0 then
        return {winner="remote",reason="initial_cloud_authority"}
    end

    -- Once both sides have a common history, ambiguous clocks are intentionally
    -- local-first. This avoids a surprise remote jump after near-simultaneous
    -- writes; the local event then goes through exact upload/readback verification.
    return {winner="local",reason=(local_changed and remote_changed)
        and "ambiguous_clock_local_fallback" or "unknown_freshness_local_fallback"}
end


-- Keep a previously observed cloud position when a delayed response is
-- provably older by server timestamp. This only resolves out-of-order
-- observations; timestamp-less responses are never rejected here because
-- their freshness cannot be proven.
function M.prefer_nonstale_remote(incoming, stored, clock_skew_grace)
    incoming=type(incoming)=="table" and incoming or nil
    stored=type(stored)=="table" and stored or nil
    if not incoming then return stored,"incoming_missing" end
    if not stored then return incoming,"stored_missing" end
    if M.same_position(incoming,stored) then return incoming,"same_position" end
    local it=number(incoming.updated_at or incoming.updated,0) or 0
    local st=number(stored.updated_at or stored.updated,0) or 0
    local grace=math.max(0,number(clock_skew_grace,120) or 120)
    if it>0 and st>0 and st-it>grace then
        return stored,"stored_remote_newer"
    end
    return incoming,"incoming_not_proven_stale"
end

function M.resolved_finished(winner, local_percent, remote_percent)
    if winner=="remote" then return (tonumber(remote_percent) or 0)>=100 end
    return (tonumber(local_percent) or 0)>=100
end

return M
