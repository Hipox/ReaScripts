--[[
@description Ableton Grids
@author Hipox
@version 1.0.14
@changelog
    + little text update
@links
    GitHub Repository https://github.com/Hipox/ReaScripts
    Forum Thread https://forum.cockos.com/showthread.php?p=2907984#post2907984
@donation https://lnk.bio/hipox
@about
    GUI tool that extracts beat grids from Ableton Live .als
    projects and creates custom Ableton sets from REAPER items.
@provides
    [main] Hipox - Ableton Grids.lua
    create_custom_ableton_set_and_open.py
    ableton_extract_grid.py
    ../../Libraries/json.lua
    Reaper_Warp_Template_modified Project/**/*

Requires:
    - ReaImGui extension
    - ableton_extract_grid.py
    - create_custom_ableton_set_and_open.py
    - json.lua
    - Python installed and available in PATH
    - Ableton Live 11+ (for creating sets and extracting grids)
--]]
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

MARKER_SPACING_OPTIONS = {
    {
        value = 0,
        label = "First & last visible marker",
    },
    {
        value       = 1,
        label = "1 bar",
    },
    {
        value       = 2,
        label = "2 bars",
    },
    {
        value       = 4,
        label = "4 bars",
    },
    {
        value       = 8,
        label = "8 bars",
    },
    {
        value       = 16,
        label = "16 bars",
    },
    {
        value       = 32,
        label = "32 bars",
    },
    {
        value       = 64,
        label = "64 bars",
    },
    {
        value       = 128,
        label = "128 bars",
    },
    {
        value       = 256,
        label = "256 bars",
    },
}


