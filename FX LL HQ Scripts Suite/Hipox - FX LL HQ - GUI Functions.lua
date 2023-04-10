-- @description Hipox - FX LL HQ - GUI Functions.lua
-- @author Hipox
-- @version 1.0
-- @about
-- @noindex

local fx_ll_hq_gui = {}

local reaper, r = reaper, reaper
local path = ({reaper.get_action_context()})[2]:match('^.+[\\//]')
package.path = path .. "?.lua"
local fx_ll_hq = require("Hipox - FX LL HQ - Functions")
--local csv = require("Simple-CSV")

local ImGui = {}
for name, func in pairs(reaper) do
  name = name:match('^ImGui_(.+)$')
  if name then ImGui[name] = func end
end

function fx_ll_hq_gui.HSV(h, s, v, a)
  local r, g, b = ImGui.ColorConvertHSVtoRGB(h, s, v)
  return ImGui.ColorConvertDouble4ToU32(r, g, b, a or 1.0)
end

function SetMinMax(Input, Min,Max )
  if Input >= Max then Input = Max 
  elseif Input <= Min then Input = Min
  else Input = Input
  end
  return Input 
end

function SL(ctx, xpos, pad)
  r.ImGui_SameLine(ctx,xpos, pad) 
end

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

local previous_valid_status_user_database = false
local catched_file_path_IN, catched_file_name_IN, catched_label_IN, catched_is_database_valid, catched_file_path_OUT, catched_file_name_OUT, catched_label_OUT, catched_valid_file_ret = nil, nil, nil, nil, nil, nil, nil, nil
local flag_dialogue_stop = false
local flag_cancel_dialogue_stop = false

