local reaper, r = reaper, reaper

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

local max = math.max

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
        local fx_name = FX_IDENTIFIER(tbl[i])
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


function FilterBox(id)
    local MAX_FX_SIZE = 300
    r.ImGui_PushItemWidth(ctx, MAX_FX_SIZE)
    if r.ImGui_IsWindowAppearing(ctx) then r.ImGui_SetKeyboardFocusHere(ctx) end

    if ImGui.Button(ctx, 'Filter...') then
      ImGui.OpenPopup(ctx, 'my_select_popup' .. id)
    end
    ImGui.SameLine(ctx)
    _, FILTER = r.ImGui_InputText(ctx, '##input' .. id, FILTER)
    --win_focused = reaper.ImGui_IsWindowFocused(ctx)
    local filtered_fx = Filter_actions(FILTER)
    local filter_h = #filtered_fx == 0 and 2 or (#filtered_fx > 40 and 20 * 17 or (17 * #filtered_fx))

    -- Simple selection popup (if you want to show the current selection inside the Button itself,
    -- you may want to build a string using the "###" operator to preserve a constant ID with a variable label)

    if not popups.popups then
        popups.popups = {
        selected_fish = -1,
        toggles = { true, false, false, false, false },
    }
    end

    ImGui.SameLine(ctx)
    if ImGui.BeginPopup(ctx, 'my_select_popup' .. id) then
        for i = 1, #filtered_fx do
            if ImGui.Selectable(ctx, filtered_fx[i]) then
            FILTER = filtered_fx[i]
            end
        end
        ImGui.EndPopup(ctx)
    end
end

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

            for i = 1, count_columns do
                ImGui.TableSetColumnIndex(ctx, i-1)
                rv,filter_bufs[i] = FilterBox(i)
            end
        ImGui.PopID(ctx)
      end

      ImGui.EndTable(ctx)
    end
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

reaper.defer(loop)