local STRAIGHT_TEMPO_OPTIONS = {
    {
        value       = "stretch_markers",
        label = "Stretch markers",
    },
    {
        value       = "playrate",
        label = "Playrate (experimental)",
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

local hm_apply_type =
[[Stretch item:
- Keeps the existing REAPER tempo map.
- Writes Ableton warp markers as stretch markers into the item.
- Good when you want to warp the audio to match the current grid.

Quantize project grid:
- Uses Ableton BPM/grid info to insert tempo markers into REAPER
    so the *project grid* matches the warped audio.
- Best used when the item playback rate is 1.0 (rate slider = 1.000).
- If you don't want items moving with tempo changes, consider setting   
    the track or project timebase to "Time" before running this mode.]]

local hm_insert_time_sig =
[[When enabled:
- The script will insert a time signature marker
    at the same position as the first visible stretch/tempo marker created
    based on information from Ableton for each processed item.
- The time-signature uses the numerator/denumerator values from the JSON
    (e.g. 4/4, 3/4, 7/8).

When disabled:
- No time signature markers are inserted.]]

local hm_use_straight_grid =
[[When enabled:
- If the Python analysis detected a stable straight BPM (either warped as "Straight" in Ableton or detected as such),
    the script will treat that file as straight-tempo.
- Stretch mode will use straight BPM behaviour (stretch_markers / playrate modes).
- Quantize mode will insert a single clean tempo marker at that BPM.

When disabled:
- Even if a straight BPM was detected, the script will use the full variable BPM grid.]]

local hm_straight_tempo_mode =
[[If straight tempo is detected, you can choose how to apply it:
Stretch markers:
- The script will create stretch markers at regular intervals
    according to the straight BPM.
Playrate (experimental):
- The script will set the take playrate to match the straight BPM.
- If not applicable, the script falls back to stretch markers mode.
- This option requires some circumstances to work right, so do not expect it to always be perfect.]]

local hm_mark_item_edges =
[[REAPER can change the start/end edges of items during processing.

When this option is enabled:
- The script inserts two take markers (__EDGE_START / __EDGE_END)
    at the exact visible item boundaries BEFORE processing.
- This lets you see precisely which part of the source was visible before the processing.]]

local hm_snap_mode =
[[Controls where the first visible warp marker lands on the grid:

Nearest grid line (QN):
- Snap to the nearest quarter-note grid position.
- Original behaviour.

First beat of next bar or current bar:
- Always pushes the item forward to the next bar start or stays at the current bar start if already there.

Nearest bar:
- Chooses the closest bar start, but won't move the item start before 0.0.]]

local hm_ableton_path =
[[Optional path to Ableton Live executable (.exe) or app (.app).

If left empty:
- The Python script will open the .als file with the system default
    application for .als (usually Ableton Live).

If set:
- The script will first try to launch Ableton using this path.
- If it fails or is invalid, it falls back to the default behaviour.

Examples:
- Windows:  C:\ProgramData\Ableton\Live 12 Suite\Program\Ableton Live 12 Suite.exe
- macOS:    /Applications/Ableton Live 12 Suite.app
- Linux/Wine:  /home/user/.wine/drive_c/.../Ableton Live 12 Suite.exe]]

local hm_marker_spacing =
[[Ableton by default sets 1 warp marker per bar.
Here you can thin out the grid markers by choosing a spacing:

First & last visible marker = only the first and last warp markers within the item will be created
1 bar  = marker every bar (default) [features every marker provided by default Ableton analysis]
2 bars = marker every 2 bars (bars 1,3,5,...) [features every 2nd marker]
4 bars = marker every 4 bars (bars 1,5,9,...) [features every 4th marker]
8 bars = marker every 8 bars (bars 1,9,17,...) [features every 8th marker]
etc.]]
-----------------------------------------
-- PATHS & GLOBALS
-----------------------------------------

local script_path = ({reaper.get_action_context()})[2]:match('^.*[/\\]'):sub(1,-2)
local sep         = package.config:sub(1,1)
local repo_root = script_path .. sep .. ".." .. sep .. ".."
package.path = repo_root   .. sep .. "Libraries" .. sep .. "?.lua"
    .. ";" .. package.path
    .. ";" .. script_path .. sep .. "?.lua"

local json = require "json"

local python_script_grid  = script_path .. sep .. "ableton_extract_grid.py"
local python_script_set   = script_path .. sep .. "create_custom_ableton_set_and_open.py"
local json_results_path = script_path .. sep ..  "ableton_result.json"

local EXT_SECTION = "Hipox_Ableton_Grids"

local MAX_ITEMS_COUNT = 16

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

local function load_ext_int(key, default)
    local v = reaper.GetExtState(EXT_SECTION, key)
    if v == "" then return default end
    local n = tonumber(v)
    if not n then return default end
    return math.floor(n)
end

local function save_ext_int(key, val)
    reaper.SetExtState(EXT_SECTION, key, tostring(math.floor(val or 0)), true)
end

-- Load config (with defaults)
local apply_type         = load_ext_str("APPLY_TYPE", "stretch_item")     -- "stretch_item" or "quantize_grid"
local set_snap_offset    = load_ext_bool("SET_SNAP_OFFSET", true)
local insert_time_sig    = load_ext_bool("INSERT_TIME_SIG", false)
local mark_item_edges    = load_ext_bool("MARK_ITEM_EDGES", false)
local straight_tempo_mode = load_ext_str("STRAIGHT_TEMPO_MODE", "stretch_markers") -- "stretch_markers" or "playrate"
local snap_mode          = load_ext_str("SNAP_MODE", "nearest_bar")       -- "nearest_qn", "next_bar", "nearest_bar"
local use_straight_grid  = load_ext_bool("USE_STRAIGHT_GRID", false)
local ableton_path = load_ext_str("ABLETON_EXE_PATH", "")
local marker_spacing = load_ext_int("MARKER_SPACING", 1)
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

------------------------------------------------------------
-- Update or create a time-signature marker at target_time.
-- - If a tempo marker exists there (within epsilon), only
--   Num/Den are updated, BPM and shape are preserved.
-- - If none exists, a new marker is created using the
--   current project tempo at that time (so tempo map audio
--   behaviour does not change).
------------------------------------------------------------
local function UpdateOrCreateTimeSigAtPosition(proj, target_time, ts_num, ts_den, epsilon)
    proj    = proj or 0
    epsilon = epsilon or 1e-6
    ts_num  = tonumber(ts_num) or 0
    ts_den  = tonumber(ts_den) or 0

    if not target_time or ts_num <= 0 or ts_den <= 0 then
        return
    end

    -- 1) Try to find an existing marker at this position
    local count = reaper.CountTempoTimeSigMarkers(proj)
    for i = 0, count - 1 do
        local ok, timepos, measurepos, beatpos, bpm, cur_num, cur_den, lineartempo =
            reaper.GetTempoTimeSigMarker(proj, i)

        if ok and math.abs(timepos - target_time) <= epsilon then
            -- Only update Num/Den, keep everything else exactly as is
            reaper.SetTempoTimeSigMarker(
                proj,
                i,
                timepos,    -- unchanged
                measurepos, -- unchanged
                beatpos,    -- unchanged
                bpm,        -- unchanged BPM
                ts_num,     -- new numerator
                ts_den,     -- new denominator
                lineartempo -- unchanged
            )
            return
        end
    end

    -- 2) No marker there → create one, but copy current tempo
    local bpm_here = reaper.TimeMap_GetDividedBpmAtTime(target_time)
    bpm_here = tonumber(bpm_here) or 120
    if bpm_here <= 0 then bpm_here = 120 end

    reaper.SetTempoTimeSigMarker(
        proj,
        -1,
        target_time,
        -1,
        -1,
        0,   -- whatever tempo is already there
        ts_num,
        ts_den,
        false       -- use standard (non-linear) segment
    )
end


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


    -- UpdateOrCreateTimeSigAtPosition(proj, t_proj, ts_num, ts_den)  -- default to 4/4 if needed

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
        -- retval = beats since start of *current* measure
        local beats_since_measure, measures, cml, fullbeats, cdenom =
            reaper.TimeMap2_timeToBeats(proj, t_proj)

        local beats_per_measure = cml
        if not beats_per_measure or beats_per_measure <= 0 then
            beats_per_measure = 4 -- fallback
        end

        -- Correct bar start even if previous measures have different lengths
        local cur_measure_start_beats = fullbeats - beats_since_measure

        -- If the anchor is already (within tolerance) on the bar start,
        -- don't move the item, but DO return a valid anchor_qn so that
        -- downstream stretch/tempo code can anchor correctly.
        local cur_measure_start_time = reaper.TimeMap2_beatsToTime(proj, cur_measure_start_beats)
        
        -- Allow for floating-point noise (about 0.1 ms)
        local epsilon = 1e-4
        if math.abs(t_proj - cur_measure_start_time) <= epsilon then
            local anchor_qn = cur_measure_start_beats  -- beats from TimeMap2_timeToBeats are QN-based
            return old_item_start, anchor_qn, used_index, snap_offset
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
        -- retval = beats since start of *current* measure
        local beats_since_measure, measures, cml, fullbeats, cdenom =
            reaper.TimeMap2_timeToBeats(proj, t_proj)

        local beats_per_measure = cml
        if not beats_per_measure or beats_per_measure <= 0 then
            beats_per_measure = 4 -- fallback
        end

        -- This gives you the correct bar start even across mixed 4/4, 3/4, etc.
        local cur_measure_start_beats = fullbeats - beats_since_measure
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
    -- UpdateOrCreateTimeSigAtPosition(proj, new_item_start + visible_offset, ts_num, ts_den)
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
    use_straight_for_this_item,
    straight_bpm,
    beats_per_bar_quarter,
    set_snap_offset
)
    if not take or type(src_times) ~= "table" or #src_times == 0 then return end

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

        fullbeats = fullbeats or 0
        anchor_qn = math.ceil(fullbeats)
        used_idx  = 1
    end

    ----------------------------------------------------------------
    -- STRAIGHT TEMPO: use JSON flag + straight_bpm (prefer) or src_bpms[1]
    -- IMPORTANT: anchor on src_times[used_idx], i.e. the beat you already
    -- snapped closest to the item edge, NOT always src_times[1] (beat 0).
    ----------------------------------------------------------------
    if use_straight_for_this_item and straight_tempo_mode == "stretch_markers" then

        used_idx = used_idx or 1
        local anchor_src_time = src_times[used_idx] or src_times[1] or 0.0
        local last_src_time   = src_times[#src_times] or anchor_src_time

        if not straight_bpm or straight_bpm <= 0 then
            return
        end

        -- seconds per beat based on BPM
        local sec_per_beat = 60 / straight_bpm

        ------------------------------------------------------------
        -- MARKER SPACING:
        --   marker_spacing = 1 -> marker every bar
        --   marker_spacing = 2 -> marker every 2 bars
        --   marker_spacing = 4 -> marker every 4 bars
        --
        -- beats_per_bar_quarter is in quarter-note beats (e.g. 4 for 4/4, 3 for 3/4, 2.5 for 5/8)
        -- We step in beats by:
        --   step_beats = beats_per_bar_quarter * marker_spacing
        ------------------------------------------------------------
        local first_last_mode = (marker_spacing == 0)

        -- local sec_per_bar = sec_per_beat * beats_per_bar_quarter

        if first_last_mode then
            ------------------------------------------------------------
            -- "First & last marker" mode for straight stretch:
            -- Only set the first and the last marker within the item.
            ------------------------------------------------------------
            local first_set   = false
            local first_dest  = nil
            local first_src   = nil
            local last_dest   = nil
            local last_src    = nil

            local n = 0
            while true do
                local beat_index = anchor_qn + n * beats_per_bar_quarter
                local beat_time  = reaper.TimeMap2_beatsToTime(proj, beat_index)
                local destpos    = beat_time - item_pos

                if destpos < -1e-6 then
                    n = n + 1
                else
                    if destpos > item_len + 1e-6 then
                        break
                    end

                    local src_time = anchor_src_time + (n * beats_per_bar_quarter) * sec_per_beat

                    -- NEW: stop once we step beyond the straight source span
                    if src_time > last_src_time + 1e-6 then
                        break
                    end

                    if not first_set then
                        first_set  = true
                        first_dest = destpos
                        first_src  = src_time
                    else
                        last_dest  = destpos
                        last_src   = src_time
                    end

                    n = n + 1
                end
            end

            if first_set and first_dest and first_src then
                reaper.SetTakeStretchMarker(take, -1, first_dest, first_src)
                if last_dest and last_src and math.abs(last_dest - first_dest) > 1e-6 then
                    reaper.SetTakeStretchMarker(take, -1, last_dest, last_src)
                end
            end

            reaper.UpdateArrange()
            return
        else
            ------------------------------------------------------------
            -- Normal straight grid spacing: every N bars.
            ------------------------------------------------------------
            local step_beats = beats_per_bar_quarter * marker_spacing

            local n = 0
            while true do
                local beat_index = anchor_qn + n * step_beats
                local beat_time  = reaper.TimeMap2_beatsToTime(proj, beat_index)
                local destpos    = beat_time - item_pos

                if destpos < -1e-6 then
                    n = n + 1
                else
                    if destpos > item_len + 1e-6 then
                        break
                    end

                    local src_time = anchor_src_time + (n * step_beats) * sec_per_beat

                    -- NEW: don't generate markers beyond source end
                    if src_time > last_src_time + 1e-6 then
                        break
                    end

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
    -- Also respect marker_spacing if we know beats_per_bar_quarter.
    ----------------------------------------------------------------
    local beat0 = (src_beats and src_beats[used_idx]) or 0

    local spacing = tonumber(marker_spacing) or 1
    local first_last_mode = (spacing == 0)
    if spacing < 1 then spacing = 1 end

    if first_last_mode then
        ------------------------------------------------------------
        -- "First & last marker" mode for variable grid stretch:
        -- Walk ALL variable markers, then only keep the first and
        -- last ones that actually fall inside the item, similar
        -- to the straight-grid logic.
        ------------------------------------------------------------
        local first_dest, first_src = nil, nil
        local last_dest,  last_src  = nil, nil
    
        if used_idx and used_idx >= 1 and used_idx <= #src_times then
            for i = 1, #src_times do
                local src_time  = src_times[i]
                local this_beat = (src_beats and src_beats[i]) or (beat0 + (i - used_idx))
    
                local delta_beats = this_beat - beat0
                local beat_index  = anchor_qn + delta_beats
    
                local beat_time   = reaper.TimeMap2_beatsToTime(proj, beat_index)
                local destpos     = beat_time - item_pos
    
                -- Mimic the straight version: only consider markers that
                -- actually sit inside the item (with a small epsilon).
                if destpos >= -1e-6 and destpos <= item_len + 1e-6 then
                    if not first_dest then
                        -- First valid marker inside the item
                        first_dest, first_src = destpos, src_time
                    else
                        -- Keep updating "last" as we walk forward
                        last_dest,  last_src  = destpos, src_time
                    end
                end
            end
        end
    
        -- Set markers like in the straight version
        if first_dest and first_src then
            reaper.SetTakeStretchMarker(take, -1, first_dest, first_src)
    
            if last_dest and last_src
               and math.abs(last_dest - first_dest) > 1e-6 then
                reaper.SetTakeStretchMarker(take, -1, last_dest, last_src)
            end
        end
    
        reaper.UpdateArrange()
        return
    else
        ------------------------------------------------------------
        -- Normal thinning: keep anchor, last, and bars matching spacing.
        ------------------------------------------------------------
        for i = 1, #src_times do
            local src_time  = src_times[i]
            local this_beat = (src_beats and src_beats[i]) or (beat0 + (i - used_idx))

            if beats_per_bar_quarter and beats_per_bar_quarter > 0 then
                local bar_idx = math.floor((this_beat - beat0) / beats_per_bar_quarter + 0.0001)

                local is_anchor = (i == used_idx)
                local is_last   = (i == #src_times)

                if (bar_idx % spacing ~= 0) and (not is_anchor) and (not is_last) then
                    goto continue_stretch
                end
            end

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

            ::continue_stretch::
        end

        reaper.UpdateArrange()
        return
    end
end
-----------------------------------------
-- TEMPO GRID FROM BPM LIST
-----------------------------------------

local function ApplyBPMListToBeats(bpms, times, beats, item, start_index, clear_in_item, use_straight_for_this_item, straight_bpm, beats_per_bar_quarter)
    local proj = 0
    if not item then return end
    
    if type(bpms) ~= "table" or #bpms == 0 then return end
    if type(times) ~= "table" or #times == 0 then return end

    start_index   = start_index or 1
    clear_in_item = (clear_in_item ~= false)

    local take = reaper.GetActiveTake(item)
    if not take then return end

    -- Freeze item in absolute time while we manipulate the tempo map
    local orig_attachmode = reaper.GetMediaItemInfo_Value(item, "C_BEATATTACHMODE")
    reaper.SetMediaItemInfo_Value(item, "C_BEATATTACHMODE", 0)  -- 0 = time

    local function RestoreAttachMode()
        if orig_attachmode ~= nil then
            reaper.SetMediaItemInfo_Value(item, "C_BEATATTACHMODE", orig_attachmode)
        end
    end

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
    local last_src_time   = times[last_idx] or anchor_src_time
    local anchor_time     = item_pos + (anchor_src_time - startoffs) / playrate

    ----------------------------------------------------------------
    -- IMPORTANT FIX:
    -- After deleting tempo markers inside the item, the time↔QN map
    -- can shift slightly. Re-snap anchor_time to the current grid
    -- so the first tempo marker (and straight grid) sit exactly
    -- on a REAPER grid line.
    ----------------------------------------------------------------
    do
        local qn_anchor = reaper.TimeMap2_timeToQN(proj, anchor_time)
        anchor_time     = reaper.TimeMap2_QNToTime(proj, math.floor(qn_anchor + 0.5))
    end
    -- anchor_time is now exactly on the project grid.
    -- SPECIAL CASE: marker_spacing == 0 → "First & last marker" mode
    -- For tempo grid, this means: only set a single tempo marker at anchor_time.
    local spacing_mode_first_last = (marker_spacing == 0)

    if spacing_mode_first_last and straight_bpm and straight_bpm > 0 then
        local bpm

        if use_straight_for_this_item and straight_bpm and straight_bpm > 0 then
            bpm = straight_bpm
        else
            -- Fallback: first positive BPM in range, or 120 as a safety default
            for i = first_idx, last_idx do
                local b = bpms[i]
                if b and b > 0 then
                    bpm = b
                    break
                end
            end
            if not bpm then bpm = 120 end
        end

        -- First marker: at anchor_time (already snapped to grid)
        local first_time = anchor_time

        -- Last marker: project the last visible warp time from the same anchor
        local last_time  = nil
        if last_src_time and last_src_time > anchor_src_time + 1e-9 then
            local src_delta = last_src_time - anchor_src_time
            last_time = anchor_time + src_delta / playrate
        end

        -- Insert tempo at first visible marker
        reaper.SetTempoTimeSigMarker(
            proj,
            -1,
            first_time,
            -1,
            -1,
            bpm,
            0,
            0,
            false
        )
        
        -- Last marker keeps whatever time sig already exists (0,0)
        if last_time and math.abs(last_time - first_time) > 1e-6 then
            reaper.SetTempoTimeSigMarker(
                proj,
                -1,
                last_time,
                -1,
                -1,
                bpm,
                0,
                0,
                false
            )
        end

        RestoreAttachMode()
        reaper.UpdateTimeline()
        return
    end

    ----------------------------------------------------------------
    -- 3) STRAIGHT GRID: use Python's decision + BPM from JSON
    --    When marker_spacing > 0, insert straight tempo markers every N bars.
    --    (marker_spacing == 0 is handled above as "First & last marker".)
    ----------------------------------------------------------------
    if use_straight_for_this_item then

        if not straight_bpm or straight_bpm <= 0 then
            RestoreAttachMode()
            reaper.UpdateTimeline()
            return
        end

        local spacing = tonumber(marker_spacing) or 1
        if spacing < 1 then spacing = 1 end

        local bpb = beats_per_bar_quarter or 4
        local sec_per_bar = (60.0 / straight_bpm) * bpb

        -- Re-read item position/length in case they shifted slightly
        local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        local item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
        local item_end = item_pos + item_len

        ----------------------------------------------------------------
        -- NEW: limit the straight grid by the visible source span.
        -- Anchor: anchor_src_time  ->  anchor_time
        -- Last  : last_src_time    ->  straight_end_time
        ----------------------------------------------------------------
        local visible_src_duration = math.max(0, (last_src_time or anchor_src_time) - anchor_src_time)
        local straight_end_time    = anchor_time + visible_src_duration

        -- Final limit: never go beyond the current item end OR the
        -- musical end implied by the warp/source data.
        local limit_end = math.min(item_end, straight_end_time)

        local t0 = anchor_time
        local k  = 0

        while true do
            local timepos = t0 + k * sec_per_bar * spacing
            if timepos > limit_end + 1e-6 then
                break
            end

            reaper.SetTempoTimeSigMarker(
                proj,
                -1,
                timepos,
                -1,
                -1,
                straight_bpm,
                0,
                0,
                false
            )

            k = k + 1
        end

        RestoreAttachMode()
        reaper.UpdateTimeline()
        return
    end



    ----------------------------------------------------------------
    -- 4) GENERAL CASE (multi-BPM / non-straight analysis)
    --    Marker spacing: compute a single BPM per N-bar chunk.
    ----------------------------------------------------------------
    local qn        = reaper.TimeMap2_timeToQN(proj, anchor_time)
    local anchor_qn = math.floor(qn + 0.5)

    local beats_tbl = (type(beats) == "table") and beats or nil
    local beat0     = (beats_tbl and beats_tbl[first_idx]) or 0

    local spacing = tonumber(marker_spacing) or 1
    if spacing < 1 then spacing = 1 end

    ----------------------------------------------------------------
    -- CASE A: no usable bar info or spacing == 1 → original behaviour
    ----------------------------------------------------------------
    if spacing == 1 or (not beats_tbl) or not beats_per_bar_quarter or beats_per_bar_quarter <= 0 then
        for i = first_idx, last_idx do
            local bpm = bpms[i]
            if bpm and bpm > 0 then
                local this_beat   = (beats_tbl and beats_tbl[i]) or (beat0 + (i - first_idx))
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

        RestoreAttachMode()
        reaper.UpdateTimeline()
        return
    end

    ----------------------------------------------------------------
    -- CASE B: spacing > 1 and we know beats_per_bar_quarter
    -- Strategy:
    --   1) Choose "kept" warp indices at bar multiples (0, N, 2N, ...).
    --   2) For each consecutive pair (i0 -> i1) of kept indices, compute
    --        BPM_chunk = 60 * (Δbeats / Δtime)
    --      using times + beats over that whole block.
    --   3) Insert a tempo marker at the start of each block.
    ----------------------------------------------------------------
    local bpb = beats_per_bar_quarter

    -- 1) Build list of indices we keep as block boundaries
    local kept = {}

    for i = first_idx, last_idx do
        local this_beat = beats_tbl[i] or (beat0 + (i - first_idx))

        if i == first_idx then
            -- Always keep the first visible marker
            table.insert(kept, i)
        else
            local bar_idx = math.floor((this_beat - beat0) / bpb + 0.0001)

            -- Keep markers on bar multiples, and also ensure we keep
            -- the last one so we can form the final chunk.
            if (bar_idx % spacing == 0) or (i == last_idx) then
                table.insert(kept, i)
            end
        end
    end

    if #kept < 2 then
        -- Not enough points to form at least one chunk → fallback to full resolution
        for i = first_idx, last_idx do
            local bpm = bpms[i]
            if bpm and bpm > 0 then
                local this_beat   = (beats_tbl and beats_tbl[i]) or (beat0 + (i - first_idx))
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

        RestoreAttachMode()
        reaper.UpdateTimeline()
        return
    end

    ----------------------------------------------------------------
    -- 2) For each chunk [kept[k] .. kept[k+1]], compute BPM and set marker
    ----------------------------------------------------------------
    local last_bpm = nil

    for k = 1, (#kept - 1) do
        local i0 = kept[k]
        local i1 = kept[k+1]

        local b0 = beats_tbl[i0] or (beat0 + (i0 - first_idx))
        local b1 = beats_tbl[i1] or (beat0 + (i1 - first_idx))

        local t0 = times[i0]
        local t1 = times[i1]

        local delta_beats = b1 - b0
        local delta_time  = t1 - t0

        local bpm = last_bpm or 120
        if delta_time > 0 and delta_beats > 0 then
            bpm = 60.0 * (delta_beats / delta_time)
            last_bpm = bpm
        end

        local this_beat  = b0
        local beat_index = anchor_qn + (this_beat - beat0)

        local timepos
        if k == 1 then
            -- First chunk starts exactly at anchor_time
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

        ----------------------------------------------------------------
    -- Optional final marker at the very last warp point
    -- (only makes sense if we had at least one chunk with a BPM).
    ----------------------------------------------------------------
    if last_bpm and last_bpm > 0 then
        local last_i = kept[#kept]

        local b_last = beats_tbl[last_i] or (beat0 + (last_i - first_idx))
        local delta_beats_last = b_last - beat0
        local beat_index_last  = anchor_qn + delta_beats_last

        local timepos_last = reaper.TimeMap2_QNToTime(proj, beat_index_last)

        reaper.SetTempoTimeSigMarker(
            proj,
            -1,
            timepos_last,
            -1,
            -1,
            last_bpm,
            0,
            0,
            false
        )
    end

    RestoreAttachMode()
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
        return
    end

    if #takes > MAX_ITEMS_COUNT then
        msg("Too many selected items (max " .. MAX_ITEMS_COUNT .. ").")
        return
    end

    local args = {}

    -- Only pass flag if user actually set a path
    if ableton_path ~= nil and ableton_path ~= "" then
        table.insert(args, "--ableton_path=" .. ableton_path)
    end

    -- NEW: de-duplicate by normalized path
    local seen = {}
    local unique_paths = {}

    for _, info in ipairs(takes) do
        local norm = NormalizePath(info.path)
        if not seen[norm] then
            seen[norm] = true
            table.insert(unique_paths, info.path)
        end
    end

    -- Now send only unique paths to Python
    for _, p in ipairs(unique_paths) do
        table.insert(args, p)
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

-- local function ResetWarpAndPlayrate(item, take)
--     if not take or not item then return end

--     -- Remove all stretch markers (warp)
--     local num = reaper.GetTakeNumStretchMarkers(take)
--     for idx = num - 1, 0, -1 do
--         reaper.DeleteTakeStretchMarkers(take, idx)
--     end

--     -- Normalise playrate
--     reaper.SetMediaItemTakeInfo_Value(take, "D_PLAYRATE", 1.0)
--     reaper.UpdateItemInProject(item)
-- end

local function CreateTimeSigInserter(proj, anchor_time, insert_time_sig, ts_num, ts_den)
    proj            = proj or 0
    insert_time_sig = (insert_time_sig == true)

    local ts_num_val = tonumber(ts_num) or 0
    local ts_den_val = tonumber(ts_den) or 0
    if ts_num_val <= 0 or ts_den_val <= 0 then
        insert_time_sig = false
    end

    anchor_time = tonumber(anchor_time)

    return function()
        if not insert_time_sig then return end
        if not anchor_time then return end
        insert_time_sig = false -- only once per item

        UpdateOrCreateTimeSigAtPosition(proj, anchor_time, ts_num_val, ts_den_val)
    end
end

local function ResetWarpAndPlayrate(item, take)
    if not take or not item then return end

    ------------------------------------------------------------
    -- 1) Capture the currently visible source region
    --    src_start = startoffs
    --    src_end   = startoffs + item_len * playrate
    ------------------------------------------------------------
    local startoffs   = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
    local old_len     = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    local old_rate    = reaper.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE")

    if old_rate == 0 then
        old_rate = 1.0
    end

    local src_start = startoffs
    local src_end   = src_start + old_len * old_rate

    ------------------------------------------------------------
    -- 2) Remove all stretch markers (warp)
    ------------------------------------------------------------
    local num = reaper.GetTakeNumStretchMarkers(take)
    for idx = num - 1, 0, -1 do
        reaper.DeleteTakeStretchMarkers(take, idx)
    end

    ------------------------------------------------------------
    -- 3) Normalise playrate to 1.0, but adjust item length so
    --    that the same [src_start, src_end] portion of the
    --    source remains visible after the reset.
    ------------------------------------------------------------
    local new_rate = 1.0
    local new_len  = src_end - src_start
    if new_len < 0 then new_len = 0 end

    reaper.SetMediaItemTakeInfo_Value(take, "D_PLAYRATE", new_rate)
    reaper.SetMediaItemInfo_Value(item, "D_LENGTH", new_len)

    reaper.UpdateItemInProject(item)
