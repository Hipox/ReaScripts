--[[
@description Quantize Existing Stretch Markers to Grid (ImGui)
@author Hipox (derived), modified by GitHub Copilot
@version 1.0.0
@about
  Lightweight standalone tool to snap the first visible stretch marker of the
  first selected *audio* item to the project grid, then quantize the item's
  existing stretch markers to either beats or bars.

  - Works directly on stretch markers already present in the active take.
  - Optionally sets the item snap offset to the first visible stretch marker.
  - Optionally inserts/updates a time signature marker at the first marker.

Requires:
  - ReaImGui extension
--]]

local SCRIPT_NAME = ({reaper.get_action_context()})[2]:match('([^/\\]+)%.lua$')

if not reaper.ImGui_GetBuiltinPath then
  reaper.MB(
    'This script requires ReaImGui.\n\nInstall it via ReaPack, and ensure it is up to date.',
    'Missing ImGui',
    0
  )
  return
end

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua'
local ImGui = require 'imgui' '0.9.1'

local EXT_SECTION = 'HIPOX_QUANTIZE_EXISTING_STRETCH_MARKERS'

local function ext_get(key, default)
  local v = reaper.GetExtState(EXT_SECTION, key)
  if v == nil or v == '' then return default end
  return v
end

local function ext_set(key, value)
  reaper.SetExtState(EXT_SECTION, key, tostring(value), true)
end

local function ext_get_bool(key, default)
  local v = ext_get(key, default and '1' or '0')
  return v == '1' or v == 'true'
end

local function ext_set_bool(key, value)
  ext_set(key, value and '1' or '0')
end

local function ext_get_num(key, default)
  local v = tonumber(ext_get(key, ''))
  if v == nil then return default end
  return v
end

local SNAP_MODE_OPTIONS = {
  { value = 'nearest_qn', label = 'Nearest grid line (QN)' },
  { value = 'next_bar',   label = 'First beat of next bar or current bar' },
  { value = 'nearest_bar',label = 'First beat of nearest bar' },
}

local QUANTIZE_UNIT_OPTIONS = {
  { value = 'beats', label = 'Beats (expects 1 marker per beat)' },
  { value = 'bars',  label = 'Bars (expects 1 marker per bar)' },
}

local snap_mode = ext_get('SNAP_MODE', 'nearest_qn')
local set_snap_offset = ext_get_bool('SET_SNAP_OFFSET', true)
local insert_time_sig = ext_get_bool('INSERT_TIME_SIG', false)
local ts_num = math.floor(ext_get_num('TS_NUM', 4))
local ts_den = math.floor(ext_get_num('TS_DEN', 4))
local quantize_unit = ext_get('QUANTIZE_UNIT', 'beats')
local debug_mode = ext_get_bool('DEBUG_MODE', false)

local status_text = 'Ready.'

local function set_status(text)
  status_text = tostring(text or '')
end

local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function dbg(text)
  if not debug_mode then return end
  reaper.ShowConsoleMsg('[Quantize Stretch Markers] ' .. tostring(text) .. '\n')
end

------------------------------------------------------------
-- Update or create a time-signature marker at target_time.
-- - If a tempo marker exists there (within epsilon), only
--   Num/Den are updated, BPM and shape are preserved.
-- - If none exists, a new marker is created using the
--   current project tempo at that time.
------------------------------------------------------------
local function UpdateOrCreateTimeSigAtPosition(proj, target_time, new_num, new_den, epsilon)
  proj = proj or 0
  epsilon = epsilon or 1e-6
  new_num = tonumber(new_num) or 0
  new_den = tonumber(new_den) or 0

  if not target_time or new_num <= 0 or new_den <= 0 then
    return
  end

  local count = reaper.CountTempoTimeSigMarkers(proj)
  for i = 0, count - 1 do
    local ok, timepos, measurepos, beatpos, bpm, cur_num, cur_den, lineartempo =
      reaper.GetTempoTimeSigMarker(proj, i)

    if ok and math.abs(timepos - target_time) <= epsilon then
      reaper.SetTempoTimeSigMarker(
        proj,
        i,
        timepos,
        measurepos,
        beatpos,
        bpm,
        new_num,
        new_den,
        lineartempo
      )
      return
    end
  end

  local bpm_here = reaper.TimeMap_GetDividedBpmAtTime(target_time)
  bpm_here = tonumber(bpm_here) or 120
  if bpm_here <= 0 then bpm_here = 120 end

  reaper.SetTempoTimeSigMarker(
    proj,
    -1,
    target_time,
    -1,
    -1,
    0, -- keep existing tempo
    new_num,
    new_den,
    false
  )