function fx_ll_hq_gui.PathHandler_forDatabase(ctx, file_name_IN, file_path_IN, label_IN, label_default, is_database_valid, count_changes, rows_count, table_refresh, flag_refresh_table)
  --count_changes = 1 -----------------------!!!!!!!!!!!!!!!!!!!!!!!!!!!! TODO TEST
  
    local path_changed_manually
    local rv
    local valid_file_ret
    local file_path_OUT = file_path_IN
    local file_name_OUT = file_name_IN
    local label_OUT = label_IN
    if reaper.ImGui_Button(ctx, 'Choose File...') then
      file_path_OUT = fx_ll_hq.OpenSystemFileOpenDialogue_ReturnFilePath()
      if file_path_OUT ~= nil then
        path_changed_manually = false
        --fx_ll_hq.print("ret_file_path == " .. file_path_OUT .. "\n")
        valid_file_ret, label_OUT = fx_ll_hq.IsDatabaseFileValidFeedbackTextReturn(file_path_OUT, label_default, false)

        -- if count_changes > 0 then
        --   if previous_valid_status_user_database == true and valid_file_ret == false then
        --     fx_ll_hq.print("Unsaved changes when changing path from dialogue!\n")
        --     --ImGui.OpenPopup(ctx, 'Change User Database Path')
        --   end
        -- end


        file_name_OUT = fx_ll_hq.ExtractFileNameFromPath(file_path_OUT)
        if file_name_OUT then
          --fx_ll_hq.print("ret_file_name == " .. file_name_OUT .. "\n")
        else
          --fx_ll_hq.print("ret_file_name == nil, could not be extracted from file path. Not saving it.\n")
          file_name_OUT = file_name_IN
        end
      else
        file_path_OUT = file_path_IN
        --fx_ll_hq.print("Open File... cancelled\n")
        --fx_ll_hq.print("file_path_IN == " .. file_path_IN .. " file_path_OUT == " .. file_path_OUT .. "\n")
      end
    end
  
    reaper.ImGui_SameLine(ctx)
  
    if flag_refresh_table then
      valid_file_ret, label_OUT = fx_ll_hq.IsDatabaseFileValidFeedbackTextReturn(file_path_OUT, label_default, false)
    end
  
    reaper.ImGui_SameLine(ctx)

    if not is_database_valid then
      ImGui.PushStyleColor(ctx, ImGui.Col_FrameBg(), fx_ll_hq_gui.HSV(320.0, 0.86, 0.6, 1.0));
    end
      --ImGui.InputText("##text1", txt_green, sizeof(txt_green));
    rv, file_path_OUT = reaper.ImGui_InputText(ctx, label_default, file_path_OUT)
    
    if not is_database_valid then
      ImGui.PopStyleColor(ctx, 1)
      --ImGui.PopID(ctx)
    end
    
    if rv then
      path_changed_manually = true
      ----fx_ll_hq.print("Manual Edit: ret_user_database_path == " .. ret_file_path .. '\n')
      valid_file_ret, label_OUT = fx_ll_hq.IsDatabaseFileValidFeedbackTextReturn(file_path_OUT, label_default, false)
      file_name_OUT = fx_ll_hq.ExtractFileNameFromPath(file_path_OUT)
      -- if count_changes > 0 then
      --   if previous_valid_status_user_database == true and valid_file_ret == false then
      --     fx_ll_hq.print("Unsaved changes when changing path manually!\n")
      --     --ImGui.OpenPopup(ctx, 'Change User Database Path')

      --   end
      -- end
      --fx_ll_hq.print("Manual Edit: file_path_OUT == " .. file_path_OUT .. '\n')
    end
    reaper.ImGui_SameLine(ctx)
  
    if not label_OUT then
      label_OUT = label_default
    end 
    reaper.ImGui_Text(ctx, label_OUT)

    if count_changes > 0 and path_changed_manually ~= nil then
      local change_from_valid_to_invalid_database_or_valid_to_another_valid_database = (previous_valid_status_user_database == true and valid_file_ret == false) or (previous_valid_status_user_database == true and valid_file_ret == true)
      --local was_path_changed = path_changed_manually ~= nil
      --fx_ll_hq.print("file_path_IN_and_OUT_match == " .. tostring(file_path_IN_and_OUT_match) .. " change_from_valid_to_invalid_database == " .. tostring(change_from_valid_to_invalid_database) .. "\n")
      -- if file_path_IN ~= file_path_OUT then
      --   fx_ll_hq.print("file_path_IN ~= file_path_OUT\n")
      -- end
      -- if previous_valid_status_user_database == true and valid_file_ret == false then
      --   fx_ll_hq.print("User Database path changed from valid to invalid!\n")
      --   --ImGui.OpenPopup(ctx, 'Change User Database Path')
      -- end
      -- if path_changed_manually ~= nil and path_changed_manually == true then
      --   fx_ll_hq.print("User Database path changed manually\n")
      -- elseif path_changed_manually ~= nil and path_changed_manually == false then
      --   fx_ll_hq.print("User Database path changed from dialogue\n")
      -- end

      if change_from_valid_to_invalid_database_or_valid_to_another_valid_database then
        fx_ll_hq.print("Unsaved changes when changing path!\n")
        fx_ll_hq.print("file_path_IN == " .. file_path_IN .. " file_path_OUT == " .. file_path_OUT .. "\n")
        catched_file_name_IN = file_name_IN
        catched_file_path_IN = file_path_IN
        catched_label_IN = label_IN
        catched_is_database_valid = is_database_valid
        catched_file_name_OUT = file_name_OUT
        catched_file_path_OUT = file_path_OUT
        catched_label_OUT = label_OUT
        catched_valid_file_ret = valid_file_ret
        file_path_OUT = file_path_IN
        file_name_OUT = file_name_IN
        label_OUT = label_IN
        valid_file_ret = is_database_valid
        flag_dialogue_stop = true
        
        if fx_ll_hq.value_checkbox_edit_popup_1 then
          fx_ll_hq.SaveTableValuesToCsvFile(fx_ll_hq.csvUserDatabase)
          flag_cancel_dialogue_stop = false
          file_name_OUT = catched_file_name_OUT
          file_path_OUT = catched_file_path_OUT
          fx_ll_hq.print("file_path_OUT == " .. file_path_OUT .. "\n" .. " file_name_OUT == " .. file_name_OUT .. "\n")
          label_OUT = catched_label_OUT
          valid_file_ret = catched_valid_file_ret
          flag_dialogue_stop = false
          flag_cancel_dialogue_stop = false
        else
          ImGui.OpenPopup(ctx, 'Unsaved changes in User Database')
        end
      -- elseif valid_file_ret then
      --   fx_ll_hq.print("User Database path changed to valid and checkbox is off\n")
      --   flag_dialogue_stop = false
      --   flag_cancel_dialogue_stop = false
      end

      --manual change?
      -- if path_changed_manually and   then
      --   -- trigger modal popup
      -- elseif not path_changed_manually then
      --   -- trigger modal popup
      -- end


      --dialogue change?

    end

    
      -- Always center this window when appearing
      local center = {ImGui.Viewport_GetCenter(ImGui.GetWindowViewport(ctx))}
      ImGui.SetNextWindowPos(ctx, center[1], center[2], ImGui.Cond_Appearing(), 0.5, 0.5)
      
      if ImGui.BeginPopupModal(ctx, 'Unsaved changes in User Database', nil, ImGui.WindowFlags_AlwaysAutoResize()) then

        ImGui.Text(ctx, 'There are some unsaved changes in the current user database.')
        ImGui.Separator(ctx)

        -- static int unused_i = 0;
        -- ImGui.Combo("Combo", &unused_i, "Delete\0Delete harder\0");
        local value
        ImGui.PushStyleVar(ctx, ImGui.StyleVar_FramePadding(), 0, 0)
        rv, value = ImGui.Checkbox(ctx, "Don't ask me next time (autosave)", fx_ll_hq.value_checkbox_edit_popup_1)
        ImGui.PopStyleVar(ctx)
        if rv then
          fx_ll_hq.value_checkbox_edit_popup_1 = value
        end

        if ImGui.Button(ctx, 'Save and proceed', 100, 0) then
          fx_ll_hq.SaveTableValuesToCsvFile(fx_ll_hq.csvUserDatabase)
          flag_cancel_dialogue_stop = false
          file_name_OUT = catched_file_name_OUT
          file_path_OUT = catched_file_path_OUT
          label_OUT = catched_label_OUT
          valid_file_ret = catched_valid_file_ret
          ImGui.CloseCurrentPopup(ctx)
          flag_dialogue_stop = false
          flag_cancel_dialogue_stop = false
          fx_ll_hq.print("Save and proceed from 'Unsaved changes in User Database'\n")
        end
        ImGui.SameLine(ctx)
        if ImGui.Button(ctx, 'Just proceed', 100, 0) then
          file_name_OUT = catched_file_name_OUT
          file_path_OUT = catched_file_path_OUT
          label_OUT = catched_label_OUT
          valid_file_ret = catched_valid_file_ret
          ImGui.CloseCurrentPopup(ctx)
          flag_dialogue_stop = false
          flag_cancel_dialogue_stop = false
          fx_ll_hq.print("Just proceed from 'Unsaved changes in User Database'\n")
        end
        
        ImGui.SameLine(ctx)
        ImGui.SetItemDefaultFocus(ctx)
        if ImGui.Button(ctx, 'Cancel', 100, 0) then
          file_path_OUT = catched_file_path_IN
          file_name_OUT = catched_file_name_IN
          label_OUT = catched_label_IN
          valid_file_ret = catched_is_database_valid
          ImGui.CloseCurrentPopup(ctx)
          flag_dialogue_stop = false
          flag_cancel_dialogue_stop = true
          fx_ll_hq.print("Cancel from 'Unsaved changes in User Database'\n")
        end

        ImGui.EndPopup(ctx)
      end
    
    previous_valid_status_user_database = is_database_valid
    return file_path_OUT, file_name_OUT, label_OUT, valid_file_ret, flag_dialogue_stop, flag_cancel_dialogue_stop, rows_count, table_refresh
  end
  
  function fx_ll_hq_gui.ExitPathHandler_forDatabase(ctx, file_path_new, file_path_database, gv_identifier)
    --fx_ll_hq.print("--Exit FN for: " .. gv_identifier .. "\n")
    --fx_ll_hq.print( "file_path_new == " .. file_path_new .. "\nVS\nfx_ll_hq.file_path_user_database == " .. fx_ll_hq.file_path_user_database .. "\n")
    --fx_ll_hq.print("file_path_new:find(file_path_database,1,true) == " .. tostring(file_path_new:find(file_path_database,1,true)) .. "\n")
    if not file_path_database:match(file_path_new) and fx_ll_hq.VerifyNewDatabaseFile(file_path_new) then
      --fx_ll_hq.print("file_path_new ~= file_path_database and IsDatabaseTableValid(csvMeta_database) == true\n")
      local file_name_new = fx_ll_hq.ExtractFileNameFromPath(file_path_new)
      if file_name_new then
        --fx_ll_hq.print("file_name_new == " .. file_name_new .. "\n")
        fx_ll_hq.SetVar(fx_ll_hq.csvGlobalVariables, fx_ll_hq.file_path_global_variables, gv_identifier, true, 1, file_name_new)
      else
        --fx_ll_hq.print("file_name_new == nil, could not be extracted from file path. Not saving it.\n")
      end
    else
      --fx_ll_hq.print("file_path_new == file_path_database or IsDatabaseTableValid(csvMeta_database) == false\n")
    end
  end