end

local function Action_ApplyAbletonBeatgridToSelection()
    if not verify_file_exists(python_script_grid) then
        msg("Python script not found: " .. python_script_grid)
        return
    end

    local takes = CollectSelectedAudioActiveTakes()
    if #takes == 0 then
        -- msg("No selected audio items with active takes found.")
        return
    end

    local args = {}

    for _, info in ipairs(takes) do
        table.insert(args, info.path)
    end

    local output = send_array_to_python_script(python_script_grid, args)

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

    local paths_list                 = data["paths_list"]
    local times_list                 = data["times_list"]
    local beats_list                 = data["beats_list"]
    local bpms_list                  = data["bpms_list"]
    local straight_bpm_list          = data["straight_bpm_list"]
    local time_sig_num_list          = data["time_sig_num_list"]
    local time_sig_den_list          = data["time_sig_den_list"]

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
                    times                 = (type(times_list)                 == "table" and times_list[idx])                 or nil,
                    beats                 = (type(beats_list)                 == "table" and beats_list[idx])                 or nil,
                    bpms                  = (type(bpms_list)                  == "table" and bpms_list[idx])                  or nil,
                    straight_bpm          = (type(straight_bpm_list)          == "table" and straight_bpm_list[idx])          or nil,
                    time_sig_num          = (type(time_sig_num_list)          == "table" and time_sig_num_list[idx])          or nil,
                    time_sig_den          = (type(time_sig_den_list)          == "table" and time_sig_den_list[idx])          or nil,
                }
            end

        end
    end


    if next(path_map) == nil then
        msg("No valid path entries in JSON.")
        return
    end

    reaper.Undo_BeginBlock()

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
            local ts_num = tonumber(entry.time_sig_num) or 4
            local ts_den = tonumber(entry.time_sig_den) or 4
            local beats_per_bar_quarter = ts_num * (4 / ts_den)

            local use_straight_for_this_item = (use_straight_grid and straight_bpm > 0)

            if src_times and type(src_times) == "table" and #src_times > 0 then

                if mark_item_edges then
                    MarkItemEdgesAsTakeMarkers(take)
                end

                ResetWarpAndPlayrate(item, take)
            
                local item_pos, anchor_qn, used_idx, snap_offset =
                    SnapItemToGridByTimesArray(item, src_times, snap_mode, set_snap_offset)

                -- Anchor the time-signature exactly where the item snaps:
                -- item_pos (current item start) + snap_offset (triangle) when available.
                local anchor_time

                if snap_offset ~= nil then
                    -- Snap offset is in seconds from item start
                    anchor_time = (item_pos or 0) + snap_offset
                elseif type(anchor_qn) == "number" then
                    -- Fallback: derive from the musical position
                    anchor_time = reaper.TimeMap2_QNToTime(0, anchor_qn)
                else
                    -- Last fallback: use item start
                    anchor_time = item_pos
                end

                local MaybeInsertTimeSig = CreateTimeSigInserter(
                    0,
                    anchor_time,
                    insert_time_sig,
                    ts_num,
                    ts_den
                )


                -- MaybeInsertTimeSig()

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
                            straight_bpm,      -- pre-rounded BPM from Python (if straight)
                            beats_per_bar_quarter
                        )

                        if MaybeInsertTimeSig then
                            MaybeInsertTimeSig()
                        end
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
                        use_straight_for_this_item,
                        straight_bpm,          -- from JSON (already rounded in Python)
                        beats_per_bar_quarter, -- now derived from Num/Den
                        set_snap_offset
                    )

                    if MaybeInsertTimeSig then
                        MaybeInsertTimeSig()
                    end

                else
                    msg("Unknown APPLY_TYPE: " .. tostring(apply_type))
                end
            else
                -- msg("No src_times for path: " .. tostring(info.path) .. ", skipping.")
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
local marker_spacing_combo_width  = nil
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

    -- Marker spacing: same idea
    max_w = 0
    for _, opt in ipairs(MARKER_SPACING_OPTIONS) do
        local w1 = ({ ImGui.CalcTextSize(ctx, opt.label) })[1]
        local w2 = ({ ImGui.CalcTextSize(ctx, opt.label) })[1]
        if w1 > max_w then max_w = w1 end
        if w2 > max_w then max_w = w2 end
    end
    marker_spacing_combo_width = max_w + 40

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
                    OpenURL("https://forum.cockos.com/showthread.php?p=2907984#post2907984") -- TODO: real link
                end
                if ImGui.MenuItem(ctx, "Social Sites & Donate") then
                    OpenURL("https://lnk.bio/hipox")
                end
                ImGui.EndMenu(ctx)
            end
            ImGui.EndMenuBar(ctx)
        end

        -- Button 1: create/open Ableton set
        if ImGui.Button(ctx, "1) Create & open Ableton set from items selection", -1, 0) then
            Action_CreateAbletonSetFromSelection()
        end

        ImGui.Spacing(ctx)
        ImGui.Separator(ctx)
        ImGui.Spacing(ctx)

        -- APPLY_TYPE combo
        -- "Apply type" label + help marker
        ImGui.Text(ctx, "Apply type")
        HelpMarker(hm_apply_type)

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

        ImGui.Text(ctx, "Marker spacing:")
    
        ImGui.SameLine(ctx)
        local marker_spacing_idx = FindOptionIndex(MARKER_SPACING_OPTIONS, marker_spacing)
        local marker_spacing_opt = MARKER_SPACING_OPTIONS[marker_spacing_idx]
        local marker_spacing_label = marker_spacing_opt.label

        if marker_spacing_combo_width then
            ImGui.SetNextItemWidth(ctx, marker_spacing_combo_width)
        end

        if ImGui.BeginCombo(ctx, "##BarSpacingCombo", marker_spacing_label) then
            for i, opt in ipairs(MARKER_SPACING_OPTIONS) do
                local is_selected = (opt.value == marker_spacing)
                if ImGui.Selectable(ctx, opt.label, is_selected) then
                    marker_spacing = opt.value
                    save_ext_int("MARKER_SPACING", marker_spacing)
                end
            end
            ImGui.EndCombo(ctx)
        end

        HelpMarker(hm_marker_spacing)

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
        HelpMarker(hm_use_straight_grid)
        
        -- Snap mode (always relevant, affects how items are placed on the grid)

        -- Straight tempo mode (only relevant for stretch_item)
        if apply_type == "stretch_item" and use_straight_grid then
            -- Straight tempo mode (for clips flagged as straight in JSON)
            -- ImGui.Separator(ctx)
            ImGui.Text(ctx, "Straight tempo mode")

            HelpMarker(hm_straight_tempo_mode)

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

        end

        -- ImGui.Separator(ctx)

        changed, mark_item_edges = ImGui.Checkbox(ctx, "Mark item edges as take markers before processing", mark_item_edges)
        if changed then
            save_ext_bool("MARK_ITEM_EDGES", mark_item_edges)
        end

        HelpMarker(hm_mark_item_edges)

        ImGui.Text(ctx, "Snap first visible marker to")
        HelpMarker(hm_snap_mode)

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

        changed, insert_time_sig = ImGui.Checkbox(ctx, "Insert time signature to first visible marker", insert_time_sig)
        if changed then
            save_ext_bool("INSERT_TIME_SIG", insert_time_sig)
        end
        HelpMarker(hm_insert_time_sig)

        ------------------------------------------------------------
        -- Ableton executable path (optional)
        ------------------------------------------------------------
        ImGui.Spacing(ctx)
        ImGui.Separator(ctx)
        ImGui.Spacing(ctx)
        ImGui.Text(ctx, "Ableton executable / app (optional)")
        HelpMarker(hm_ableton_path)

        -- Path input + Browse button on same line
        local input_width = 280
        ImGui.SetNextItemWidth(ctx, input_width)
        local changed_path
        changed_path, ableton_path = ImGui.InputText(
            ctx,
            "##AbletonExePath",
            ableton_path or ""
        )
        if changed_path then
            save_ext_str("ABLETON_EXE_PATH", ableton_path)
        end

        ImGui.SameLine(ctx)
        if ImGui.Button(ctx, "Browse...", 90, 0) then
            -- Start in current path if set, otherwise in script folder
            local initial = (ableton_path ~= "" and ableton_path) or script_path
            local retval, file = reaper.GetUserFileNameForRead(
                initial,
                "Select Ableton executable / app",
                ""
            )
            if retval and file and file ~= "" then
                ableton_path = file
                save_ext_str("ABLETON_EXE_PATH", ableton_path)
            end
        end        

        ImGui.Spacing(ctx)
        ImGui.Separator(ctx)
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
