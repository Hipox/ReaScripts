local reaper, r = reaper, reaper

local path = ({reaper.get_action_context()})[2]:match('^.+[\\//]')
package.path = path .. "?.lua"
local fx_ll_hq = require("Hipox - FX LL HQ - Functions")
local fx_ll_hq_gui = require("Hipox - FX LL HQ - GUI Functions")

dofile(reaper.GetResourcePath() .. '/Scripts/ReaTeam Extensions/API/imgui.lua')('0.8')

local ctx = reaper.ImGui_CreateContext('My script', reaper.ImGui_ConfigFlags_DockingEnable())

local sans_serif = reaper.ImGui_CreateFont('sans-serif', 13)
reaper.ImGui_Attach(ctx, sans_serif)


local ImGui = {}
for name, func in pairs(reaper) do
  name = name:match('^ImGui_(.+)$')
  if name then ImGui[name] = func end
end

local FLT_MIN, FLT_MAX = ImGui.NumericLimits_Float()
local TEXT_BASE_WIDTH  = ImGui.CalcTextSize(ctx, 'A')
local TEXT_BASE_HEIGHT = ImGui.GetTextLineHeightWithSpacing(ctx)
--- core functions ---

--- end of core functions ---

--- variables ---
local flag_popup_open = false
local ret_button
local ret_button_prev
local FilterBox_ret = false
--- end of variables ---


--------------------------------- GUI TOOLS ---------------------------------
local demo = {
  open = true,

  menu = {
    enabled = true,
    f = 0.5,
    n = 0,
    b = true,
  },

  -- Window flags (accessible from the "Configuration" section)
  no_titlebar       = false,
  no_scrollbar      = false,
  no_menu           = false,
  no_move           = false,
  no_resize         = false,
  no_collapse       = false,
  no_close          = false,
  no_nav            = false,
  no_background     = false,
  -- no_bring_to_front = false,
  unsaved_document  = false,
  no_docking        = false,
}

local config  = {}
local widgets = {}
local layout  = {}
local popups  = {}
local tables  = {}
local misc    = {}
local app     = {}
local cache   = {}

function demo.loop()
  demo.PushStyle()
  demo.open = demo.ShowDemoWindow(true)
  demo.PopStyle()

  if demo.open then
    reaper.defer(demo.loop)
  end
end

---------------------------------- SEXAN FX SEARCH --------------------------------
local SLOT = 1

function FX_NAME(str)
    local vst_name
    for name_segment in str:gmatch('[^%,]+') do
        if name_segment:match("(%S+) ") then
            if name_segment:match('"(JS: .-)"') then
                vst_name = name_segment:match('"JS: (.-)"') and "JS:" .. name_segment:match('"JS: (.-)"') or nil
            else
                vst_name = name_segment:match("(%S+ .-%))") and "VST:" .. name_segment:match("(%S+ .-%))") or nil
            end
        end
    end
    if vst_name then return vst_name end
end

function GetFileContext(fp)
    local str = "\n"
    local f = io.open(fp, 'r')
    if f then
        str = f:read('a')
        f:close()
    end
    return str
end