local function Lead_Trim_ws(s) return s:match '^%s*(.*)' end

local function Filter_actions_unique_pairs(filter_text, table)
  -- filter text would have to be empty string
  local is_filter_text_empty = filter_text:match("^%s*$") == 1 and true or filter_text == nil
  filter_text = Lead_Trim_ws(filter_text)
  --fx_ll_hq.print("filter_text == " .. tostring(filter_text) .. "\n")
  local t = {}
  --if filter_text == "" then return t end
  
  for identifier,_ in pairs(table) do
    if is_filter_text_empty then  
      t[#t + 1] = identifier
    else
      local identifier_lower = identifier:lower()
      local found = true
      for word in filter_text:gmatch("%S+") do
          if not identifier_lower:find(word:lower(), 1, true) then
              found = false
              break
          end
      end
      if found then t[#t + 1] = identifier end
    end
  end
  return t
end

  function fx_ll_hq_gui.FilterSearchHandler(ctx, idx, row, isOpen, isOpen_prev, input, flag_first, flag_changed, table) -- UNUSED
    --fx_ll_hq.print("idx == " .. tostring(idx) .. " row == " .. tostring(row) .. "\n")
    local rv
    ImGui.TableSetColumnIndex(ctx, idx-1)
    rv, input = reaper.ImGui_InputText(ctx, "input".. idx .. "_"..row, input or '', ImGui.InputTextFlags_AutoSelectAll());

    local isActive = reaper.ImGui_IsItemActive(ctx)
    isOpen = isOpen or isActive
    local id = idx .. "_" .. row
    if isOpen then
      reaper.ImGui_SetNextWindowPos(ctx, reaper.ImGui_GetItemRectMin(ctx), select(2, reaper.ImGui_GetItemRectMax(ctx)))
      reaper.ImGui_SetNextWindowSize(ctx, reaper.ImGui_GetItemRectSize(ctx), 0)

      local visible = reaper.ImGui_Begin(ctx, "##popup" .. tostring(id), nil, reaper.ImGui_WindowFlags_NoTitleBar()|reaper.ImGui_WindowFlags_NoMove()|reaper.ImGui_WindowFlags_NoResize()|reaper.ImGui_WindowFlags_NoFocusOnAppearing()|reaper.ImGui_WindowFlags_TopMost())
      
      if visible then

        local filtered_fx = Filter_actions_unique_pairs(input, table)

        fx_ll_hq.print("#filtered_fx == " .. tostring(#filtered_fx) .. "\n")
  
        fx_ll_hq.print("filtered_fx == " .. tostring(filtered_fx) .. "\n")
      
        ADDFX_Sel_Entry = SetMinMax ( ADDFX_Sel_Entry or 1 ,  1 , #filtered_fx)


        --fx_ll_hq.print("#choices == " .. tostring(#choices) .. " filter_string == " .. tostring(filter_text) .. "\n")
        for i = 1, #filtered_fx do

          if reaper.ImGui_Selectable(ctx, filtered_fx[i]) then
            input = filtered_fx[i]
            isOpen = false
          end

          -- if choice:sub(1, #input) == input and reaper.ImGui_Selectable(ctx, choice) then
          if i == ADDFX_Sel_Entry then
            HighlightSelectedItem(ctx,0xffffff11, nil, 0, L,T,R,B,h,w, 1, 1,'GetItemRect')
          end


          --reaper.ImGui_PopID(ctx)
        end

        if r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Enter()) then 
          fx_ll_hq.print("fx selected\n")
          input = filtered_fx[ADDFX_Sel_Entry]
          ADDFX_Sel_Entry = nil
          
        elseif r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_UpArrow()) then 
            fx_ll_hq.print("upArrow\n")
            ADDFX_Sel_Entry = ADDFX_Sel_Entry -1 
        elseif r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_DownArrow()) then 
            fx_ll_hq.print("downArrow\n")
            ADDFX_Sel_Entry = ADDFX_Sel_Entry +1
        end
        
        isOpen = isOpen and (isActive or reaper.ImGui_IsWindowFocused(ctx))
    
        reaper.ImGui_End(ctx)
      end
    end

    return isOpen, isOpen_prev, input, flag_first, flag_changed
end

local addfx_sel_entry = {}

function fx_ll_hq_gui.autoComplete(ctx, isOpen, input, fx_identifier_tab, row)
    local set_focus = nil
    -- fx_ll_hq.print( "isOpen == "  .. tostring(isOpen) .. " input == " .. tostring(input) .. " row == " .. tostring(row) .. "#fx_identifier_tab == " .. #fx_identifier_tab .. "\n")
    --fx_ll_hq.print("input_"..row .. " == " .. tostring(input) .. "\n")
    local filtered_fx = fx_ll_hq.Filter_actions(fx_identifier_tab, input)
    --fx_ll_hq.print("("..row .. ") filtered_fx == " .. tostring(#filtered_fx) .. "\n")
    addfx_sel_entry[row] = (#filtered_fx == 0 or addfx_sel_entry[row] == nil) and 1 or addfx_sel_entry[row]
    --fx_ll_hq.print("ADDFX_Sel_Entry == " .. tostring(addfx_sel_entry[row]) .. "\n")
    local isActive = r.ImGui_IsItemActive(ctx)
    isOpen = isOpen or isActive
    --fx_ll_hq.print("isOpen == " .. tostring(isOpen) .. " #filtered_fx == " .. #filtered_fx .. "\n")
    if isOpen and #filtered_fx ~= 0 then
        --r.ImGui_SetKeyboardFocusHere(ctx)
        r.ImGui_SetNextWindowPos(ctx, r.ImGui_GetItemRectMin(ctx), select(2, r.ImGui_GetItemRectMax(ctx)))
        r.ImGui_SetNextWindowSize(ctx, r.ImGui_GetItemRectSize(ctx), 0)

        addfx_sel_entry[row] = fx_ll_hq.clamp(1, addfx_sel_entry[row], #filtered_fx)
        

        local visible = r.ImGui_Begin(ctx, "##autoComplete_popup_tableRow_" .. row, nil,
            r.ImGui_WindowFlags_NoTitleBar()|r.ImGui_WindowFlags_NoMove()|r.ImGui_WindowFlags_NoResize()|
            r.ImGui_WindowFlags_NoFocusOnAppearing()|r.ImGui_WindowFlags_TopMost())
        if visible then

          -- if r.ImGui_IsWindowAppearing( ctx) then 
          --   r.ImGui_SetKeyboardFocusHere(ctx, -1)
          -- end

            for i, choice in ipairs(filtered_fx) do
                r.ImGui_PushID(ctx, i)
                fx_ll_hq.PushColor(ctx)
                if r.ImGui_Selectable(ctx, choice, i == addfx_sel_entry[row]) then
                    --AddFxToTracks(choice)
                    addfx_sel_entry[row] = 1
                    --INPUT = '' -- RESET INPUT
                    input = choice -- MAKE INPUT STAY AT FX NAME
                    isOpen = false
                end
                r.ImGui_PopID(ctx)
                fx_ll_hq.PopColor(ctx)
            end

            if r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Enter()) and r.ImGui_IsKeyDown(ctx, ImGui.Mod_Shift()) then
                --fx_ll_hq.print("shift+enter pressed\n")
                --AddFxToTracks(filtered_fx[ADDFX_Sel_Entry])
                --INPUT = ''
                --input = filtered_fx[addfx_sel_entry[row]]
                isOpen = false
                --addfx_sel_entry[row] = 1
                --set_focus = true
            elseif r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Enter()) then
              --fx_ll_hq.print("enter pressed\n")
              --AddFxToTracks(filtered_fx[ADDFX_Sel_Entry])
              --INPUT = ''
              input = filtered_fx[addfx_sel_entry[row]]
              isOpen = false
              addfx_sel_entry[row] = 1
              --set_focus = true
            elseif r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_UpArrow()) then
                --fx_ll_hq.print("up pressed\n")
                addfx_sel_entry[row] = addfx_sel_entry[row] - 1
            elseif r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_DownArrow()) then
                --fx_ll_hq.print("down pressed\n")
                addfx_sel_entry[row] = addfx_sel_entry[row] + 1
            end

            isOpen = isOpen and (isActive or r.ImGui_IsWindowFocused(ctx))
            --isOpen = isOpen and (isActive or reaper.ImGui_IsWindowFocused(ctx))
            r.ImGui_End(ctx)
        end
    end

    return isOpen, input, set_focus
end

local addfx_sel_entry_database = 1

function fx_ll_hq_gui.autoComplete_database_search(csvMeta, input)
  local rows_count = fx_ll_hq.ReturnNumberOfRowsInCsvTable(csvMeta)
  if rows_count == nil then rows_count = 0 end
  local column_removed = fx_ll_hq.GetPositionOfElementInIterativeTable(fx_ll_hq.database_fomat_table, "Removed")

  local unfiltered_database = {}
  local page
  for i = 1, rows_count do
    --fx_ll_hq.print("i == " .. tostring(i) .. "\n")
    if fx_ll_hq.GetAttributeByRowAndColumnFromCsvTable(fx_ll_hq.csvUserDatabase, i, fx_ll_hq.GetPositionOfElementInIterativeTable(fx_ll_hq.database_fomat_table, "FX Identifier")) == "" then
      goto continue
    end

    for row = 1, rows_count do
      if fx_ll_hq.GetAttributeByRowAndColumnFromCsvTable(fx_ll_hq.csvUserDatabase, row, column_removed) == true then
          goto continue
      end
   end
    page = { fx_ll_hq.GetAttributeByRowAndColumnFromCsvTable(fx_ll_hq.csvUserDatabase, i, fx_ll_hq.GetPositionOfElementInIterativeTable(fx_ll_hq.database_fomat_table, "Row")) , fx_ll_hq.GetAttributeByRowAndColumnFromCsvTable(fx_ll_hq.csvUserDatabase, i, fx_ll_hq.GetPositionOfElementInIterativeTable(fx_ll_hq.database_fomat_table, "FX Identifier"))}
    -- fx_ll_hq.print("fx_ll_hq.GetAttributeByRowAndColumnFromCsvTable(fx_ll_hq.csvUserDatabase, i, fx_ll_hq.GetPositionOfElementInIterativeTable(fx_ll_hq.database_fomat_table, 'Row')) == " .. tostring(fx_ll_hq.GetAttributeByRowAndColumnFromCsvTable(fx_ll_hq.csvUserDatabase, i, fx_ll_hq.GetPositionOfElementInIterativeTable(fx_ll_hq.database_fomat_table, "Row"))) .. "\n")
    --fx_ll_hq.print("fx_ll_hq.GetAttributeByRowAndColumnFromCsvTable(fx_ll_hq.csvUserDatabase, i, fx_ll_hq.GetPositionOfElementInIterativeTable(fx_ll_hq.database_fomat_table, 'FX Identifier')) == " .. tostring(fx_ll_hq.GetAttributeByRowAndColumnFromCsvTable(fx_ll_hq.csvUserDatabase, i, fx_ll_hq.GetPositionOfElementInIterativeTable(fx_ll_hq.database_fomat_table, "FX Identifier"))) .. "\n")
    table.insert(unfiltered_database, page)
    ::continue::
  end

  local filtered_database = fx_ll_hq.Filter_actions_2D(unfiltered_database, input)

  return input, filtered_database
end


return fx_ll_hq_gui