end

local function get_first_selected_audio_item()
  local item = reaper.GetSelectedMediaItem(0, 0)
  if not item then return nil, 'No selected item.' end

  local take = reaper.GetActiveTake(item)
  if not take then return nil, 'Selected item has no active take.' end
  if reaper.TakeIsMIDI(take) then return nil, 'Selected item is MIDI; this script requires an audio take.' end

  return item, nil
end

local function get_stretch_markers(take)
  local out = {}
  local num = reaper.GetTakeNumStretchMarkers(take)
  for i = 0, num - 1 do
    local ok, pos, srcpos = reaper.GetTakeStretchMarker(take, i)
    if ok then
      local slope = 0
      if reaper.GetTakeStretchMarkerSlope then
        slope = reaper.GetTakeStretchMarkerSlope(take, i) or 0
      end
      out[#out + 1] = { idx = i, pos = pos, srcpos = srcpos, slope = slope }
    end
  end
  return out
end

local function delete_all_stretch_markers(take)
  local num = reaper.GetTakeNumStretchMarkers(take)
  if num <= 0 then return end
  -- delete from end to start
  for i = num - 1, 0, -1 do
    reaper.DeleteTakeStretchMarkers(take, i)
  end
end

local function find_first_visible_marker(markers, item_len)
  for _, m in ipairs(markers) do
    if m.pos ~= nil and m.pos >= -1e-9 and m.pos <= item_len + 1e-9 then
      return m
    end
  end
  return nil
end

-- Returns: new_item_start, anchor_qn, snapped_time
local function SnapItemToGridByMarker(item, marker_pos_in_item, snap_mode_value, set_snap_offset_value)
  local proj = 0

  local old_item_start = reaper.GetMediaItemInfo_Value(item, 'D_POSITION')
  local item_len = reaper.GetMediaItemInfo_Value(item, 'D_LENGTH')

  marker_pos_in_item = tonumber(marker_pos_in_item)
  if not marker_pos_in_item then return nil end

  local t_proj = old_item_start + marker_pos_in_item

  local snap_offset
  if set_snap_offset_value then
    snap_offset = clamp(marker_pos_in_item, 0, item_len)
    reaper.SetMediaItemInfo_Value(item, 'D_SNAPOFFSET', snap_offset)
  end

  local new_item_start, anchor_qn, snapped_time

  if snap_mode_value == 'next_bar' then
    local beats_since_measure, measures, cml, fullbeats = reaper.TimeMap2_timeToBeats(proj, t_proj)

    local beats_per_measure = cml
    if not beats_per_measure or beats_per_measure <= 0 then beats_per_measure = 4 end

    local cur_measure_start_beats = (fullbeats or 0) - (beats_since_measure or 0)
    local cur_measure_start_time = reaper.TimeMap2_beatsToTime(proj, cur_measure_start_beats)

    local epsilon = 1e-4
    if math.abs(t_proj - cur_measure_start_time) <= epsilon then
      anchor_qn = cur_measure_start_beats
      snapped_time = cur_measure_start_time
      return old_item_start, anchor_qn, snapped_time
    end

    anchor_qn = cur_measure_start_beats + beats_per_measure
    snapped_time = reaper.TimeMap2_beatsToTime(proj, anchor_qn)

    if snapped_time < t_proj - 1e-9 then
      anchor_qn = anchor_qn + beats_per_measure
      snapped_time = reaper.TimeMap2_beatsToTime(proj, anchor_qn)
    end

    new_item_start = snapped_time - marker_pos_in_item
    if new_item_start < 0 then new_item_start = 0 end

  elseif snap_mode_value == 'nearest_bar' then
    local beats_since_measure, measures, cml, fullbeats = reaper.TimeMap2_timeToBeats(proj, t_proj)

    local beats_per_measure = cml
    if not beats_per_measure or beats_per_measure <= 0 then beats_per_measure = 4 end

    local cur_measure_start_beats = (fullbeats or 0) - (beats_since_measure or 0)
    local prev_beats = cur_measure_start_beats
    local next_beats = cur_measure_start_beats + beats_per_measure

    local prev_time = reaper.TimeMap2_beatsToTime(proj, prev_beats)
    local next_time = reaper.TimeMap2_beatsToTime(proj, next_beats)

    local prev_start = prev_time - marker_pos_in_item
    local next_start = next_time - marker_pos_in_item

    local prev_valid = (prev_start >= 0)
    local next_valid = true

    if prev_valid and next_valid then
      if math.abs(prev_time - t_proj) <= math.abs(next_time - t_proj) then
        anchor_qn = prev_beats
        snapped_time = prev_time
      else
        anchor_qn = next_beats
        snapped_time = next_time
      end
    elseif prev_valid then
      anchor_qn = prev_beats
      snapped_time = prev_time
    else
      anchor_qn = next_beats
      snapped_time = next_time
    end

    new_item_start = snapped_time - marker_pos_in_item
    if new_item_start < 0 then new_item_start = 0 end

  else
    local qn = reaper.TimeMap2_timeToQN(proj, t_proj)
    anchor_qn = math.floor((qn or 0) + 0.5)

    -- Avoid snapping that would move the item start < 0
    local min_snapped_time = marker_pos_in_item
    local min_qn = reaper.TimeMap2_timeToQN(proj, min_snapped_time)
    if min_qn and anchor_qn < min_qn then
      anchor_qn = math.ceil(min_qn)
    end

    snapped_time = reaper.TimeMap2_QNToTime(proj, anchor_qn)
    new_item_start = snapped_time - marker_pos_in_item
    if new_item_start < 0 then new_item_start = 0 end
  end

  reaper.SetMediaItemInfo_Value(item, 'D_POSITION', new_item_start)
  reaper.UpdateItemInProject(item)

  return new_item_start, anchor_qn, snapped_time
end

local function get_time_sig_at_time(proj, time)
  proj = proj or 0

  local num, den = 4, 4

  if reaper.TimeMap_GetTimeSigAtTime then
    local n, d = reaper.TimeMap_GetTimeSigAtTime(proj, time)
    if n ~= nil then num = n end
    if d ~= nil then den = d end
  else
    -- Fallback: try TimeMap2_timeToBeats
    local _, _, cml, _, cdenom = reaper.TimeMap2_timeToBeats(proj, time)
    if cml ~= nil then num = cml end
    if cdenom ~= nil then den = cdenom end
  end

  num = tonumber(num) or 4
  den = tonumber(den) or 4
  if num <= 0 then num = 4 end
  if den <= 0 then den = 4 end

  return num, den
end

local function get_qn_per_bar_at_time(proj, time)
  local num, den = get_time_sig_at_time(proj, time)
  return num * (4.0 / den)
end

local function get_qn_per_beat_at_time(proj, time)
  local _, den = get_time_sig_at_time(proj, time)
  return 4.0 / den
end

local function QuantizeStretchMarkers(take, markers, anchor_marker, anchor_qn, item_pos, snapped_time, unit)
  local proj = 0

  if not take or not markers or #markers == 0 then return false, 'No stretch markers.' end
  if not anchor_marker then return false, 'No visible stretch marker in item.' end
  if anchor_qn == nil then return false, 'Internal error: missing anchor grid position.' end

  unit = unit or 'beats'

  local anchor_time = snapped_time or (item_pos + (anchor_marker.pos or 0))

  local step_qn
  if unit == 'bars' then
    step_qn = get_qn_per_bar_at_time(proj, anchor_time)
    if not step_qn or step_qn <= 0 then step_qn = 4 end
  else
    step_qn = get_qn_per_beat_at_time(proj, anchor_time)
    if not step_qn or step_qn <= 0 then step_qn = 1 end
  end

  -- IMPORTANT: Stretch markers are ordered by position. If we mutate them
  -- in-place by index, REAPER may re-sort them mid-loop, so later indices
  -- no longer refer to the same marker.
  -- To avoid this, we compute the new list, delete all, and re-insert.

  local anchor_idx0 = anchor_marker.idx
  local epsilon = 1e-6
  local new_markers = {}
  local last_pos = nil

  for _, m in ipairs(markers) do
    local delta = m.idx - anchor_idx0
    local target_qn = anchor_qn + delta * step_qn
    local target_time = reaper.TimeMap2_QNToTime(proj, target_qn)
    local new_pos = target_time - item_pos

    if last_pos ~= nil and new_pos <= last_pos + epsilon then
      new_pos = last_pos + epsilon
    end

    new_markers[#new_markers + 1] = { pos = new_pos, srcpos = m.srcpos, slope = m.slope or 0 }
    last_pos = new_pos
  end

  dbg(('Quantize: unit=%s step_qn=%.6f anchor_qn=%.6f'):format(tostring(unit), tonumber(step_qn) or -1, tonumber(anchor_qn) or -1))
  dbg(('Anchor: idx=%s pos=%.6f srcpos=%.6f item_pos=%.6f anchor_time=%.6f'):format(
    tostring(anchor_marker.idx),
    tonumber(anchor_marker.pos) or -1,
    tonumber(anchor_marker.srcpos) or -1,
    tonumber(item_pos) or -1,
    tonumber(anchor_time) or -1
  ))
  dbg(('Markers: before=%d'):format(#markers))
  if #new_markers > 0 then
    local first = new_markers[1]
    local last = new_markers[#new_markers]
    dbg(('New range: first_pos=%.6f last_pos=%.6f'):format(tonumber(first.pos) or -1, tonumber(last.pos) or -1))
  end

  delete_all_stretch_markers(take)

  for i, m in ipairs(new_markers) do
    local idx = reaper.SetTakeStretchMarker(take, -1, m.pos, m.srcpos)
    if reaper.SetTakeStretchMarkerSlope and idx ~= nil and idx >= 0 then
      reaper.SetTakeStretchMarkerSlope(take, idx, m.slope)
    end
  end

  local after = reaper.GetTakeNumStretchMarkers(take)
  dbg(('Markers: after=%d'):format(after))

  return true, string.format('Quantized %d stretch markers (%s).', after, unit)
end

local function ApplyToSelection()
  local item, err = get_first_selected_audio_item()
  if not item then
    set_status(err)
    return
  end

  local take = reaper.GetActiveTake(item)
  local markers = get_stretch_markers(take)
  if #markers == 0 then
    set_status('Selected take has no stretch markers.')
    return
  end

  dbg('--- APPLY START ---')
  dbg(('Marker count=%d'):format(#markers))

  local item_len = reaper.GetMediaItemInfo_Value(item, 'D_LENGTH')
  local first_visible = find_first_visible_marker(markers, item_len)
  if not first_visible then
    set_status('No stretch markers fall within the visible item range.')
    return
  end

  dbg(('First visible: idx=%s pos=%.6f srcpos=%.6f item_len=%.6f'):format(
    tostring(first_visible.idx),
    tonumber(first_visible.pos) or -1,
    tonumber(first_visible.srcpos) or -1,
    tonumber(item_len) or -1
  ))

  reaper.Undo_BeginBlock()

  local marker_pos = first_visible.pos
  local new_item_pos, anchor_qn, snapped_time = SnapItemToGridByMarker(item, marker_pos, snap_mode, set_snap_offset)
  if not new_item_pos then
    reaper.Undo_EndBlock('Quantize stretch markers to grid (failed)', -1)
    set_status('Failed to snap item to grid.')
    return
  end

  dbg(('Snap: mode=%s new_item_pos=%.6f anchor_qn=%.6f snapped_time=%.6f'):format(
    tostring(snap_mode),
    tonumber(new_item_pos) or -1,
    tonumber(anchor_qn) or -1,
    tonumber(snapped_time) or -1
  ))

  if insert_time_sig then
    UpdateOrCreateTimeSigAtPosition(0, snapped_time or (new_item_pos + marker_pos), ts_num, ts_den)
  end

  -- Re-read item pos after snapping
  local item_pos_after = reaper.GetMediaItemInfo_Value(item, 'D_POSITION')

  local ok, msg = QuantizeStretchMarkers(take, markers, first_visible, anchor_qn, item_pos_after, snapped_time, quantize_unit)

  reaper.UpdateItemInProject(item)
  reaper.UpdateArrange()

  reaper.Undo_EndBlock('Quantize existing stretch markers to grid', -1)

  if ok then
    set_status(msg)
  else
    set_status('Error: ' .. tostring(msg))
  end

  dbg('--- APPLY END ---')
end

-- UI helpers
local function FindOptionIndex(options, value)
  for i, opt in ipairs(options) do
    if opt.value == value then return i end
  end
  return 1
end

local ctx = ImGui.CreateContext(SCRIPT_NAME)

local function loop()
  ImGui.SetNextWindowSize(ctx, 430, 220, ImGui.Cond_FirstUseEver)

  local visible, open = ImGui.Begin(ctx, SCRIPT_NAME, true)
  if visible then
    ImGui.Text(ctx, 'Operates on stretch markers already in the selected item.')
    ImGui.Separator(ctx)

    ImGui.Text(ctx, 'Snap first visible stretch marker to')
    local snap_idx = FindOptionIndex(SNAP_MODE_OPTIONS, snap_mode)
    local snap_label = SNAP_MODE_OPTIONS[snap_idx].label

    ImGui.SetNextItemWidth(ctx, -1)
    if ImGui.BeginCombo(ctx, '##SnapMode', snap_label) then
      for _, opt in ipairs(SNAP_MODE_OPTIONS) do
        local selected = (opt.value == snap_mode)
        if ImGui.Selectable(ctx, opt.label, selected) then
          snap_mode = opt.value
          ext_set('SNAP_MODE', snap_mode)
        end
      end
      ImGui.EndCombo(ctx)
    end

    local changed
    changed, set_snap_offset = ImGui.Checkbox(ctx, 'Set snap offset to first visible stretch marker', set_snap_offset)
    if changed then ext_set_bool('SET_SNAP_OFFSET', set_snap_offset) end

    changed, insert_time_sig = ImGui.Checkbox(ctx, 'Insert/update time signature marker at first stretch marker', insert_time_sig)
    if changed then ext_set_bool('INSERT_TIME_SIG', insert_time_sig) end

    changed, debug_mode = ImGui.Checkbox(ctx, 'Debug output to REAPER console', debug_mode)
    if changed then ext_set_bool('DEBUG_MODE', debug_mode) end

    if insert_time_sig then
      ImGui.PushItemWidth(ctx, 70)
      local ch1; ch1, ts_num = ImGui.InputInt(ctx, 'TS num', ts_num)
      ImGui.SameLine(ctx)
      local ch2; ch2, ts_den = ImGui.InputInt(ctx, 'TS den', ts_den)
      ImGui.PopItemWidth(ctx)

      if ch1 then
        ts_num = math.max(1, math.floor(ts_num))
        ext_set('TS_NUM', ts_num)
      end
      if ch2 then
        ts_den = math.max(1, math.floor(ts_den))
        ext_set('TS_DEN', ts_den)
      end
    end

    ImGui.Spacing(ctx)
    ImGui.Text(ctx, 'Quantize stretch markers to')

    local unit_idx = FindOptionIndex(QUANTIZE_UNIT_OPTIONS, quantize_unit)
    local unit_label = QUANTIZE_UNIT_OPTIONS[unit_idx].label

    ImGui.SetNextItemWidth(ctx, -1)
    if ImGui.BeginCombo(ctx, '##QuantizeUnit', unit_label) then
      for _, opt in ipairs(QUANTIZE_UNIT_OPTIONS) do
        local selected = (opt.value == quantize_unit)
        if ImGui.Selectable(ctx, opt.label, selected) then
          quantize_unit = opt.value
          ext_set('QUANTIZE_UNIT', quantize_unit)
        end
      end
      ImGui.EndCombo(ctx)
    end

    ImGui.Spacing(ctx)
    if ImGui.Button(ctx, 'Apply to first selected item', -1, 0) then
      ApplyToSelection()
    end

    ImGui.Separator(ctx)
    ImGui.TextWrapped(ctx, status_text)

    ImGui.End(ctx)
  end

  if open then
    reaper.defer(loop)
  else
    if reaper.ImGui_DestroyContext then
      reaper.ImGui_DestroyContext(ctx)
    end
  end
end

reaper.defer(loop)
