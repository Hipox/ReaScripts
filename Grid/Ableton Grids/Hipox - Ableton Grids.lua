-- @description Ableton Grids (ReaImGui GUI)
-- @version 1.0.0
-- @author Hipox
-- @links
--  GitHub Repository https://github.com/Hipox/ReaScripts
--  Forum Thread http://forum.cockos.com/showthread.php?t=169127
-- @donation https://paypal.me/Hipox
-- @about
--   GUI tool that extracts beat grids from Ableton Live .als
--   projects and creates custom Ableton sets from REAPER items.
-- @changelog
--   + Initial ReaPack release
-- @provides
--   ../../Libraries/json.lua
--   ableton_extract_grid.py
--   create_custom_ableton_set_and_open.py
--   [data] Grid/Ableton Grids/Reaper_Warp_Template_modified Project/**
--   [main] Grid/Ableton Grids/Hipox - Ableton Grids.lua

-- Requires:
--   - ReaImGui extension
--   - ableton_extract_grid.py
--   - create_custom_ableton_set_and_open.py
--   - json.lua

local SCRIPT_NAME = ({reaper.get_action_context()})[2]:match("([^/\\_]+)%.lua$")

local function msg(s)
    reaper.ShowConsoleMsg(tostring(s) .. "\n")
end

-----------------------------------------
-- CHECK PYTHON INSTALLATION
-----------------------------------------
local function detect_python()
    local os = reaper.GetOS()

    -- Windows: try python.exe
    if os:match("^Win") then
        local test = reaper.ExecProcess('python --version', 3000)
        if test and test:match("Python") then
            return "python"
        else
            return nil
        end
    end

    -- macOS / Linux: python3 is default
    local test = reaper.ExecProcess('python3 --version', 3000)
    if test and test:match("Python") then
        return "python3"
    end

    -- Last fallback: try plain python
    local test2 = reaper.ExecProcess('python --version', 3000)
    if test2 and test2:match("Python") then
        return "python"
    end

    return nil
end

-- Run Python check BEFORE opening GUI
local detected_python = detect_python()
if not detected_python then
    msg(
[[Python could not be found on this system.

This script requires Python to run Ableton grid extraction.

Install Python:

WINDOWS:
  1) Download from https://www.python.org/downloads/windows/
  2) IMPORTANT: Check "Add Python to PATH" during installation.

macOS:
  Run in Terminal:
      brew install python
  or install from python.org

LINUX:
  Install from package manager, e.g.:
      sudo apt install python3

GUI will NOT open until Python is available.]]
    )
    return  -- stop script completely, skip GUI
end

if not reaper.ImGui_GetBuiltinPath then
    reaper.MB("This script requires ReaImGui." ..
      "Please install it via ReaPack, and check that it's up to date in the 'Extensions' menu. \z" ..
      "Install it from ReaPack > Browse packages.",
      "Missing ImGui", 0)
    return
  end
  
  package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua'
  local ImGui = require 'imgui' '0.9.1'

-- Option tables for GUI + config

local APPLY_TYPE_OPTIONS = {
    {
        value       = "stretch_item",
        label = "Stretch item (warp to existing grid)",      -- shown in closed combo
    },
    {
        value       = "quantize_grid",
        label = "Quantize project grid (create tempo map)",
    },
}

local STRAIGHT_TEMPO_OPTIONS = {
    {
        value       = "stretch_markers",
        label = "Stretch markers",
    },
    {
        value       = "playrate",
        label = "Playrate",
    },
}

local SNAP_MODE_OPTIONS = {
    {
        value       = "nearest_qn",
        label = "Nearest grid line (QN)",
    },
    {
        value       = "next_bar",
        label = "First beat of next bar or current bar",
    },
    {
        value       = "nearest_bar",
        label  = "First beat of nearest bar",
    },
}

-----------------------------------------
-- PATHS & GLOBALS
-----------------------------------------

local script_path = ({reaper.get_action_context()})[2]:match('^.*[/\\]'):sub(1,-2)
local sep         = package.config:sub(1,1)
local repo_root = script_path .. sep .. ".." .. sep .. ".."
package.path = repo_root   .. sep .. "Libraries" .. sep .. "?.lua"
    .. ";" .. package.path
    .. ";" .. script_path .. sep .. "?.lua"

require "json"

local python_script_grid  = script_path .. sep .. "ableton_extract_grid.py"
local python_script_set   = script_path .. sep .. "create_custom_ableton_set_and_open.py"
local json_results_path = script_path .. sep ..  "ableton_result.json"

local EXT_SECTION = "Hipox_Ableton_Grids"

local function verify_file_exists(path)
    if reaper.file_exists(path) then
        return true
    else
        msg("File does NOT exist: " .. tostring(path))
        return false
    end
end

local function NormalizePath(path)
    if not path then return "" end
    -- unify slashes and lowercase for case-insensitive match on Windows
    path = path:gsub("\\", "/")
    path = path:lower()
    return path
end


local function get_python_exe()
    local os = reaper.GetOS()
    -- "Win32" / "Win64" / "OSX10.15" / "Linux" etc.
    if os:match("^Win") then
        return "python"
    else
        return "python3"   -- most common on macOS / Linux
    end
end

local function send_array_to_python_script(py_script, arr)

    local py = get_python_exe()
    local cmd = '"' .. py .. '" "' .. py_script .. '"'
    for _, v in ipairs(arr) do
        cmd = cmd .. ' "' .. v .. '"'
    end
    local timeout_ms = 500000
    return reaper.ExecProcess(cmd, timeout_ms)
end
-----------------------------------------
-- CONFIG (runtime, extstate-backed)
-----------------------------------------

local function load_ext_bool(key, default)
    local v = reaper.GetExtState(EXT_SECTION, key)
    if v == "" then return default end
    return v ~= "0"
end

local function save_ext_bool(key, val)
    reaper.SetExtState(EXT_SECTION, key, val and "1" or "0", true)
end

local function load_ext_str(key, default)
    local v = reaper.GetExtState(EXT_SECTION, key)
    if v == "" then return default end
    return v
end

local function save_ext_str(key, val)
    reaper.SetExtState(EXT_SECTION, key, tostring(val), true)
end

-- Load config (with defaults)
local apply_type         = load_ext_str("APPLY_TYPE", "stretch_item")     -- "stretch_item" or "quantize_grid"
local set_snap_offset    = load_ext_bool("SET_SNAP_OFFSET", true)
local mark_item_edges    = load_ext_bool("MARK_ITEM_EDGES", false)
local straight_tempo_mode = load_ext_str("STRAIGHT_TEMPO_MODE", "stretch_markers") -- "stretch_markers" or "playrate"
local snap_mode          = load_ext_str("SNAP_MODE", "nearest_bar")       -- "nearest_qn", "next_bar", "nearest_bar"
local use_straight_grid  = load_ext_bool("USE_STRAIGHT_GRID", false)
local beats_per_bar = tonumber(load_ext_str("BEATS_PER_BAR", "4")) or 4
if beats_per_bar < 1 then beats_per_bar = 4 end
local ableton_exe_path = load_ext_str("ABLETON_EXE_PATH", "")
-----------------------------------------
-- HELPERS – ITEMS & JSON
-----------------------------------------

-- Collect all selected items with active *audio* takes,
-- sorted by:
--   1) item position (earliest first)
--   2) track index (lower track number first)
--   3) lane index (lower lane first, if using fixed lanes)
--   4) item index on track (as a final stable tiebreaker)
local function CollectSelectedAudioActiveTakes()
    local t = {}
    local num_sel_items = reaper.CountSelectedMediaItems(0)
    if num_sel_items == 0 then return t end

    for i = 0, num_sel_items - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        if item then
            local take = reaper.GetActiveTake(item)
            if take and not reaper.TakeIsMIDI(take) then
                local src = reaper.GetMediaItemTake_Source(take)
                if src then
                    -- Resolve to topmost parent source
                    local parent = reaper.GetMediaSourceParent(src)
                    while parent do
                        src = parent
                        parent = reaper.GetMediaSourceParent(src)
                    end

                    local path = reaper.GetMediaSourceFileName(src)
                    if path ~= nil and path ~= "" then
                        local src_type = reaper.GetMediaSourceType(src)
                        if src_type ~= "MIDI" and src_type ~= "MIDIPOOL" then

                            local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
                            local track = reaper.GetMediaItem_Track(item)
                            local track_idx = reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER")

                            -- Fixed lane index (REAPER 7+). If not using fixed lanes, this is usually -1.
                            local lane_idx = reaper.GetMediaItemInfo_Value(item, "I_FIXEDLANE") or -1
                            if lane_idx < 0 then lane_idx = 0 end

                            -- Index of item on its track (stable fallback)
                            local item_idx_on_track = reaper.GetMediaItemInfo_Value(item, "IP_ITEMNUMBER") or 0

                            table.insert(t, {
                                item = item,
                                take = take,
                                path = path,
                                pos = pos,
                                track_idx = track_idx,
                                lane_idx = lane_idx,
                                item_idx_on_track = item_idx_on_track
                            })
                        end
                    end
                end
            end
        end
    end

    -- Sort:
    -- 1) position
    -- 2) track index
    -- 3) lane index
    -- 4) item index on track
    table.sort(t, function(a, b)
        if a.pos ~= b.pos then
            return a.pos < b.pos
        end
        if a.track_idx ~= b.track_idx then
            return a.track_idx < b.track_idx
        end
        if a.lane_idx ~= b.lane_idx then
            return a.lane_idx < b.lane_idx
        end
        return a.item_idx_on_track < b.item_idx_on_track
    end)

    return t
end


local function load_json_result(json_path)
    local f = io.open(json_path, "r")
    if not f then
        msg("Cannot open JSON file: " .. tostring(json_path))
        return nil
    end
    local content = f:read("*a")
    f:close()

    local ok, data = pcall(json.decode, content)
    if not ok or type(data) ~= "table" then
        msg("JSON decode error")
        return nil
    end

    return data
end

-----------------------------------------
-- EDGE MARKER HELPERS
-----------------------------------------

local function MarkItemEdgesAsTakeMarkers(take)
    if not take or not reaper.ValidatePtr2(0, take, "MediaItem_Take*") then
        return
    end

    local item = reaper.GetMediaItemTake_Item(take)
    if not item then return end

    local item_len  = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    local startoffs = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
    local playrate  = reaper.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE")
    if playrate == 0 then playrate = 1 end

    local edge_start_src = startoffs
    local edge_end_src   = startoffs + item_len * playrate

    for i = reaper.GetNumTakeMarkers(take)-1, 0, -1 do
        local _, name = reaper.GetTakeMarker(take, i)
        if name == "__EDGE_START" or name == "__EDGE_END" then
            reaper.DeleteTakeMarker(take, i)
        end
    end

    reaper.SetTakeMarker(take, -1, "__EDGE_START", edge_start_src, 0)
    reaper.SetTakeMarker(take, -1, "__EDGE_END",   edge_end_src,   0)
end

local function DeleteEdgeMarkers(take)
    if not take or not reaper.ValidatePtr2(0, take, "MediaItem_Take*") then
        return
    end

    for i = reaper.GetNumTakeMarkers(take)-1, 0, -1 do
        local _, name = reaper.GetTakeMarker(take, i)
        if name == "__EDGE_START" or name == "__EDGE_END" then
            reaper.DeleteTakeMarker(take, i)
        end
    end
end

-----------------------------------------
-- CORE MATH HELPERS
-----------------------------------------

-- Snap item to grid based on first visible source time.
-- snap_mode:
--   "next_bar"    = snap to first beat of next bar
--   "nearest_bar" = snap to first beat of nearest bar (but not < 0)
--   anything/ nil = snap to nearest QN (original behaviour)
--
-- set_snap_offset:
--   true  = also set item snap offset to that first visible source time
--   false = don't touch snap offset
--
-- Returns: new_item_start, anchor_qn, used_index, snap_offset
local function SnapItemToGridByTimesArray(item, times, snap_mode, set_snap_offset)
    local proj = 0

    if not item or type(times) ~= "table" or #times == 0 then
        return nil
    end

    local take = reaper.GetActiveTake(item)
    if not take or reaper.TakeIsMIDI(take) then
        return nil
    end

    snap_mode       = snap_mode or "nearest_qn"
    set_snap_offset = (set_snap_offset == true)

    local old_item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local item_len       = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    local startoffs      = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
    local playrate       = reaper.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE")
    if playrate == 0 then playrate = 1 end

    local src_visible_start = startoffs
    local src_visible_end   = startoffs + item_len * playrate

    local used_src_time = nil
    local used_index    = nil

    ------------------------------------------------------------
    -- 1) Find first source time inside visible portion of item
    ------------------------------------------------------------
    for idx, src_time in ipairs(times) do
        if src_time >= src_visible_start and src_time <= src_visible_end then
            used_src_time = src_time
            used_index    = idx
            break
        end
    end

    if not used_src_time then
        return nil
    end

    ------------------------------------------------------------
    -- 2) Compute project time of that visible point
    ------------------------------------------------------------
    local visible_offset = (used_src_time - startoffs) / playrate      -- seconds from item start
    local t_proj         = old_item_start + visible_offset             -- absolute project time

    ------------------------------------------------------------
    -- 3) Optionally set snap offset to that visible point
    ------------------------------------------------------------
    local snap_offset = nil
    if set_snap_offset then
        snap_offset = visible_offset

        -- clamp to item bounds just in case
        if snap_offset < 0 then
            snap_offset = 0
        elseif snap_offset > item_len then
            snap_offset = item_len
        end

        reaper.SetMediaItemInfo_Value(item, "D_SNAPOFFSET", snap_offset)
    end

    ------------------------------------------------------------
    -- 4) Choose target bar / grid position according to mode
    ------------------------------------------------------------
    local new_item_start, anchor_qn

    ----------------------------------------------------------------
    -- MODE: snap to FIRST BEAT OF NEXT BAR
    ----------------------------------------------------------------
    if snap_mode == "next_bar" then
        local retval, measures, cml, fullbeats, cdenom =
            reaper.TimeMap2_timeToBeats(proj, t_proj)

        local beats_per_measure = cml
        if not beats_per_measure or beats_per_measure <= 0 then
            beats_per_measure = 4 -- fallback
        end

        local cur_measure_start_beats = fullbeats - (fullbeats % beats_per_measure)

        -- If the anchor is already exactly on the bar start,
        -- don't move it to the next bar – just keep the item where it is.
        local cur_measure_start_time = reaper.TimeMap2_beatsToTime(proj, cur_measure_start_beats)
        local epsilon = 1e-9
        if math.abs(t_proj - cur_measure_start_time) <= epsilon then
            -- Return the original item position and used_index,
            -- no position change applied.
            return old_item_start, nil, used_index, snap_offset
        end

        -- Otherwise, go to the next bar as usual
        local next_measure_start_beats = cur_measure_start_beats + beats_per_measure

        anchor_qn = next_measure_start_beats
        local snapped_time = reaper.TimeMap2_beatsToTime(proj, anchor_qn)

        -- Just in case tempo map weirdness puts it behind:
        if snapped_time < t_proj - 1e-9 then
            anchor_qn    = anchor_qn + beats_per_measure
            snapped_time = reaper.TimeMap2_beatsToTime(proj, anchor_qn)
        end

        new_item_start = snapped_time - visible_offset
        if new_item_start < 0 then
            new_item_start = 0
        end


    ----------------------------------------------------------------
    -- MODE: snap to FIRST BEAT OF NEAREST BAR
    -- (but don't choose a bar that would move item start < 0)
    ----------------------------------------------------------------
    elseif snap_mode == "nearest_bar" then
        local retval, measures, cml, fullbeats, cdenom =
            reaper.TimeMap2_timeToBeats(proj, t_proj)

        local beats_per_measure = cml
        if not beats_per_measure or beats_per_measure <= 0 then
            beats_per_measure = 4 -- fallback
        end

        local cur_measure_start_beats = fullbeats - (fullbeats % beats_per_measure)
        local prev_beats = cur_measure_start_beats
        local next_beats = cur_measure_start_beats + beats_per_measure

        local prev_time = reaper.TimeMap2_beatsToTime(proj, prev_beats)
        local next_time = reaper.TimeMap2_beatsToTime(proj, next_beats)

        local prev_start = prev_time - visible_offset
        local next_start = next_time - visible_offset

        local prev_valid = (prev_start >= 0)
        local next_valid = true

        local snapped_time

        if prev_valid and next_valid then
            if math.abs(prev_time - t_proj) <= math.abs(next_time - t_proj) then
                anchor_qn    = prev_beats
                snapped_time = prev_time
            else
                anchor_qn    = next_beats
                snapped_time = next_time
            end
        elseif prev_valid then
            anchor_qn    = prev_beats
            snapped_time = prev_time
        else
            anchor_qn    = next_beats
            snapped_time = next_time
        end

        new_item_start = snapped_time - visible_offset
        if new_item_start < 0 then
            new_item_start = 0
        end

    ----------------------------------------------------------------
    -- DEFAULT MODE: original behaviour (snap to nearest grid / QN)
    ----------------------------------------------------------------
    else
        local qn        = reaper.TimeMap2_timeToQN(proj, t_proj)
        anchor_qn       = math.floor(qn + 0.5)

        -- Don't allow a grid position that would push item start < 0
        local min_snapped_time = visible_offset
        local min_qn           = reaper.TimeMap2_timeToQN(proj, min_snapped_time)

        if anchor_qn < min_qn then
            anchor_qn = math.ceil(min_qn)
        end

        local snapped_time = reaper.TimeMap2_QNToTime(proj, anchor_qn)
        new_item_start     = snapped_time - visible_offset

        if new_item_start < 0 then
            new_item_start = 0
        end
    end

    ------------------------------------------------------------
    -- 5) Apply new position & update item
    ------------------------------------------------------------
    reaper.SetMediaItemInfo_Value(item, "D_POSITION", new_item_start)
    reaper.UpdateItemInProject(item)

    return new_item_start, anchor_qn, used_index, snap_offset
end

local function ShareStretchMarkers(
    take,
    src_times,
    src_beats,
    item_pos,
    anchor_qn,
    used_idx,
    beats_per_bar,
    use_straight_for_this_item,
    straight_bpm,
    set_snap_offset
)
    if not take or type(src_times) ~= "table" or #src_times == 0 then return end

    beats_per_bar = math.floor(beats_per_bar or 1)
    if beats_per_bar < 1 then beats_per_bar = 4 end

    local proj = 0
    local item = reaper.GetMediaItemTake_Item(take)
    if not item then return end

    item_pos = item_pos or reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH") or 0
    if item_len <= 0 then return end

    ----------------------------------------------------------------
    -- Reset existing stretch markers
    ----------------------------------------------------------------
    local num = reaper.GetTakeNumStretchMarkers(take)
    for idx = num - 1, 0, -1 do
        reaper.DeleteTakeStretchMarkers(take, idx)
    end

    ----------------------------------------------------------------
    -- Normalize playrate (we will control timing via markers or BPM)
    ----------------------------------------------------------------
    reaper.SetMediaItemTakeInfo_Value(take, "D_PLAYRATE", 1.0)
    reaper.UpdateItemInProject(item)

    ----------------------------------------------------------------
    -- Default anchor if needed (fallback)
    ----------------------------------------------------------------
    if not anchor_qn or not used_idx then
        local retval, measures, cml, fullbeats, cdenom =
            reaper.TimeMap2_timeToBeats(proj, item_pos)
        anchor_qn = math.ceil(fullbeats)
        used_idx  = 1
    end

    ----------------------------------------------------------------
    -- STRAIGHT TEMPO: use JSON flag + straight_bpm (prefer) or src_bpms[1]
    -- IMPORTANT: anchor on src_times[used_idx], i.e. the beat you already
    -- snapped closest to the item edge, NOT always src_times[1] (beat 0).
    ----------------------------------------------------------------
    if use_straight_for_this_item and straight_tempo_mode == "stretch_markers" then

        --------------------------------------------------------
        --    Use the *anchored* source time as reference
        --    This is the warp marker closest to the item edge
        --    (used_idx), which was also used for snapping.
        --------------------------------------------------------
        used_idx = used_idx or 1
        local anchor_src_time = src_times[used_idx] or src_times[1] or 0.0

        -- seconds per beat based on BPM
        local sec_per_beat = 60 / straight_bpm

        local n = 0
        while true do
            -- project beat index, anchored at anchor_qn
            local beat_index = anchor_qn + n * beats_per_bar
            local beat_time  = reaper.TimeMap2_beatsToTime(proj, beat_index)
            local destpos    = beat_time - item_pos

            -- Skip markers strictly before item start
            if destpos < -1e-6 then
                n = n + 1
            else
                -- Stop once we pass item end
                if destpos > item_len + 1e-6 then
                    break
                end

                -- SOURCE TIME = anchor_src_time + offset * sec_per_beat
                local src_time = anchor_src_time + (n * beats_per_bar) * sec_per_beat

                reaper.SetTakeStretchMarker(
                    take,
                    -1,
                    destpos,
                    src_time
                )

                n = n + 1
            end
        end

        reaper.UpdateArrange()
        return
    end

    ----------------------------------------------------------------
    -- STRAIGHT TEMPO: playrate mode
    ----------------------------------------------------------------
    
    if use_straight_for_this_item and straight_tempo_mode == "playrate" then
        local straight_tempo = straight_bpm
    
        local clip_bpm = tonumber(straight_tempo) or 120
        if clip_bpm <= 0 then
            clip_bpm = 120
        end
    
        anchor_qn = tonumber(anchor_qn) or 0
        local anchor_time = reaper.TimeMap2_QNToTime(proj, anchor_qn)
    
        -- project BPM at the anchor
        local proj_bpm = reaper.TimeMap_GetDividedBpmAtTime(anchor_time)
        proj_bpm = tonumber(proj_bpm) or clip_bpm
        if proj_bpm <= 0 then
            proj_bpm = clip_bpm
        end
    
        local new_playrate = proj_bpm / clip_bpm
    
        ----------------------------------------------------------------
        -- NEW PART: keep the *same source point* on the grid
        ----------------------------------------------------------------
        -- which source time did we snap to?
        used_idx = used_idx or 1
        local anchor_src_time = (src_times and src_times[used_idx]) or (src_times and src_times[1]) or 0.0
    
        local startoffs = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS") or 0.0
    
        -- We want anchor_src_time to land at anchor_time after changing playrate:
        local new_item_pos = anchor_time - (anchor_src_time - startoffs) / new_playrate
        if new_item_pos < 0 then new_item_pos = 0 end
    
        -- apply both position and playrate together
        reaper.SetMediaItemInfo_Value(item, "D_POSITION", new_item_pos)
        reaper.SetMediaItemTakeInfo_Value(take, "D_PLAYRATE", new_playrate)
        if set_snap_offset then
            local snap_offset = (anchor_src_time - startoffs) / new_playrate
            if snap_offset < 0 then
                snap_offset = 0
            end
            reaper.SetMediaItemInfo_Value(item, "D_SNAPOFFSET", snap_offset)
        end
        reaper.UpdateItemInProject(item)
    
        return
    end
    
    ----------------------------------------------------------------
    -- GENERAL CASE (non-straight analysis)
    ----------------------------------------------------------------
    local beat0 = (src_beats and src_beats[used_idx]) or 0

    for i = 1, #src_times do
        local src_time  = src_times[i]
        local this_beat = (src_beats and src_beats[i]) or (beat0 + (i - used_idx))

        local delta_beats = this_beat - beat0
        local beat_index  = anchor_qn + delta_beats

        local beat_time   = reaper.TimeMap2_beatsToTime(proj, beat_index)
        local destpos     = beat_time - item_pos

        reaper.SetTakeStretchMarker(
            take,
            -1,
            destpos,
            src_time
        )
    end

    reaper.UpdateArrange()
end

-----------------------------------------
-- TEMPO GRID FROM BPM LIST
-----------------------------------------

local function ApplyBPMListToBeats(bpms, times, beats, item, start_index, clear_in_item, use_straight_for_this_item, straight_bpm)
    local proj = 0
    if not item then return end
    if type(bpms) ~= "table" or #bpms == 0 then return end
    if type(times) ~= "table" or #times == 0 then return end

    start_index   = start_index or 1
    clear_in_item = (clear_in_item ~= false)

    local take = reaper.GetActiveTake(item)
    if not take then return end

    -- In grid mode we don't want stretch markers
    local num = reaper.GetTakeNumStretchMarkers(take)
    for idx = num - 1, 0, -1 do
        reaper.DeleteTakeStretchMarkers(take, idx)
    end

    local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    local item_end = item_pos + item_len

    if clear_in_item then
        local cnt = reaper.CountTempoTimeSigMarkers(proj)
        for i = cnt - 1, 0, -1 do
            local retval, timepos = reaper.GetTempoTimeSigMarker(proj, i)
            if retval and timepos >= item_pos and timepos <= item_end then
                reaper.DeleteTempoTimeSigMarker(proj, i)
            end
        end
    end

    item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    item_end = item_pos + item_len

    local startoffs = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
    local playrate  = reaper.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE")
    if playrate == 0 then playrate = 1 end

    -- What part of the source is actually visible in this item?
    local src_visible_start = startoffs
    local src_visible_end   = startoffs + item_len * playrate

    ----------------------------------------------------------------
    -- 1) Find FIRST warp time that is actually visible in the item
    ----------------------------------------------------------------
    local first_idx = nil
    local last_idx  = nil

    for i = start_index, #times do
        local t_src = times[i]
        if t_src >= src_visible_start and t_src <= src_visible_end then
            if not first_idx then first_idx = i end
            last_idx = i
        elseif t_src > src_visible_end then
            break
        end
    end

    -- No warp markers overlap the visible part → nothing to do
    if not first_idx then
        return
    end

    ----------------------------------------------------------------
    -- 2) Convert that first visible warp time to project time
    --    This is the "first visible first beat" anchor in the project.
    ----------------------------------------------------------------
    local anchor_src_time = times[first_idx]
    local anchor_time     = item_pos + (anchor_src_time - startoffs) / playrate
    -- anchor_time is where we want the tempo change to start.

    ----------------------------------------------------------------
    -- 3) STRAIGHT GRID: use Python's decision + BPM from JSON
    ----------------------------------------------------------------
    if use_straight_for_this_item then

        if not straight_bpm or straight_bpm <= 0 then
            return
        end

        -- Single tempo marker at the first visible bar in the item.
        reaper.SetTempoTimeSigMarker(
            proj,
            -1,
            anchor_time,
            -1,
            -1,
            straight_bpm,
            0,
            0,
            false
        )

        reaper.UpdateTimeline()
        return
    end

    ----------------------------------------------------------------
    -- 4) GENERAL CASE (multi-BPM / non-straight analysis)
    ----------------------------------------------------------------
    local qn        = reaper.TimeMap2_timeToQN(proj, anchor_time)
    local anchor_qn = math.floor(qn + 0.5)

    local beat0 = (type(beats) == "table" and beats[first_idx]) or 0

    for i = first_idx, last_idx do
        local bpm = bpms[i]
        if bpm and bpm > 0 then
            local this_beat   = (type(beats) == "table" and beats[i]) or (beat0 + (i - first_idx))
            local delta_beats = this_beat - beat0
            local beat_index  = anchor_qn + delta_beats

            local timepos
            if i == first_idx then
                timepos = anchor_time
            else
                timepos = reaper.TimeMap2_QNToTime(proj, beat_index)
            end

            reaper.SetTempoTimeSigMarker(
                proj,
                -1,
                timepos,
                -1,
                -1,
                bpm,
                0,
                0,
                false
            )
        end
    end

    reaper.UpdateTimeline()
end

-----------------------------------------
-- ACTION 1: CREATE / OPEN ABLETON SET
-----------------------------------------

local function Action_CreateAbletonSetFromSelection()
    if not verify_file_exists(python_script_set) then
        msg("Python script not found: " .. python_script_set)
        return
    end

    local takes = CollectSelectedAudioActiveTakes()
    if #takes == 0 then
        msg("No selected audio items with active takes found.")
        return
    end

    -- Build args: first the Ableton path, then audio paths
    local args = {}
    table.insert(args, ableton_exe_path or "")

    for _, info in ipairs(takes) do
        table.insert(args, info.path)
    end

    local output = send_array_to_python_script(python_script_set, args)

    if not output or output == "" then
        msg("Python (create set) returned empty output.")
        return
    end

end

-----------------------------------------
-- ACTION 2: APPLY ABLETON BEATGRID
-----------------------------------------

local function Action_ApplyAbletonBeatgridToSelection()
    if not verify_file_exists(python_script_grid) then
        msg("Python script not found: " .. python_script_grid)
        return
    end

    local takes = CollectSelectedAudioActiveTakes()
    if #takes == 0 then
        msg("No selected audio items with active takes found.")
        return
    end

    local paths = {}
    for _, info in ipairs(takes) do
        table.insert(paths, info.path)
    end

    local output = send_array_to_python_script(python_script_grid, paths)

    if not output or output == "" then
        msg("Python returned empty output.")
        return
    end

    local json_path = output:match("([^\r\n]+)%s*$")
    if not json_path or json_path == "" then
        msg("Could not parse JSON path from Python output.")
        return
    end

    local data = load_json_result(json_results_path)
    if not data then return end

    local paths_list = data["paths_list"]
    local times_list = data["times_list"]
    local beats_list = data["beats_list"]
    local bpms_list  = data["bpms_list"]
    local straight_bpm_list = data["straight_bpm_list"]

    if type(paths_list) ~= "table" or type(times_list) ~= "table" then
        msg("JSON missing paths_list or times_list.")
        return
    end

    -- Build lookup: normalized_path -> { times = {...}, beats = {...}, bpms = {...} }
    local path_map = {}

    for idx, p in ipairs(paths_list) do
        if type(p) == "string" and p ~= "" then
            local norm = NormalizePath(p)

            -- Only store first occurrence for this path; duplicates will share the same grid
            if not path_map[norm] then
                path_map[norm] = {
                    times    = (type(times_list)    == "table" and times_list[idx])    or nil,
                    beats    = (type(beats_list)    == "table" and beats_list[idx])    or nil,
                    bpms     = (type(bpms_list)     == "table" and bpms_list[idx])     or nil,
                    straight_bpm = (type(straight_bpm_list) == "table" and straight_bpm_list[idx]) or nil
                }
            end
        end
    end


    if next(path_map) == nil then
        msg("No valid path entries in JSON.")
        return
    end

    reaper.Undo_BeginBlock()

    for _, info in ipairs(takes) do
        local take = info.take
        local item = info.item
        local num = reaper.GetTakeNumStretchMarkers(take)
        for idx = num-1, 0, -1 do
            reaper.DeleteTakeStretchMarkers(take, idx)
        end
        reaper.SetMediaItemTakeInfo_Value(take, "D_PLAYRATE", 1.0)
        reaper.UpdateItemInProject(item)
    end

    for i, info in ipairs(takes) do
        local item = info.item
        local take = info.take

        -- match JSON record by source path, not by index
        local norm_path = NormalizePath(info.path)
        local entry = path_map[norm_path]

        if not entry then
            msg("No JSON data for path: " .. tostring(info.path))
        else
            local src_times    = entry.times
            local src_beats    = entry.beats
            local src_bpms     = entry.bpms
            local straight_bpm = tonumber(entry.straight_bpm) or 0.0

            local use_straight_for_this_item = (use_straight_grid and straight_bpm > 0)

            if src_times and type(src_times) == "table" and #src_times > 0 then

                if mark_item_edges then
                    MarkItemEdgesAsTakeMarkers(take)
                end

                local item_pos, anchor_qn, used_idx, snap_offset =
                SnapItemToGridByTimesArray(item, src_times, snap_mode, set_snap_offset)
            

                if apply_type == "quantize_grid" then

                    if src_bpms and type(src_bpms) == "table" and #src_bpms > 0 then

                        ApplyBPMListToBeats(
                            src_bpms,
                            src_times,
                            src_beats,
                            item,
                            used_idx,
                            true,             -- clear existing tempo markers inside item
                            use_straight_for_this_item,
                            straight_bpm      -- pre-rounded BPM from Python (if straight)
                        )
                    else
                        msg("No BPM list for path " .. tostring(info.path) .. ", skipping tempo map.")
                    end


                    reaper.SetMediaItemTakeInfo_Value(take, "D_PLAYRATE", 1.0)
                    reaper.UpdateItemInProject(item)

                elseif apply_type == "stretch_item" then

                    ShareStretchMarkers(
                        take,
                        src_times,
                        src_beats,
                        item_pos,
                        anchor_qn,
                        used_idx,
                        beats_per_bar,
                        use_straight_for_this_item,
                        straight_bpm,    -- from JSON bpms_list (already rounded in Python)
                        set_snap_offset
                    )


                else
                    msg("Unknown APPLY_TYPE: " .. tostring(apply_type))
                end
            else
                msg("No src_times for path: " .. tostring(info.path) .. ", skipping.")
            end
        end
    end

    reaper.Undo_EndBlock("Import Ableton warp grid (" .. apply_type .. ")", -1)
end

-----------------------------------------
-- IMGUI SETUP
-----------------------------------------

local ctx = ImGui.CreateContext(SCRIPT_NAME)
-- Add MenuBar flag so BeginMenuBar works
local window_flags =
    ImGui.WindowFlags_AlwaysAutoResize +
    ImGui.WindowFlags_MenuBar

local apply_combo_width         = nil
local straight_mode_combo_width = nil
local snap_mode_combo_width     = nil
local combo_widths_initialized  = false

local function HelpMarker(desc)
    ImGui.SameLine(ctx)
    ImGui.TextDisabled(ctx, "(?)")
    if ImGui.IsItemHovered(ctx) and ImGui.BeginTooltip(ctx) then
        ImGui.PushTextWrapPos(ctx, ImGui.GetFontSize(ctx) * 35.0)
        ImGui.Text(ctx, desc)
        ImGui.PopTextWrapPos(ctx)
        ImGui.EndTooltip(ctx)
    end
end

local function FindOptionIndex(options, value)
    for i, opt in ipairs(options) do
        if opt.value == value then
            return i
        end
    end
    return 1  -- fallback to first option if value is invalid
end

local function OpenURL(url)
    local os_str = reaper.GetOS()

    if os_str:match("Win") then
        -- Windows
        -- ^& escaping is only needed if you know you'll have & in the URL and want to be extra safe
        os.execute('start "" "' .. url .. '"')
    elseif os_str:match("OSX") then
        -- macOS
        os.execute('open "' .. url .. '"')
    else
        -- Linux / other UNIX
        os.execute('xdg-open "' .. url .. '"')
    end
end

local function InitComboWidths()
    -- Apply type: find longest label or label
    local max_w = 0
    for _, opt in ipairs(APPLY_TYPE_OPTIONS) do
        local w1 = ({ ImGui.CalcTextSize(ctx, opt.label) })[1]
        local w2 = ({ ImGui.CalcTextSize(ctx, opt.label) })[1]
        if w1 > max_w then max_w = w1 end
        if w2 > max_w then max_w = w2 end
    end
    apply_combo_width = max_w + 40  -- padding for arrow + margins

    -- Straight tempo: same idea
    max_w = 0
    for _, opt in ipairs(STRAIGHT_TEMPO_OPTIONS) do
        local w1 = ({ ImGui.CalcTextSize(ctx, opt.label) })[1]
        local w2 = ({ ImGui.CalcTextSize(ctx, opt.label) })[1]
        if w1 > max_w then max_w = w1 end
        if w2 > max_w then max_w = w2 end
    end
    straight_mode_combo_width = max_w + 40

    -- Snap mode: same idea
    max_w = 0
    for _, opt in ipairs(SNAP_MODE_OPTIONS) do
        local w1 = ({ ImGui.CalcTextSize(ctx, opt.label) })[1]
        local w2 = ({ ImGui.CalcTextSize(ctx, opt.label) })[1]
        if w1 > max_w then max_w = w1 end
        if w2 > max_w then max_w = w2 end
    end
    snap_mode_combo_width = max_w + 40

    combo_widths_initialized = true
end

local function loop()
    ImGui.SetNextWindowSize(ctx, 430, 230, ImGui.Cond_FirstUseEver)
    local visible, open = ImGui.Begin(ctx, SCRIPT_NAME, true, window_flags)

    if visible then
        if not combo_widths_initialized then
            InitComboWidths()
        end

        if ImGui.BeginMenuBar(ctx) then
            if ImGui.BeginMenu(ctx, "Links") then
                if ImGui.MenuItem(ctx, "Reaper Forum Thread (help & talk)") then
                    OpenURL("http://www.documentation-link.com") -- TODO: real link
                end
                if ImGui.MenuItem(ctx, "Donate") then
                    OpenURL("http://www.donation-link.com") -- TODO
                end
                if ImGui.MenuItem(ctx, "Contact") then
                    OpenURL("https://lnk.bio/reahipox")
                end
                ImGui.EndMenu(ctx)
            end
            ImGui.EndMenuBar(ctx)
        end

        -- APPLY_TYPE combo
        -- "Apply type" label + help marker
        ImGui.Text(ctx, "Apply type")
        HelpMarker(
[[Stretch item:
- Keeps the existing REAPER tempo map.
- Writes Ableton warp markers as stretch markers into the item.
- Good when you want to warp the audio to match the current grid.

Quantize grid:
- Uses Ableton BPM/grid info to insert tempo markers into REAPER
so the *project grid* matches the warped audio.
- Best used when the item playback rate is 1.0 (rate slider = 1.000).
- If you don't want items moving with tempo changes, consider setting
the track or project timebase to "Time" before running this mode.
]])

        -- APPLY_TYPE combo (label is hidden by using ##)
        -- figure out current index + label
        local apply_idx = FindOptionIndex(APPLY_TYPE_OPTIONS, apply_type)
        local apply_opt = APPLY_TYPE_OPTIONS[apply_idx]
        local apply_label = apply_opt.label
        
        if apply_combo_width then
            ImGui.SetNextItemWidth(ctx, apply_combo_width)
        end
        
        if ImGui.BeginCombo(ctx, "##ApplyTypeCombo", apply_label) then
            for i, opt in ipairs(APPLY_TYPE_OPTIONS) do
                local is_selected = (opt.value == apply_type)
                if ImGui.Selectable(ctx, opt.label, is_selected) then
                    apply_type = opt.value
                    save_ext_str("APPLY_TYPE", apply_type)
                end
            end
            ImGui.EndCombo(ctx)
        end


        -- Toggle options
        local changed

        changed, use_straight_grid = ImGui.Checkbox(
            ctx,
            "Prefer straight grid when available",
            use_straight_grid
        )
        if changed then
            save_ext_bool("USE_STRAIGHT_GRID", use_straight_grid)
        end
        HelpMarker(
[[When enabled:
- If the Python analysis detected a stable straight BPM (either warped as "Straight" in Ableton or detected as such),
    the script will treat that file as straight-tempo.
- Stretch mode will use straight BPM behaviour (stretch_markers / playrate modes).
- Quantize mode will insert a single clean tempo marker at that BPM.

When disabled:
- Even if a straight BPM was detected, the script will use the full variable BPM grid.
]])
        
        -- Snap mode (always relevant, affects how items are placed on the grid)

        -- Straight tempo mode (only relevant for stretch_item)
        if apply_type == "stretch_item" and use_straight_grid then
            -- Straight tempo mode (for clips flagged as straight in JSON)
            -- ImGui.Separator(ctx)
            ImGui.Text(ctx, "Straight tempo mode")

            -- current index + label
            local mode_idx = FindOptionIndex(STRAIGHT_TEMPO_OPTIONS, straight_tempo_mode)
            local mode_opt = STRAIGHT_TEMPO_OPTIONS[mode_idx]
            local mode_label = mode_opt.label

            if straight_mode_combo_width then
                ImGui.SetNextItemWidth(ctx, straight_mode_combo_width)
            end
            if ImGui.BeginCombo(ctx, "##StraightTempoMode", mode_label) then
                for i, opt in ipairs(STRAIGHT_TEMPO_OPTIONS) do
                    local is_selected = (opt.value == straight_tempo_mode)
                    if ImGui.Selectable(ctx, opt.label, is_selected) then
                        straight_tempo_mode = opt.value
                        save_ext_str("STRAIGHT_TEMPO_MODE", straight_tempo_mode)
                    end
                end
                ImGui.EndCombo(ctx)
            end

            -- When using straight grid + playrate mode,
            -- allow user to define beats_per_bar (must be >= 1).
            ImGui.Text(ctx, "Beats per bar")
            HelpMarker(
[[Number of beats in one bar for straight tempo in playrate mode.

Examples:
- 4  → standard 4/4 bar
- 3  → 3/4 feel
- 5+ → odd meters

Must be 1 or higher.]])

            ImGui.SetNextItemWidth(ctx, 80)
            local changed_int
            changed_int, beats_per_bar = ImGui.InputInt(
                ctx,
                "##BeatsPerBar",
                beats_per_bar,
                1, 4
            )

            if changed_int then
                if beats_per_bar < 1 then
                    beats_per_bar = 1
                end
                save_ext_str("BEATS_PER_BAR", beats_per_bar)
            end
        end

        ImGui.Separator(ctx)

        changed, mark_item_edges = ImGui.Checkbox(ctx, "Mark item edges as take markers before processing", mark_item_edges)
        if changed then
            save_ext_bool("MARK_ITEM_EDGES", mark_item_edges)
        end

        HelpMarker(
[[REAPER can change the start/end edges of items during processing.

When this option is enabled:
- The script inserts two take markers (__EDGE_START / __EDGE_END)
    at the exact visible item boundaries BEFORE processing.
- This lets you see precisely which part of the source was visible before the processing.]])

        ImGui.Text(ctx, "Snap first visible beat to")
        HelpMarker(
[[Controls where the first visible warp marker lands on the grid:

Nearest grid line (QN):
- Snap to the nearest quarter-note grid position.
- Original behaviour.

First beat of next bar or current bar:
- Always pushes the item forward to the next bar start or stays at the current bar start if already there.

Nearest bar:
- Chooses the closest bar start, but won't move the item start before 0.0.
]])

        local snap_idx  = FindOptionIndex(SNAP_MODE_OPTIONS, snap_mode)
        local snap_opt  = SNAP_MODE_OPTIONS[snap_idx]
        local snap_label = snap_opt.label

        if snap_mode_combo_width then
            ImGui.SetNextItemWidth(ctx, snap_mode_combo_width)
        end

        if ImGui.BeginCombo(ctx, "##SnapModeCombo", snap_label) then
            for i, opt in ipairs(SNAP_MODE_OPTIONS) do
                local is_selected = (opt.value == snap_mode)
                if ImGui.Selectable(ctx, opt.label, is_selected) then
                    snap_mode = opt.value
                    save_ext_str("SNAP_MODE", snap_mode)
                end
            end
            ImGui.EndCombo(ctx)
        end

        changed, set_snap_offset = ImGui.Checkbox(ctx, "Set snap offset to first visible marker", set_snap_offset)
        if changed then
            save_ext_bool("SET_SNAP_OFFSET", set_snap_offset)
        end

        ------------------------------------------------------------
        -- Ableton executable path (optional)
        ------------------------------------------------------------
        ImGui.Separator(ctx)
        ImGui.Text(ctx, "Ableton executable / app (optional)")
        HelpMarker(
[[Optional path to Ableton Live executable (.exe) or app (.app).

If left empty:
- The Python script will open the .als file with the system default
  application for .als (usually Ableton Live).

If set:
- The script will first try to launch Ableton using this path.
- If it fails or is invalid, it falls back to the default behaviour.

Examples:
- Windows:  C:\ProgramData\Ableton\Live 12 Suite\Program\Ableton Live 12 Suite.exe
- macOS:    /Applications/Ableton Live 11 Suite.app
- Linux/Wine:  /home/user/.wine/drive_c/.../Ableton Live 11 Suite.exe
]])

        -- Path input + Browse button on same line
        local input_width = 280
        ImGui.SetNextItemWidth(ctx, input_width)
        local changed_path
        changed_path, ableton_exe_path = ImGui.InputText(
            ctx,
            "##AbletonExePath",
            ableton_exe_path or ""
        )
        if changed_path then
            save_ext_str("ABLETON_EXE_PATH", ableton_exe_path)
        end

        ImGui.SameLine(ctx)
        if ImGui.Button(ctx, "Browse...", 90, 0) then
            -- Start in current path if set, otherwise in script folder
            local initial = (ableton_exe_path ~= "" and ableton_exe_path) or script_path
            local retval, file = reaper.GetUserFileNameForRead(
                initial,
                "Select Ableton executable / app",
                ""
            )
            if retval and file and file ~= "" then
                ableton_exe_path = file
                save_ext_str("ABLETON_EXE_PATH", ableton_exe_path)
            end
        end        

        ImGui.Separator(ctx)
        ImGui.Text(ctx, "Actions (work on currently selected items)")
        ImGui.Spacing(ctx)

        -- Button 1: create/open Ableton set
        if ImGui.Button(ctx, "1) Create & open Ableton set from selection", -1, 0) then
            Action_CreateAbletonSetFromSelection()
        end

        ImGui.Spacing(ctx)

        -- Button 2: apply beatgrid
        if ImGui.Button(ctx, "2) Apply Ableton beatgrid to selected items", -1, 0) then
            Action_ApplyAbletonBeatgridToSelection()
        end

        ImGui.End(ctx)
    end

    if open then
        reaper.defer(loop)
    else
        -- ImGui.DestroyContext(ctx)
    end
end

reaper.defer(loop)