-- Fill function with desired database
function Fill_fx_list()
    local tbl_list   = {}
    local tbl        = {}

    local vst_path   = r.GetResourcePath() .. "/reaper-vstplugins64.ini"
    local vst_str    = GetFileContext(vst_path)

    local vst_path32 = r.GetResourcePath() .. "/reaper-vstplugins.ini"
    local vst_str32  = GetFileContext(vst_path32)

    local jsfx_path  = r.GetResourcePath() .. "/reaper-jsfx.ini"
    local jsfx_str   = GetFileContext(jsfx_path)

    local au_path    = r.GetResourcePath() .. "/reaper-auplugins64-bc.ini"
    local au_str     = GetFileContext(au_path)

    local plugins    = vst_str .. vst_str32 .. jsfx_str .. au_str

    for line in plugins:gmatch('[^\r\n]+') do tbl[#tbl + 1] = line end

    -- CREATE NODE LIST
    for i = 1, #tbl do
        local fx_name = FX_NAME(tbl[i])
        if fx_name then
            tbl_list[#tbl_list + 1] = fx_name
        end
    end
    return tbl_list
end

local USER_FX_IDENTIFIER_TAB = Fill_fx_list()
local function Lead_Trim_ws(s) return s:match '^%s*(.*)' end

local function Filter_actions(filter_text)
    filter_text = Lead_Trim_ws(filter_text)
    local t = {}
    if filter_text == "" then return t end
    for i = 1, #USER_FX_IDENTIFIER_TAB do
        local action = USER_FX_IDENTIFIER_TAB[i]
        local name = action:lower()
        local found = true
        for word in filter_text:gmatch("%S+") do
            if not name:find(word:lower(), 1, true) then
                found = false
                break
            end
        end
        if found then t[#t + 1] = action end
    end
    return t
end

local function AddFxToTracks(fx)
    if r.CountTracks(0) == 1 and r.CountSelectedTracks(0) == 0 then
        local track = r.GetTrack(0, 0)
        r.TrackFX_AddByName(track, fx, false, -1000 - (SLOT - 1))
        return
    end
    for t = 1, r.CountSelectedTracks(0, 0) do
        r.TrackFX_AddByName(r.GetSelectedTrack(0, t - 1), fx, false, -1000 - (SLOT - 1))
    end
end

local keys = {
    r.ImGui_Key_1(),
    r.ImGui_Key_2(),
    r.ImGui_Key_3(),
    r.ImGui_Key_4(),
    r.ImGui_Key_5(),
    r.ImGui_Key_6(),
    r.ImGui_Key_7(),
    r.ImGui_Key_8(),
    r.ImGui_Key_9(),
    r.ImGui_Key_GraveAccent(),
    r.ImGui_Key_0()
}

local function CheckKeyNumbers()
    CTRL = r.ImGui_IsKeyDown(ctx, r.ImGui_Key_LeftCtrl())
    if not CTRL then return end
    for i = 1, #keys do
        if r.ImGui_IsKeyPressed(ctx, keys[i]) then
            SLOT = i < 10 and i or 100
        end
    end
end

local function AllowChildFocus(i)
    if ALLOW_IN_LIST and not PASS_FOCUS then
        if i == 1 then
            r.ImGui_SetKeyboardFocusHere(ctx)
            PASS_FOCUS = true
        end
    end
end

local filter_h = 60
local MAX_FX_SIZE = 300
local FILTER = "valhalla"
function FilterBox()
    FilterBox_ret = true
    CheckKeyNumbers()
    r.ImGui_SetNextWindowSize(ctx, 0, filter_h)
    if ImGui.Button(ctx, "" .. FILTER) then
        ImGui.OpenPopup(ctx, 'popup')
      end

    if r.ImGui_BeginPopup(ctx, "popup") then
        --r.ImGui_Text(ctx, "ADD TO SLOT : " .. (SLOT < 100 and tostring(SLOT) or "LAST"))
        r.ImGui_PushItemWidth(ctx, MAX_FX_SIZE)
        if r.ImGui_IsWindowAppearing(ctx) then r.ImGui_SetKeyboardFocusHere(ctx) end
        -- IF KEYBOARD FOCUS IS ON CHILD ITEMS SET IT HERE
        if r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Escape()) then r.ImGui_SetKeyboardFocusHere(ctx) end
        _, FILTER = r.ImGui_InputText(ctx, '##input', FILTER)
        if r.ImGui_IsItemFocused(ctx) then 
            ALLOW_IN_LIST, PASS_FOCUS = nil, nil
            -- IF FOCUS IS ALREADY HERE CLOSE POPUP
            if r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Escape()) then r.ImGui_CloseCurrentPopup(ctx); FilterBox_ret = false end
        end

        local filtered_fx = Filter_actions(FILTER)
        filter_h = #filtered_fx == 0 and 60 or (#filtered_fx > 40 and 20 * 17 or (17 * #filtered_fx) + 55)

        if r.ImGui_BeginChild(ctx, "aaaaa") then
            -- DANCING AROUND SOME LIMITATIONS OF SELECTING CHILDS
            if r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_DownArrow()) then
                if not ALLOW_IN_LIST then ALLOW_IN_LIST = true end
            end
            for i = 1, #filtered_fx do
                AllowChildFocus(i)
                r.ImGui_PushID(ctx, i)
                if r.ImGui_Selectable(ctx, filtered_fx[i], true, nil, MAX_FX_SIZE) then
                    --AddFxToTracks(filtered_fx[i])
                    FILTER = filtered_fx[i]
                end
                r.ImGui_PopID(ctx)
                if r.ImGui_IsItemHovered(ctx) then
                    if r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Enter()) then
                        --AddFxToTracks(filtered_fx[i])
                        FILTER = filtered_fx[i]
                    end
                end
            end
            r.ImGui_EndChild(ctx)
        end
        r.ImGui_EndPopup(ctx)
        r.defer(FilterBox)
    end
