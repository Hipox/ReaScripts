local SLOT = 1

local r = reaper

local ctx = r.ImGui_CreateContext('My script', r.ImGui_ConfigFlags_NavEnableKeyboard())

local sans_serif = reaper.ImGui_CreateFont('sans-serif', 13)
r.ImGui_Attach(ctx, sans_serif)

function HighlightSelectedItem(ctx,FillClr,OutlineClr, Padding, L,T,R,B,h,w, H_OutlineSc, V_OutlineSc,GetItemRect, Foreground,rounding)

    if GetItemRect == 'GetItemRect' then 
        L, T = r.ImGui_GetItemRectMin( ctx ) ; R,B = r.ImGui_GetItemRectMax( ctx ); w,h=r.ImGui_GetItemRectSize(ctx)
        --Get item rect 
    end
    local P=Padding; local HSC = H_OutlineSc or 4 ; local VSC = V_OutlineSc or 4 
    if Foreground == 'Foreground' then  WinDrawList = Glob.FDL else WinDrawList = Foreground end
    if not WinDrawList then WinDrawList = r.ImGui_GetWindowDrawList(ctx) end 
    if FillClr then r.ImGui_DrawList_AddRectFilled(WinDrawList, L,T,R, B, FillClr) end 
  
    if OutlineClr and not rounding then 
    r.ImGui_DrawList_AddLine(WinDrawList, L-P, T-P, L-P, T+h/VSC-P, OutlineClr) ; r.ImGui_DrawList_AddLine(WinDrawList, R+P, T-P, R+P, T+h/VSC-P, OutlineClr) 
    r.ImGui_DrawList_AddLine(WinDrawList, L-P, B+P, L-P, B+P-h/VSC, OutlineClr) ;   r.ImGui_DrawList_AddLine(WinDrawList, R+P, B+P, R+P, B-h/VSC+P, OutlineClr)
    r.ImGui_DrawList_AddLine(WinDrawList, L-P,T-P , L-P+w/HSC,T-P, OutlineClr) ; r.ImGui_DrawList_AddLine(WinDrawList, R+P,T-P , R+P-w/HSC,T-P, OutlineClr)
    r.ImGui_DrawList_AddLine(WinDrawList, L-P ,B+P , L-P+w/HSC,B+P, OutlineClr) ; r.ImGui_DrawList_AddLine(WinDrawList, R+P ,B+P , R+P-w/HSC,B+P, OutlineClr)
    else 
        if FillClr then r.ImGui_DrawList_AddRectFilled(WinDrawList,L,T,R,B,FillClr, rounding) end 
        if OutlineClr then  r.ImGui_DrawList_AddRect(WinDrawList,L,T,R,B, OutlineClr, rounding)end 
    end
    if GetItemRect == 'GetItemRect' then return L,T,R,B,w,h end 
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
r.ShowConsoleMsg("USER_FX_IDENTIFIER_TAB == " .. tostring(#USER_FX_IDENTIFIER_TAB) .. "\n")
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

-- local function Filter_actions_mod(filter_text)
--     local is_filter_text_empty 
--     --r.ShowConsoleMsg("filter_text == " .. tostring(filter_text) .. "\n")
--     if filter_text then
--         is_filter_text_empty = filter_text:match("^%s*$") ~= nil
--     else
--         is_filter_text_empty = true
--     end

--     if not is_filter_text_empty then
--         filter_text = Lead_Trim_ws(filter_text)
--     end
--     local t = {}
--     --if filter_text == "" then return t end
--     for i = 1, #USER_FX_IDENTIFIER_TAB do
--         if is_filter_text_empty then  
--             t[#t + 1] = USER_FX_IDENTIFIER_TAB[i]
--         else
--             local action = USER_FX_IDENTIFIER_TAB[i]
--             local name = action:lower()
--             local found = true
--             for word in filter_text:gmatch("%S+") do
--                 if not name:find(word:lower(), 1, true) then
--                     found = false
--                     break
--                 end
--             end
--             if found then t[#t + 1] = action end
--         end
--     end
--     return t
-- end

local function AddFxToTracks(fx)
    reaper.ShowConsoleMsg("fx == " .. tostring(fx) .. "\n")
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

function SetMinMax(Input, Min,Max )
    if Input >= Max then Input = Max 
    elseif Input <= Min then Input = Min
    else Input = Input
    end
    return Input 
end
function ToNum(str)
    str = tonumber(str)
end

local filter_h = 60
local MAX_FX_SIZE = 300

local input
function FilterSearchHandler(ctx, isOpen)
    local rv
    rv, input = r.ImGui_InputText(ctx, "##input", input or '', r.ImGui_InputTextFlags_AutoSelectAll());

    -- if r.ImGui_IsWindowAppearing( ctx) then 
    --     r.ImGui_SetKeyboardFocusHere(ctx, -1)
    -- end

    local isActive = r.ImGui_IsItemActive(ctx)
    isOpen = isOpen or isActive
    if isOpen then
      r.ImGui_SetNextWindowPos(ctx, r.ImGui_GetItemRectMin(ctx), select(2, r.ImGui_GetItemRectMax(ctx)))
      r.ImGui_SetNextWindowSize(ctx, r.ImGui_GetItemRectSize(ctx), 0)

      local visible = r.ImGui_Begin(ctx, "##popup", nil, r.ImGui_WindowFlags_NoTitleBar()|r.ImGui_WindowFlags_NoMove()|r.ImGui_WindowFlags_NoResize()|r.ImGui_WindowFlags_NoFocusOnAppearing()|r.ImGui_WindowFlags_TopMost())

      if visible then


        local filtered_fx = Filter_actions(input)
  
        ADDFX_Sel_Entry =   SetMinMax ( ADDFX_Sel_Entry or 1 ,  1 , #filtered_fx)        

        for i = 1, #filtered_fx do
            if r.ImGui_Selectable(ctx, filtered_fx[i]) then
                AddFxToTracks(filtered_fx[i])
            end

            if i==ADDFX_Sel_Entry then 
                HighlightSelectedItem(ctx, 0xffffff11, nil, 0, L,T,R,B,h,w, 1, 1,'GetItemRect')
            end
        end

        if r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Enter()) then
            r.ShowConsoleMsg("ADDFX_Sel_Entry == " .. tostring(ADDFX_Sel_Entry) .. "\n")
             --AddFxToTracks(filtered_fx[ADDFX_Sel_Entry])
            ADDFX_Sel_Entry = nil
        elseif r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_UpArrow()) then 
            ADDFX_Sel_Entry = ADDFX_Sel_Entry -1
        elseif r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_DownArrow()) then 
            ADDFX_Sel_Entry = ADDFX_Sel_Entry +1
        end
        
        isOpen = isOpen and (isActive or r.ImGui_IsWindowFocused(ctx))
    
        r.ImGui_End(ctx)
      end
    end
end

local function loop()
    r.ImGui_PushFont(ctx, sans_serif)
    r.ImGui_SetNextWindowSize(ctx, 400, 80, r.ImGui_Cond_FirstUseEver())
    local visible, open = r.ImGui_Begin(ctx, 'AutoComplete FX Browser', true)
    if visible then
        FilterSearchHandler(ctx, false)
      r.ImGui_End(ctx)
    end
    r.ImGui_PopFont(ctx)
    
    if open then
      r.defer(loop)
    end
  end

r.defer(loop)
