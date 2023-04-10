local SLOT = 1
local r = reaper

local ctx = r.ImGui_CreateContext('My script', r.ImGui_ConfigFlags_NavEnableKeyboard())
local sans_serif = r.ImGui_CreateFont('sans-serif', 13)
r.ImGui_Attach(ctx, sans_serif)

local function AddFxToTracks(fx)
    r.ShowConsoleMsg("fx == " .. tostring(fx) .. "\n")
    if r.CountTracks(0) == 1 and r.CountSelectedTracks(0) == 0 then
        local track = r.GetTrack(0, 0)
        r.TrackFX_AddByName(track, fx, false, -1000 - (SLOT - 1))
        return
    end
    for t = 1, r.CountSelectedTracks(0, 0) do
        r.TrackFX_AddByName(r.GetSelectedTrack(0, t - 1), fx, false, -1000 - (SLOT - 1))
    end
end

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

local function PushColor()
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Header(), 0xffffff33) -- DEFAULT BG
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_HeaderHovered(), 0xffffff55) -- HIGHLIGHT BG
    --r.ImGui_PushStyleColor(ctx,r.ImGui_Col_HeaderActive(), 0xffffff33) -- CLICKED
end

local function PopColor()
    r.ImGui_PopStyleColor(ctx)
    r.ImGui_PopStyleColor(ctx)
end

local function clamp(min, value, max)
    return math.max(min, math.min(max, value))
end

local ADDFX_Sel_Entry = 1
local function autoComplete(isOpen)
    local filtered_fx = Filter_actions(INPUT)
    ADDFX_Sel_Entry = #filtered_fx == 0 and 1 or ADDFX_Sel_Entry
    local isActive = r.ImGui_IsItemActive(ctx)
    isOpen = isOpen or isActive
    if isOpen and #filtered_fx ~= 0 then
        r.ImGui_SetKeyboardFocusHere(ctx)
        r.ImGui_SetNextWindowPos(ctx, r.ImGui_GetItemRectMin(ctx), select(2, r.ImGui_GetItemRectMax(ctx)))
        r.ImGui_SetNextWindowSize(ctx, r.ImGui_GetItemRectSize(ctx), 0)

        ADDFX_Sel_Entry = clamp(1, ADDFX_Sel_Entry, #filtered_fx)

        local visible = r.ImGui_Begin(ctx, "##popup", nil,
            r.ImGui_WindowFlags_NoTitleBar()|r.ImGui_WindowFlags_NoMove()|r.ImGui_WindowFlags_NoResize()|
            r.ImGui_WindowFlags_NoFocusOnAppearing()|r.ImGui_WindowFlags_TopMost())
        if visible then
            for i, choice in ipairs(filtered_fx) do
                r.ImGui_PushID(ctx, i)
                PushColor()
                if r.ImGui_Selectable(ctx, choice, i == ADDFX_Sel_Entry) then
                    AddFxToTracks(choice)
                    ADDFX_Sel_Entry = 1
                    --INPUT = '' -- RESET INPUT
                    INPUT = choice -- MAKE INPUT STAY AT FX NAME
                    isOpen = false
                end
                r.ImGui_PopID(ctx)
                PopColor()
            end

            if r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Enter()) then
                AddFxToTracks(filtered_fx[ADDFX_Sel_Entry])
                --INPUT = ''
                INPUT = filtered_fx[ADDFX_Sel_Entry]
                isOpen = false
                ADDFX_Sel_Entry = 1
                SET_FOCUS = true
            elseif r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_UpArrow()) then
                ADDFX_Sel_Entry = ADDFX_Sel_Entry - 1
            elseif r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_DownArrow()) then
                ADDFX_Sel_Entry = ADDFX_Sel_Entry + 1
            end

            r.ImGui_End(ctx)
        end
    end

    return isOpen, INPUT
end

SET_FOCUS = true
local function loop()
    r.ImGui_PushFont(ctx, sans_serif)
    r.ImGui_SetNextWindowSize(ctx, 400, 80, r.ImGui_Cond_FirstUseEver())
    local visible, open = r.ImGui_Begin(ctx, 'AutoComplete FX Browser', true)
    r.ImGui_PopFont(ctx)
    if visible then
        -- ALWAYS SET FOCUS ON INPUT AFTER KEY CONFIRM OR CANCEL OPERATIONS
        -- if r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Escape()) or SET_FOCUS then
        --     SET_FOCUS = nil
        --     ADDFX_Sel_Entry = 1
        --     INPUT = ''
        --     r.ImGui_SetKeyboardFocusHere(ctx)
        -- end
        RV, INPUT = r.ImGui_InputText(ctx, "INPUT", INPUT or '', r.ImGui_InputTextFlags_AutoSelectAll())
        r.ImGui_SameLine(ctx)
        IS_OPEN = autoComplete(IS_OPEN)
        r.ImGui_End(ctx)
    end
    if open then
        r.defer(loop)
    end
end

r.defer(loop)