end

-- local function loop()
--     r.ImGui_OpenPopup(ctx, 'popup')
--     r.ImGui_SetNextWindowPos(ctx, r.ImGui_PointConvertNative(ctx, r.GetMousePosition()))
--     FilterBox()
-- end

------------------------------ GUI --------------------------------
local function myWindow()
    local rv

    function demo.PopStyleCompact()
    ImGui.PopStyleVar(ctx, 2)
    end

    function demo.PushStyleCompact()
    local frame_padding_x, frame_padding_y = ImGui.GetStyleVar(ctx, ImGui.StyleVar_FramePadding())
    local item_spacing_x,  item_spacing_y  = ImGui.GetStyleVar(ctx, ImGui.StyleVar_ItemSpacing())
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_FramePadding(), frame_padding_x, math.floor(frame_padding_y * 0.60))
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_ItemSpacing(),  item_spacing_x,  math.floor(item_spacing_y  * 0.60))
    end

---------------------

    local filter_bufs = {"filterContent1"}

    local column_names = {"Filter1"}
    local count_columns = #filter_bufs
    local rows_count = 1

    if ImGui.BeginTable(ctx, 'table_item_width', count_columns, ImGui.TableFlags_Borders()) then
        
        for i = 1, count_columns do
            ImGui.TableSetupColumn(ctx, column_names[i])
        end
        
        ImGui.TableHeadersRow(ctx)

        for row = 0, rows_count-1 do
            ImGui.TableNextRow(ctx)
            if row == 0 then
                for i = 1, count_columns do
                    ImGui.TableSetColumnIndex(ctx, i-1)
                    ImGui.PushItemWidth(ctx, -FLT_MIN)
                end
            end

            -- Draw our contents
            ImGui.PushID(ctx, row)
            local content = filter_bufs[1]
            for i = 1, count_columns do
                rv, input = reaper.ImGui_InputText(ctx, "input", input or '');
                reaper.ImGui_SameLine(ctx)
                isOpen, input = fx_ll_hq_gui.autoComplete(ctx, isOpen, input, { 'foo', 'bar', 'baz' })
            end
        ImGui.PopID(ctx)
      end

      ImGui.EndTable(ctx)
    end
    --reaper.defer(loop)
    -- if ImGui.Button(ctx, 'Filter...') then
        
    --     ImGui.OpenPopup(ctx, 'popup')
    --     --r.ImGui_SetNextWindowPos(ctx, r.ImGui_PointConvertNative(ctx, r.GetMousePosition()))
    --     ::continue::
    --     FilterBox()
    --     if FilterBox_ret then
    --         goto continue
    --     end
        
    -- end

end

local function loop()
  reaper.ImGui_PushFont(ctx, sans_serif)
  reaper.ImGui_SetNextWindowSize(ctx, 400, 80, reaper.ImGui_Cond_FirstUseEver())
  local visible, open = reaper.ImGui_Begin(ctx, 'Hipox - Combo Filter', true)
  if visible then
    myWindow()
    reaper.ImGui_End(ctx)
  end
  reaper.ImGui_PopFont(ctx)
  
  if open then
    reaper.defer(loop)
  end
end

-- local function loop()
--     r.ImGui_OpenPopup(ctx, 'popup')
--     r.ImGui_SetNextWindowPos(ctx, r.ImGui_PointConvertNative(ctx, r.GetMousePosition()))
--     FilterBox()
-- end

reaper.defer(loop)

