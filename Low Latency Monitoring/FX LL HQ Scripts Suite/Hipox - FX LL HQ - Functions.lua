-- @description Hipox - FX LL HQ - Functions.lua
-- @author Hipox
-- @version 1.0
-- @about
-- @noindex

--inspired by scripts:
-- SEXAN dd FX TO SEL TRACKS SLOT


local fx_ll_hq = {}

local reaper, r = reaper, reaper
local path = ({reaper.get_action_context()})[2]:match('^.+[\\//]')
package.path = path .. "?.lua"
local csv = require("Simple-CSV")

local USER_FX_IDENTIFIER_TAB = {}

fx_ll_hq.fx_database_table_header_row = {"Row","FX Identifier","Parameter Index","Low Latency Value","High Quality Value", "Active"}
fx_ll_hq.database_fomat_table = {"Row","FX Identifier","Parameter Index","Low Latency Value","High Quality Value", "Active", "Filter", "Default Low Latency Value", "Default High Quality Value"}
fx_ll_hq.fx_database_table_format = {"VST","VST2","VST3","AU","AAX"}


function fx_ll_hq.GetPositionOfElementInIterativeTable(t, element)
   for i = 1, #t do
      if t[i] == element then
         return i
      end
   end
   return nil
end

fx_ll_hq.row_num_IDX = fx_ll_hq.GetPositionOfElementInIterativeTable(fx_ll_hq.database_fomat_table, "Row")
fx_ll_hq.fx_identifier_IDX = fx_ll_hq.GetPositionOfElementInIterativeTable(fx_ll_hq.database_fomat_table, "FX Identifier")
fx_ll_hq.par_idx_IDX = fx_ll_hq.GetPositionOfElementInIterativeTable(fx_ll_hq.database_fomat_table, "Parameter Index")
fx_ll_hq.ll_val_IDX = fx_ll_hq.GetPositionOfElementInIterativeTable(fx_ll_hq.database_fomat_table, "Low Latency Value")
fx_ll_hq.hq_val_IDX = fx_ll_hq.GetPositionOfElementInIterativeTable(fx_ll_hq.database_fomat_table, "High Quality Value")
fx_ll_hq.active_IDX = fx_ll_hq.GetPositionOfElementInIterativeTable(fx_ll_hq.database_fomat_table, "Active")
fx_ll_hq.filter_IDX = fx_ll_hq.GetPositionOfElementInIterativeTable(fx_ll_hq.database_fomat_table, "Filter")
fx_ll_hq.default_ll_val_IDX = fx_ll_hq.GetPositionOfElementInIterativeTable(fx_ll_hq.database_fomat_table, "Default Low Latency Value")
fx_ll_hq.default_hq_val_IDX = fx_ll_hq.GetPositionOfElementInIterativeTable(fx_ll_hq.database_fomat_table, "Default High Quality Value")

local INT_MIN, INT_MAX = reaper.ImGui_NumericLimits_Int()
fx_ll_hq.emptyNewRowDatabase = {INT_MAX,"",0,0,1,true,true,0,1}
-- fx_ll_hq.database_format_table_filterSearch_idxs = {2}

fx_ll_hq.number_of_non_native_columns_in_table = 1

fx_ll_hq.official_count_of_columns_in_database_file = #fx_ll_hq.database_fomat_table

fx_ll_hq.separator_reallm = ";"
fx_ll_hq.separator_csv = ";"

function fx_ll_hq.print(content)
    reaper.ShowConsoleMsg(tostring(content) .. "\n")
end

---use as this example: print_tab({csv.find_attribute_return_row_column(csvMeta, "file_name_user_database")},2)
---@param tab any
---@param row_elements any
function fx_ll_hq.print_tab(tab, row_elements)
   for i = 1, #tab do
       reaper.ShowConsoleMsg(tab[i] .. "\t")
       if i % row_elements == 0 then
           reaper.ShowConsoleMsg("\n")
       end
   end
end

------------------------------------------------------------------CORE TOOLS------------------------------------------------------------------

function fx_ll_hq.get_script_path()
   local info = debug.getinfo(1,'S');
   local script_path = info.source:match[[^@?(.*[\/])[^\/]-$]]
   return script_path
end

function fx_ll_hq.GetPathToFileSameDirectoryAsScript(file_name)
   local ret_val = fx_ll_hq.get_script_path() .. file_name
   return ret_val
end

function fx_ll_hq.GetLocationInCsvFile(csvMeta, var_name_search)
   local t = csv.get_location(csvMeta,var_name_search)
   --fx_ll_hq.print("t.row == " .. tostring(t.row) .. " t.col == " .. tostring(t.col) .. "\n")
   if (t and (t.row == nil or t.col == nil)) or t == nil then 
      reaper.ShowMessageBox("Could not find " .. var_name_search .. " in " .. fx_ll_hq.file_path_global_variables, "Error", 0)
      return nil
   end
   return t
end

---comment 
---@param var_name_search any
---@param csvMeta any csvMeta
---@param isVertical boolean global variable file is vertical, else not vertical
---@param index number position from the var_name_search
---@return string|unknown
function fx_ll_hq.GetVar(csvMeta, var_name_search, isVertical, index)
   local t = fx_ll_hq.GetLocationInCsvFile(csvMeta, var_name_search)
   --fx_ll_hq.print("t.row == " .. tostring(t.row) .. " t.col == " .. tostring(t.col) .. "\n")
   if t and (t.row == nil or t.col == nil) then return nil end
   if t and isVertical == true then
      
      return csv.get_attribute(csvMeta, t.row, t.col+index)
   elseif t and isVertical == false then
      return csv.get_attribute(csvMeta, t.row+index, t.col)
   else
      return nil
   end
end



 -- @description Search action by command ID or name
-- @author cfillion
-- @version 2.0.2
-- @changelog Enable ReaImGui's backward compatibility shims
-- @link Forum thread https://forum.cockos.com/showthread.php?t=226107
-- @screenshot https://i.imgur.com/yqkvZvf.gif
-- @donation https://www.paypal.com/cgi-bin/webscr?business=T3DEWBQJAV7WL&cmd=_donations&currency_code=CAD

local AL_SECTIONS = {
   { id=0,     name='Main'                   },
   { id=100,   name='Main (alt recording)'   },
   { id=32060, name='MIDI Editor'            },
   { id=32061, name='MIDI Event List Editor' },
   { id=32062, name='MIDI Inline Editor'     },
   { id=32063, name='Media Explorer'         },
 }

 local function iterateActions(section)
   local i = 0
 
   return function()
     local retval, name = reaper.CF_EnumerateActions(section.id, i, '')
     if retval > 0 then
       i = i + 1
       return retval, name
     end
   end
 end
 
 local function findById(section, commandId)
   local numericId = reaper.NamedCommandLookup(commandId)
   local actionName = reaper.CF_GetCommandText(section.id, numericId)
   return actionName
 end
 
 local function findByName(section, actionName)
   local commandId 
   for id, name in iterateActions(section) do
     if name == actionName then
       local namedId = id and reaper.ReverseNamedCommandLookup(id)
       commandId = namedId and ('_' .. namedId) or tostring(id)
       return commandId
     end
   end
   --commandId = ''
 end

 ---------------------------------------- GET SCRIPTS COMMAND ID -----------------------------------------------
local actionName = "Script: Hipox - FX LL HQ - Set All Plugins From User Database To High Quality Mode.lua"
fx_ll_hq.CommabdID_SetAllPluginsFromUserDatabaseToHighQualityMode = findByName(AL_SECTIONS[1], actionName)
-- fx_ll_hq.print("fx_ll_hq.CommabdID_SetAllPluginsFromUserDatabaseToHighQualityMode == " .. fx_ll_hq.CommabdID_SetAllPluginsFromUserDatabaseToHighQualityMode .. "\n")

actionName = "Script: Hipox - FX LL HQ - Set All Plugins From User Database To Low Latency Mode.lua"
fx_ll_hq.CommabdID_SetAllPluginsFromUserDatabaseToLowLatencyMode = findByName(AL_SECTIONS[1], actionName)
-- fx_ll_hq.print("fx_ll_hq.CommabdID_SetAllPluginsFromUserDatabaseToLowLatencyMode == " .. fx_ll_hq.CommabdID_SetAllPluginsFromUserDatabaseToLowLatencyMode .. "\n")

actionName = "Script: Hipox - FX LL HQ - Initialize ReaLlm with User Settings.lua"
fx_ll_hq.CommabdID_InitializeReaLlmWithUserSettings = findByName(AL_SECTIONS[1], actionName)
-- fx_ll_hq.print("fx_ll_hq.CommabdID_InitializeReaLlmWithUserSettings == " .. fx_ll_hq.CommabdID_InitializeReaLlmWithUserSettings .. "\n")
------------------------------------------END GET SCRIPTS COMMAND ID -------------------------------------------

------------------------------------------------------------------CORE TOOLS END------------------------------------------------------------------
------------------------------------------------------------------GLOBAL VARIABLES ASSIGN------------------------------------------------------------------
fx_ll_hq.script_path = fx_ll_hq.get_script_path()
fx_ll_hq.resources_path = reaper.GetResourcePath()

fx_ll_hq.file_name_global_variables = "FX LL HQ Global Variables.csv"
fx_ll_hq.default_file_name_user_database = "FX LL HQ User Database.csv"
fx_ll_hq.gv_identifier_user_database = "file_name_user_database"
fx_ll_hq.file_path_global_variables = fx_ll_hq.get_script_path() .. fx_ll_hq.file_name_global_variables

fx_ll_hq.csvGlobalVariables = csv.new()
csv.load_csvfile(fx_ll_hq.csvGlobalVariables, fx_ll_hq.file_path_global_variables)

fx_ll_hq.file_name_user_database = fx_ll_hq.GetVar(fx_ll_hq.csvGlobalVariables, "file_name_user_database", true, 1)
-- fx_ll_hq.file_path_user_database = fx_ll_hq.GetPathToFileSameDirectoryAsScript(fx_ll_hq.file_name_user_database)
fx_ll_hq.file_path_user_database = fx_ll_hq.get_script_path() .. "/Database Files/" .. fx_ll_hq.file_name_user_database

fx_ll_hq.startupFilePath = r.GetResourcePath()..'/Scripts/__startup.lua'

fx_ll_hq.csvUserDatabase = csv.new()
csv.load_csvfile(fx_ll_hq.csvUserDatabase, fx_ll_hq.file_path_user_database)

--- GUI ELEMENTS ---
fx_ll_hq.value_checkbox_edit_popup_1_ID = "value_checkbox_edit_popup_1"
fx_ll_hq.value_checkbox_edit_popup_1 = nil

fx_ll_hq.value_checkbox_close_script_1_ID = "value_checkbox_close_script_1"
fx_ll_hq.value_checkbox_close_script_1 = nil

fx_ll_hq.reallm_pref_action_PDC_Limit_ID = "reallm_pref_action_PDC_Limit"
fx_ll_hq.reallm_pref_action_PDC_Limit = nil

fx_ll_hq.reallm_pref_action_AllowAutomaticStartup_ID = "reallm_pref_action_AllowAutomaticStartup"
fx_ll_hq.reallm_pref_action_AllowAutomaticStartup = nil

fx_ll_hq.reallm_pref_action_ProcessMonitorChain_ID = "reallm_pref_action_ProcessMonitorChain"
fx_ll_hq.reallm_pref_action_ProcessMonitorChain = nil

fx_ll_hq.reallm_pref_action_SetLlmAndHqmForPlugins_ID = "reallm_pref_action_SetLlmAndHqmForPlugins"
fx_ll_hq.reallm_pref_action_SetLlmAndHqmForPlugins = nil

fx_ll_hq.global_mode_switch_ProcessTrackFXs_ID = "global_mode_switch_ProcessTrackFXs"
fx_ll_hq.global_mode_switch_ProcessTrackFXs = nil

fx_ll_hq.global_mode_switch_ProcessTakeFXs_ID = "global_mode_switch_ProcessTakeFXs"
fx_ll_hq.global_mode_switch_ProcessTakeFXs = nil

fx_ll_hq.global_mode_switch_ProcessInputFx_ID = "global_mode_switch_ProcessInputFx"
fx_ll_hq.global_mode_switch_ProcessInputFx = nil

------------------------------------------------------------------GLOBAL VARIABLES END------------------------------------------------------------------

function fx_ll_hq.GetGlobalSharedVariables()
   fx_ll_hq.value_checkbox_edit_popup_1 = fx_ll_hq.GetVar(fx_ll_hq.csvGlobalVariables,  fx_ll_hq.value_checkbox_edit_popup_1_ID, true, 1)   
   fx_ll_hq.value_checkbox_close_script_1 = fx_ll_hq.GetVar(fx_ll_hq.csvGlobalVariables,  fx_ll_hq.value_checkbox_close_script_1_ID, true, 1)
   fx_ll_hq.reallm_pref_action_AllowAutomaticStartup = fx_ll_hq.GetVar(fx_ll_hq.csvGlobalVariables,  fx_ll_hq.reallm_pref_action_AllowAutomaticStartup_ID, true, 1)
   fx_ll_hq.reallm_pref_action_ProcessMonitorChain = fx_ll_hq.GetVar(fx_ll_hq.csvGlobalVariables,  fx_ll_hq.reallm_pref_action_ProcessMonitorChain_ID, true, 1)
   fx_ll_hq.reallm_pref_action_SetLlmAndHqmForPlugins = fx_ll_hq.GetVar(fx_ll_hq.csvGlobalVariables,  fx_ll_hq.reallm_pref_action_SetLlmAndHqmForPlugins_ID, true, 1)
   fx_ll_hq.reallm_pref_action_PDC_Limit = fx_ll_hq.GetVar(fx_ll_hq.csvGlobalVariables,  fx_ll_hq.reallm_pref_action_PDC_Limit_ID, true, 1)
   fx_ll_hq.global_mode_switch_ProcessTrackFXs = fx_ll_hq.GetVar(fx_ll_hq.csvGlobalVariables,  fx_ll_hq.global_mode_switch_ProcessTrackFXs_ID, true, 1)
   fx_ll_hq.global_mode_switch_ProcessTakeFXs = fx_ll_hq.GetVar(fx_ll_hq.csvGlobalVariables,  fx_ll_hq.global_mode_switch_ProcessTakeFXs_ID, true, 1)
   fx_ll_hq.global_mode_switch_ProcessInputFx = fx_ll_hq.GetVar(fx_ll_hq.csvGlobalVariables,  fx_ll_hq.global_mode_switch_ProcessInputFx_ID, true, 1)
end

fx_ll_hq.GetGlobalSharedVariables()

function fx_ll_hq.SaveGlobalSharedVariables()
   fx_ll_hq.SetVar(fx_ll_hq.csvGlobalVariables, fx_ll_hq.file_path_global_variables ,fx_ll_hq.value_checkbox_edit_popup_1_ID, true, 1, fx_ll_hq.value_checkbox_edit_popup_1)
   fx_ll_hq.SetVar(fx_ll_hq.csvGlobalVariables, fx_ll_hq.file_path_global_variables ,fx_ll_hq.value_checkbox_close_script_1_ID, true, 1, fx_ll_hq.value_checkbox_close_script_1)
   fx_ll_hq.SetVar(fx_ll_hq.csvGlobalVariables, fx_ll_hq.file_path_global_variables ,fx_ll_hq.reallm_pref_action_AllowAutomaticStartup_ID, true, 1, fx_ll_hq.reallm_pref_action_AllowAutomaticStartup)
   fx_ll_hq.SetVar(fx_ll_hq.csvGlobalVariables, fx_ll_hq.file_path_global_variables ,fx_ll_hq.reallm_pref_action_ProcessMonitorChain_ID, true, 1, fx_ll_hq.reallm_pref_action_ProcessMonitorChain)
   fx_ll_hq.SetVar(fx_ll_hq.csvGlobalVariables, fx_ll_hq.file_path_global_variables ,fx_ll_hq.reallm_pref_action_SetLlmAndHqmForPlugins_ID, true, 1, fx_ll_hq.reallm_pref_action_SetLlmAndHqmForPlugins)
   fx_ll_hq.SetVar(fx_ll_hq.csvGlobalVariables, fx_ll_hq.file_path_global_variables ,fx_ll_hq.reallm_pref_action_PDC_Limit_ID, true, 1, fx_ll_hq.reallm_pref_action_PDC_Limit)
   fx_ll_hq.SetVar(fx_ll_hq.csvGlobalVariables, fx_ll_hq.file_path_global_variables ,fx_ll_hq.global_mode_switch_ProcessTrackFXs_ID, true, 1, fx_ll_hq.global_mode_switch_ProcessTrackFXs)
   fx_ll_hq.SetVar(fx_ll_hq.csvGlobalVariables, fx_ll_hq.file_path_global_variables ,fx_ll_hq.global_mode_switch_ProcessTakeFXs_ID, true, 1, fx_ll_hq.global_mode_switch_ProcessTakeFXs)
   fx_ll_hq.SetVar(fx_ll_hq.csvGlobalVariables, fx_ll_hq.file_path_global_variables ,fx_ll_hq.global_mode_switch_ProcessInputFx_ID, true, 1, fx_ll_hq.global_mode_switch_ProcessInputFx)
end

function fx_ll_hq.ExecuteAtStart()
   fx_ll_hq.UnmarkFilterCsvTableDatabase(fx_ll_hq.csvUserDatabase)
end

function fx_ll_hq.ExecuteAtExit()
   fx_ll_hq.WriteOrUpdateEntryInStartupFile_ReaLlm_Init_Settings(fx_ll_hq.reallm_pref_action_AllowAutomaticStartup)
end

------------------------------------------------------------------TOOLS------------------------------------------------------------------

---comment
---@param csvMeta any
---@param path string
---@param var_name_search string
---@param isVertical boolean global variable file is vertical, else not vertical
---@param index number
---@param content any
---@return nil
function fx_ll_hq.SetVar(csvMeta,path,var_name_search, isVertical, index, content)
   --print_tab({csv.find_attribute_return_row_column(csvMeta, var_name_search)},2)
   fx_ll_hq.print("var_name_search: " .. var_name_search .. " content: " .. tostring(content) .. "\n")
   local t = fx_ll_hq.GetLocationInCsvFile(csvMeta, var_name_search)
   if t == nil then fx_ll_hq.print("t == nil\n"); return nil end
   fx_ll_hq.print("Location of " .. var_name_search .. " is row: " .. tostring(t.row) .. " col: " .. tostring(t.col) .. "\n")
   --fx_ll_hq.print_tab(t, 2)
   if t and (t.row == nil or t.col == nil) then return nil end
   local ret
   if isVertical == true and t then
      ret = csv.set_attribute(csvMeta, t.row, t.col+index, content)
   elseif isVertical == false and t then
      ret = csv.set_attribute(csvMeta, t.row+index, t.col, content)
   end
   if ret then csv.write_csvfile(csvMeta, path) else reaper.ShowMessageBox("Could not set " .. var_name_search .. " to " .. tostring(content), "Error", 0) end
end

---comment
---@param csvMeta any
---@param var_name_search string
---@param isVertical boolean
---@param index number
---@param content any
function fx_ll_hq.SetVarWithPrompt(csvMeta, path, var_name_search, isVertical, index, content)
   local ret = reaper.ShowMessageBox("Set " .. var_name_search .. " to " .. content .. "?", "Set Global Variable", 1)
   if ret == 1 then
      fx_ll_hq.SetVar(csvMeta, path, var_name_search, isVertical, index, content)
      return true
   else
      return false
   end
end

------------------------------------------------------------------TOOLS END------------------------------------------------------------------

function fx_ll_hq.IsNumber(value)
   return tonumber(value) and true or false
end

function fx_ll_hq.file_exists_file_path(file_path)
   local f = io.open(file_path, "r")
   return f ~= nil and io.close(f)
end

function fx_ll_hq.file_exists_in_same_dir_as_script_name(name)
   local f = io.open(fx_ll_hq.GetPathToFileSameDirectoryAsScript(name), "r")
   return f ~= nil and io.close(f)
end


---comment
---@param folder_path any folder_path
---@param file_name any file_name
---@param keep_file_name_if_not_exist any to initiate set to -1 (false)
---@param flag_cancel any to initiate set to -1 (false)
---@param flag_first_time any to initiate set to -1 (true)
---@param flag_new_file any to initiate set to -1 (true)
---@param repeat_run any to initiate set to -1 (false)
---@return string|unknown new_user_database_path
---@return any new_user_database_name
---@return any keep_file_name_if_not_exist
---@return any flag_cancel
---@return any flag_first_time
---@return any flag_increment_file
function fx_ll_hq.CreateNewFileIfUserAgreesOrIncrementName(folder_path, file_name, keep_file_name_if_not_exist, flag_cancel, flag_first_time, flag_new_file, repeat_run)
   if keep_file_name_if_not_exist == -1 then keep_file_name_if_not_exist = false end
   if flag_cancel == -1 then flag_cancel = false end
   if flag_first_time == -1 then flag_first_time = true end
   if flag_new_file == -1 then flag_new_file = true end
   if repeat_run == -1 then repeat_run = false end
   --fx_ll_hq.print('Start of function, folder_path = ' .. folder_path .. ' file_name = ' .. file_name .. '\n')
   local file_path = folder_path .. file_name

   --print('file_path == ' .. file_path .. '\n')
   if not fx_ll_hq.file_exists_file_path(file_path) and not repeat_run then
      --fx_ll_hq.print('file does not exist\n')
      --fx_ll_hq.print("file_name == " .. file_name .. "default_file_name_user_database == " .. default_file_name_user_database)
      local default_file_name_user_database_without_extension = fx_ll_hq.default_file_name_user_database:match("(.+)%..+")
      local default_file_name_reference_database_without_extension = fx_ll_hq.default_file_name_reference_database:match("(.+)%..+")
      local default_file_name_user_database_backup_without_extension = fx_ll_hq.default_file_name_user_database_backup:match("(.+)%..+")
      if not keep_file_name_if_not_exist and file_name:match(fx_ll_hq.default_file_name_user_database_without_extension) then
         --fx_ll_hq.print("match default_file_name_user_database\n")
         file_name = fx_ll_hq.default_file_name_user_database
         file_path = folder_path .. file_name
         fx_ll_hq.SetVar(fx_ll_hq.csvGlobalVariables, fx_ll_hq.file_path_global_variables, fx_ll_hq.gv_identifier_user_database, true, 1, file_name)
         fx_ll_hq.file_path_user_database = file_path
      elseif not keep_file_name_if_not_exist and file_name:match(default_file_name_reference_database_without_extension) then
         --fx_ll_hq.print("match default_file_name_community_database\n")
         file_name = fx_ll_hq.default_file_name_community_database
         file_path = folder_path .. file_name
         fx_ll_hq.SetVar(fx_ll_hq.csvGlobalVariables, fx_ll_hq.file_path_global_variables, fx_ll_hq.gv_identifier_community_database, true, 1, file_name)
      elseif not keep_file_name_if_not_exist and file_name:match(default_file_name_user_database_backup_without_extension) then
         --fx_ll_hq.print("match default_file_name_user_database_backup\n")
         file_name = fx_ll_hq.default_file_name_user_database_backup
         file_path = folder_path .. file_name
         fx_ll_hq.SetVar(fx_ll_hq.csvGlobalVariables, fx_ll_hq.file_path_global_variables, fx_ll_hq.gv_identifier_user_database_backup, true, 1, file_name)
      else
         --fx_ll_hq.print("match nothing\n")
         --file_name = default_file_name_user_database
         --file_path = folder_path .. file_name
      end
      local file = io.open(file_path, "w")
      io.close(file)
   elseif not fx_ll_hq.file_exists_file_path(file_path) and repeat_run then
      local file = io.open(file_path, "w")
      io.close(file)
      flag_first_time = false
      --fx_ll_hq.SetVar(fx_ll_hq.csvGlobalVariables, fx_ll_hq.file_path_global_variables, fx_ll_hq.gv_identifier_user_database_backup, true, 1, file_name)
   else
      flag_first_time = false
      local ret = reaper.ShowMessageBox("File " .. file_name .. " already exists. Do you want to overwrite it?", "File already exists", 3)
      --fx_ll_hq.print(ret .. '\n')
      if ret == 6 then
         flag_new_file = false
         --print("Overwriting, just return file_path\n")
      elseif ret == 2 then
         flag_cancel = true
         --print("Cancel\n")
      else
         
         local ret = reaper.ShowMessageBox("Do you want to increment the file name?", "File already exists", 1)
         --fx_ll_hq.print(ret .. '\n')
         if ret == 1 then
            local file_name_without_extension = file_name:match("(.+)%..+")
            local file_extension = file_name:match(".+(%..+)")
            --fx_ll_hq.print('file_name_without_extension = ' .. file_name_without_extension .. ' file_extension = ' .. file_extension .. '\n')
            local file_name_incremented
            local number
            if file_name_without_extension:match("_(%d+)$") then
               local file_name_without_number = file_name_without_extension:match("(.+)_")
               number = tonumber(file_name_without_extension:match("_(%d+)$")) + 1
               --fx_ll_hq.print("number = " .. number .. '\n')
               file_name_incremented = file_name_without_number .. "_" .. number .. file_extension
            else
               number = 1
               file_name_incremented = file_name_without_extension .. "_" .. number .. file_extension
            end
            
            local path_to_incremented_file = folder_path .. "/" .. file_name_incremented
            while true do -- dangerouse, TODO: fix not use while true
               if fx_ll_hq.file_exists_file_path(path_to_incremented_file) then
                  number = number + 1
                  file_name_incremented = file_name_without_extension .. "_" .. number .. file_extension
                  path_to_incremented_file = folder_path .. file_name_incremented
               else
                  break
               end
            end
            --fx_ll_hq.print("Incremented file name = " .. file_name_incremented .. '\n')
            file_path, file_name, keep_file_name_if_not_exist, flag_cancel, flag_first_time, flag_new_file = fx_ll_hq.CreateNewFileIfUserAgreesOrIncrementName(folder_path, file_name_incremented, keep_file_name_if_not_exist, flag_cancel, flag_first_time, flag_new_file, true)
         else
            flag_cancel = true
            --print("Not overwriting, ending function before proceeding to next step\n")
         end
      end
   end
   --print('End of function, file_path = ' .. file_path .. '\n')
   return file_path, file_name, keep_file_name_if_not_exist, flag_cancel, flag_first_time, flag_new_file
end

function fx_ll_hq.create_file_if_not_present(file_path)
-- if file_path doesn't exist, it will be created
   if not fx_ll_hq.file_exists_file_path(file_path) then
      local file = io.open(file_path, "w")
      io.close(file)
   end
end

function fx_ll_hq.GetFileContextString(fp)
   local str = "\n"
   local f = io.open(fp, 'r')
   if f then
       str = f:read('all*')
       f:close()
   end
   return str
end

---comment
---@param file_path any
---@return table
function fx_ll_hq.LoadDatabaseFromCsvFileToTable(file_path)
  local table = {}
  local flag_first_row = true
  for line in io.lines(file_path) do
     local fx_identifier, par_id, ll_val, hq_val = line:match("%s*(.-)" .. fx_ll_hq.separator_csv .. "%s*(.-)" .. fx_ll_hq.separator_csv ..  "%s*(.-)" .. fx_ll_hq.separator_csv ..  "%s*(.-)$")
     -- if flag_first_row then
     --    flag_first_row = false
     -- else
        table[#table + 1] = { fx_identifier = fx_identifier , par_id = par_id, ll_val = ll_val, hq_val = hq_val }
     -- end
  end
  return table
end


--- SEXAN START ---

function fx_ll_hq.SaveStringToFile_name(str, name)
   local file_path = fx_ll_hq.get_script_path() .. name
   fx_ll_hq.SaveStringToCsvFile(str, file_path)
end

function fx_ll_hq.AppendLineToStringAsNewLine(str, line)
   if str then
      return str .. '\n' .. tostring(line) 
   else
      return tostring(line)
   end
end

function fx_ll_hq.ConvertUniqueTableToIterativeTable(table)
   local table_iterative = {}
   j = 1
   for i,_ in pairs(table) do
      table_iterative[j] = i
      j = j + 1
   end
   return table_iterative
end

function fx_ll_hq.FX_IDENTIFIER(str, tbl) -- Script: SEXAN dd FX TO SEL TRACKS SLOT
   local vst_name
   local format, developer, fx_name, identifier
   local flag_three_commas = false
   local format_type = 0
   if str:match('.vst3') then
      format = "VST3"
      format_type = 1
   elseif str:match('.dll') then
      format = "VST"
      format_type = 1
   elseif str:match('^NAME ') then
      format = "JS"
      format_type = 2
      --if str contains '|'
   elseif str:match('|') then
      format = "CLAP"
      format_type = 3
   elseif str:match('^AU') then
      format = "AU"
      format_type = 4
   else
      format = "Unknown"
      format_type = 0
   end

   if format_type == 1 then
      --fx_ll_hq.print("VST3 found on line: " ..  str .. "\n")
      --count number of commas in str
      local count = 0
      for i in str:gmatch(",") do
         count = count + 1
      end
      -- set str to contain everything after 2nd ','
      if count > 2 then
         --fx_ll_hq.print("str contains " ..  count .. " commas\n")
         -- set str to contain everything after 2nd ',' including another comma
         str = str:match(".*,(.*),") .. "," .. str:match(".*,(.*)")
         --
         --fx_ll_hq.print("str:" ..  str .. "\n")
         flag_three_commas = true
      else
         str = str:match(".*,(.*)")
      end
      if str == nil then goto continue end
      --fx_ll_hq.print("str after 1st comma: " ..  str .. "\n")
      -- developer is everything between first ( and first ) in str
      if flag_three_commas then
         -- developer is everything between first ( and , plus everything between , and first )
         developer = str:match("%((.-),") .. "," .. str:match(",(.-)%)")
      else
         developer = str:match("%((.-)%)")
      end
      -- find if string contains '!!!VSTi'
      if str:match('!!!VSTi') then
         format = format .. "i"
         -- set str to contain everything before '!!!VSTi'
         if flag_three_commas then
            -- str is everything between beginning and comma plus everything between , and !!!VSTi
            str =  str:match("(.*),") .. "," .. str:match(",(.*)!!!VSTi")
         else
            str = str:match("(.*)!!!VSTi")
         end
         --fx_ll_hq.print("VST3i found on line: " ..  str .. "\n")
      else
         --fx_ll_hq.print("VST3 found on line: " ..  str .. "\n")
            
      end
      -- fx_name is everything until first ' (' in str
      fx_name = str:match("(.*) %(.*")

      if not str:match('<SHELL>') then
         identifier = format .. ": " .. str
      else
         goto continue
      end
   elseif format_type == 2 then
      --everything after 'NAME '
      --everything after 'JS: '
      str = str:match("JS: (.*)")
      if str then str = str:gsub('"','') else goto continue end
      -- fx_ll_hq.print("JS found on line: " ..  str .. "\n")
      -- str = str:match("NAME[ ](.*)")
      -- does str contain '"''
      if str:match('"') then
         -- set str to contain everything between first " and last "
         str = str:match('"(.*)"')
      end
      if str then
         local count = 0
         -- match only for '/'
         for i in str:gmatch("/") do
            count = count + 1
         end
         if count > 0 then
            
            -- developer is everything before first / in str
            developer = str:match("([^/]*)")
            -- fx_name is everything after first / in str
            fx_name = str:match("/(.*)")
         else
            --fx_ll_hq.print("str contains " ..  count .. " /'s : " .. str .. "\n")
            -- developer is everything before first / in str
            developer = "Unknown"
            -- fx_name is everything after first / in str
            fx_name = str
         end
         identifier = format .. ": " .. str

      else
         goto continue
      end
   elseif format_type == 3 then
      --one or more digits before '|' in str
      local is_synth = tonumber(str:match("(%d)|"))
      if is_synth == 1 then
         format = format .. "i"
      end
      --everything after '|'
      str = str:match("|(.*)")
      developer = str:match("%((.-)%)")

      if str then
         identifier = format .. ": " .. str
         -- fx_name is everything before first ' (' in str
         fx_name = str:match("(.*) %(.*")
      else
         goto continue
      end
   elseif format_type == 4 then
      str = string.match(str, '%b""')
      str = string.gsub(str, '"', "")
      developer = str:match('(.*):')
      --everything between : and end of string
      fx_name = str:match(': (.*)')
      --fx_ll_hq.print("developer: " ..  developer .. " fx_name: " .. fx_name .. "\n")
      for i = 1, #tbl do
         if tbl[i]:match(fx_name) then
            -- match <!inst>
            if tbl[i]:match('<inst>') then
               format = format .. "i"
               break
            end
         end
      end
      identifier = format .. ": " .. fx_name
   else
      goto continue
   end

   if identifier and (format == nil or developer == nil or fx_name == nil) then
      fx_ll_hq.print("identifier: " ..  identifier .. "\n")
   end
   if identifier then
      return identifier, format, fx_name, developer
   end
   ::continue::
end

function fx_ll_hq.GetFileContext(fp)
   local str = "\n"
   local f = io.open(fp, 'r')
   if f then
       str = f:read('a')
       f:close()
   end
   return str
end

---comment
---@param min any
---@param value any
---@param max any
---@return number
function fx_ll_hq.clamp(min, value, max)
   return math.max(min, math.min(max, value))
end

-- Fill function with desired database
function fx_ll_hq.Fill_fx_list() -- Script Edit: SEXAN dd FX TO SEL TRACKS SLOT
   local tbl_identifier   = {}
    local tbl        = {}

    -- extended version of file paths

    local reaper_vstplugins_ini = fx_ll_hq.resources_path .. "/reaper-vstplugins.ini"
    local reaper_vstplugins_str = fx_ll_hq.GetFileContextString(reaper_vstplugins_ini)

    local reaper_vstplugins_64_ini = fx_ll_hq.resources_path .. "/reaper-vstplugins64.ini"
    local reaper_vstplugins_64_str = fx_ll_hq.GetFileContextString(reaper_vstplugins_64_ini)

    local reaper_jsfx_ini = fx_ll_hq.resources_path .. "/reaper-jsfx.ini"
    local reaper_jsfx_str = fx_ll_hq.GetFileContextString(reaper_jsfx_ini)

    local reaper_clap_win64_ini = fx_ll_hq.resources_path .. "/reaper-clap-win64.ini"
    local reaper_clap_win64_str = fx_ll_hq.GetFileContextString(reaper_clap_win64_ini)

    local reaper_auplugins64_bc_ini = fx_ll_hq.resources_path .. "/reaper-auplugins64-bc.ini"
    local reaper_auplugins64_bc_str = fx_ll_hq.GetFileContextString(reaper_auplugins64_bc_ini)

    local reaper_auplugins64_ini = fx_ll_hq.resources_path .. "/reaper-auplugins64.ini"
    local reaper_auplugins64_str = fx_ll_hq.GetFileContextString(reaper_auplugins64_ini)

    --sexan's original version of file paths
   --  local vst_path   = r.GetResourcePath() .. "/reaper-vstplugins64.ini"
   --  local vst_str    = fx_ll_hq.GetFileContext(vst_path)

   --  local vst_path32 = r.GetResourcePath() .. "/reaper-vstplugins.ini"
   --  local vst_str32  = fx_ll_hq.GetFileContext(vst_path32)

   --  local jsfx_path  = r.GetResourcePath() .. "/reaper-jsfx.ini"
   --  local jsfx_str   = fx_ll_hq.GetFileContext(jsfx_path)

   --  local au_path    = r.GetResourcePath() .. "/reaper-auplugins64-bc.ini"
   --  local au_str     = fx_ll_hq.GetFileContext(au_path)

   --  local plugins    = vst_str .. vst_str32 .. jsfx_str .. au_str -- use for sexan's original version of file paths
    local plugins    = reaper_vstplugins_str .. reaper_vstplugins_64_str .. reaper_jsfx_str .. reaper_clap_win64_str .. reaper_auplugins64_bc_str .. reaper_auplugins64_str -- use for extended version of file paths
    fx_ll_hq.SaveStringToFile_name(plugins, "FXs_summary_all_present.txt")

    for line in plugins:gmatch('[^\r\n]+') do tbl[#tbl + 1] = line end


    -- CREATE NODE LIST
    for i = 1, #tbl do 
      local identifier = fx_ll_hq.FX_IDENTIFIER(tbl[i], tbl)
        if identifier then
         tbl_identifier[#tbl_identifier + 1] = identifier
        end
    end

    -- PRINT ALL IDENTIFIERS TO FILE
   --  local str = ""
   --  for i = 1, #tbl do 
   --    local identifier = fx_ll_hq.FX_IDENTIFIER(tbl[i], tbl)
   --      if identifier then
   --       str = str .. identifier .. "\n" -- dev tool
   --      end
   --  end
   -- fx_ll_hq.SaveStringToFile_name(str, "FXs_summary_test_output.txt") --  dev tool
   -- END OF PRINT ALL IDENTIFIERS TO FILE

    return tbl_identifier
end

function fx_ll_hq.Lead_Trim_ws(s) return s:match '^%s*(.*)' end
function fx_ll_hq.FormatString(s) return s:format('%q') end

function fx_ll_hq.Filter_actions(fx_identifier_tab,filter_text)

   --fx_ll_hq.print("filter_text: " .. tostring(filter_text) .. " #fx_identifier_tab: " .. tostring(#fx_identifier_tab) .. "\n")
   filter_text = fx_ll_hq.Lead_Trim_ws(filter_text)
   --fx_ll_hq.print("here\n")
   local is_filter_text_empty = filter_text == nil or filter_text == ''
   --fx_ll_hq.print("is_filter_text_empty: " .. tostring(is_filter_text_empty) .. "\n")
   local t = {}
   --if filter_text == "" then return t end
   for i = 1, #fx_identifier_tab do
      if is_filter_text_empty then  
         t[#t + 1] = fx_identifier_tab[i]
      else
         --if not table[i] then goto continue end
         local content = fx_identifier_tab[i]
         local name = content:lower()
         local found = true
         for word in filter_text:gmatch("%S+") do
            if not name:find(word:lower(), 1, true) then
                  found = false
                  break
            end
         end
         if found then t[#t + 1] = content end
      end
   end
   return t
end

function fx_ll_hq.Filter_actions_2D(fx_identifier_tab,filter_text)
   --fx_ll_hq.print("filter_text: " .. tostring(filter_text) .. " #fx_identifier_tab: " .. tostring(#fx_identifier_tab) .. "\n")
   filter_text = fx_ll_hq.Lead_Trim_ws(filter_text)
   --fx_ll_hq.print("here\n")
   local is_filter_text_empty = filter_text == nil or filter_text == ''
   --fx_ll_hq.print("is_filter_text_empty: " .. tostring(is_filter_text_empty) .. "\n")
   local t = {}
   --if filter_text == "" then return t end
   for i = 1, #fx_identifier_tab do
      if is_filter_text_empty then 
         t[#t + 1] = { fx_identifier_tab[i][1], fx_identifier_tab[i][2] }
      else
         --if not table[i] then goto continue end
         local content = fx_identifier_tab[i][2]
         local name = content:lower()
         local found = true
         for word in filter_text:gmatch("%S+") do
            if not name:find(word:lower(), 1, true) then
                  found = false
                  break
            end
         end
         if found then t[#t + 1] = {fx_identifier_tab[i][1], content} end
      end
   end
   return t
end

--- SEXAN END ---

function fx_ll_hq.SaveAllExistingFXsIntoFilesSameDirAsAcript()
   local USER_FX_IDENTIFIER_TAB = fx_ll_hq.Fill_fx_list()
   --fx_ll_hq.create_fx_summary_all_present_path_file() -- USEFL FOR DEBUGGING
   local present_fx_identifiers_path = fx_ll_hq.get_script_path() .. "User Present FX - Identifiers.txt"
   local str = fx_ll_hq.TableToString_1D(USER_FX_IDENTIFIER_TAB, false, true)
   --fx_ll_hq.print("fx_summary_all_present_path = " .. fx_summary_all_present_path .. '\n')
   fx_ll_hq.create_file_if_not_present(present_fx_identifiers_path)
   fx_ll_hq.print("Saving all existing FXs into file: " .. tostring(present_fx_identifiers_path) .. '\n')
   fx_ll_hq.print("Number of FXs: " .. tostring(#USER_FX_IDENTIFIER_TAB) .. '\n')
   -- table.save(USER_FX_IDENTIFIER_TAB, present_fx_identifiers_path) -- save "USER_FX_IDENTIFIER_TAB" table to file
   fx_ll_hq.SaveStringToCsvFile(str, present_fx_identifiers_path)
   return present_fx_identifiers_path
end

---comment overwrites existing file
---@param string_to_save any
---@param file_path any
function  fx_ll_hq.SaveStringToCsvFile(string_to_save, file_path) 
   local file = io.open(file_path, "w")
   if file then
      file:write(string_to_save)
      file:write('\n')
      file:close()
   else
      --fx_ll_hq.print("Error: could not open file " .. file_path .. " for writing\n")
   end
end

function fx_ll_hq.ReturnCountRowsInFile(file_path)
   --if fx_ll_hq.IsDatabaseFileValidFeedbackTextReturn(file_path) then
      local ctr = 0
      for _ in io.lines(file_path) do
      ctr = ctr + 1
      end
      return ctr
   --else
   --    return nil
   -- end
end

function fx_ll_hq.ReturnCountNonEmptyRowsInFile(file_path)
   --if fx_ll_hq.IsDatabaseFileValidFeedbackTextReturn(file_path) then
      local ctr = 0
      for line in io.lines(file_path) do
         if line ~= "" then
            ctr = ctr + 1
         end
      end
      return ctr
   --else
   --    return nil
   -- end
end

function fx_ll_hq.open_file_path_folder_in_explorer(file_path)
   if fx_ll_hq.file_exists(file_path) then
      reaper.CF_ShellExecute(file_path)
   end
end

function fx_ll_hq.OpenContainingFolderInExplorer()
   local folder_path = fx_ll_hq.get_script_path()
   if folder_path then
      reaper.CF_ShellExecute(folder_path)
   end
end


function fx_ll_hq.OpenContainingFolderInExplorerPrompt()
   local retval = reaper.ShowMessageBox("Do you want to open containing folder in Explorer?", "Open Containing Folder", 4)
   --fx_ll_hq.print(retval)
   if retval == 6 then
         fx_ll_hq.OpenContainingFolderInExplorer()
         return true
   else
         return false

   end
end

function fx_ll_hq.SetUserDatabaseFilePrompt()
   local retval = reaper.ShowMessageBox("Do you want to create default User Database based on existing plugins and Community Database?", "File does not exist", 4)
   --fx_ll_hq.print(retval)
   if retval == 6 then
         fx_ll_hq.SetupUserDatabaseFromReferenceDatabaseWithExistingPluginsOnly(false)
         return true
   else
         return false
   end
end

function fx_ll_hq.SaveTableToCsvFile(table, file_path)
   --fx_ll_hq.print('file_path: ' .. file_path .. '\n')
   local file = assert(io.open(file_path, "w"))
   --fx_ll_hq.print('path_file: ' .. file_path .. '\n')
   for i = 1, #table do
      for k, v in pairs(table[i]) do
         --fx_ll_hq.print('k: ' .. k .. ' v: ' .. v .. '\n')
         file:write(tostring(v))
         if k ~= #table[i] then
            file:write(fx_ll_hq.separator_csv)
         end
      end
      file:write("\n")
   end
   file:close()
end

function fx_ll_hq.TableToString_2D(table, newline_at_end)
   local string = ""
   --fx_ll_hq.print("#table == " .. #table .. '\n')
   for i = 1, #table do
      for k, v in pairs(table[i]) do
         --fx_ll_hq.print('k: ' .. tostring(k) .. ' v: ' .. tostring(v) .. '\n')
         string = tostring(string) .. tostring(v)
         if k ~= #table[i] then
            string = tostring(string) .. fx_ll_hq.separator_csv
         end
      end
      if i == #table and not newline_at_end then
         goto skip
      else
         string = string .. "\n"
      end
   end
   ::skip::
   return string
end

function fx_ll_hq.TableToString_1D(table, newline_at_end, separate_rows_with_newline)
   local string = ""
      for k, v in pairs(table) do
         --fx_ll_hq.print('k: ' .. tostring(k) .. ' v: ' .. tostring(v) .. '\n')
         string = tostring(string) .. tostring(v)
         if k ~= #table then
            string = tostring(string) .. fx_ll_hq.separator_csv
            if separate_rows_with_newline then
               string = string .. "\n"
            end
         end
      end
      if newline_at_end then
         string = string .. "\n"
      end
   return string
end




function fx_ll_hq.GetValuesFromCsvTableLineFxDatabase(csvMeta,line_number)
   local row_number, fx_identifier, par_id, ll_val, hq_val, default_ll_val ,default_hq_val, flag_filter, flag_active

   row_number = csv.get_attribute(csvMeta,line_number, fx_ll_hq.GetPositionOfElementInIterativeTable(fx_ll_hq.database_fomat_table, "Row"))
   fx_identifier = csv.get_attribute(csvMeta,line_number, fx_ll_hq.GetPositionOfElementInIterativeTable(fx_ll_hq.database_fomat_table, "FX Identifier"))
   par_id = csv.get_attribute(csvMeta,line_number, fx_ll_hq.GetPositionOfElementInIterativeTable(fx_ll_hq.database_fomat_table, "Parameter Index"))
   ll_val = csv.get_attribute(csvMeta,line_number, fx_ll_hq.GetPositionOfElementInIterativeTable(fx_ll_hq.database_fomat_table, "Low Latency Value"))
   hq_val = csv.get_attribute(csvMeta,line_number, fx_ll_hq.GetPositionOfElementInIterativeTable(fx_ll_hq.database_fomat_table, "High Quality Value"))
   default_ll_val = csv.get_attribute(csvMeta,line_number, fx_ll_hq.GetPositionOfElementInIterativeTable(fx_ll_hq.database_fomat_table, "Default Low Latency Value"))
   default_hq_val = csv.get_attribute(csvMeta,line_number, fx_ll_hq.GetPositionOfElementInIterativeTable(fx_ll_hq.database_fomat_table, "Default High Quality Value"))
   flag_active = csv.get_attribute(csvMeta,line_number, fx_ll_hq.GetPositionOfElementInIterativeTable(fx_ll_hq.database_fomat_table, "Active"))
   flag_filter = csv.get_attribute(csvMeta,line_number, fx_ll_hq.GetPositionOfElementInIterativeTable(fx_ll_hq.database_fomat_table, "Filter"))

   if fx_identifier == nil or par_id == nil or ll_val == nil or hq_val == nil then
      --fx_ll_hq.print('Error: while reading line ' .. line_number .. ' from csv file\n')
      return nil, nil, nil, nil, nil, nil, nil, nil, nil
   end
   return row_number, fx_identifier, par_id, ll_val, hq_val, default_ll_val, default_hq_val, flag_active, flag_filter -- potentially dangerous! TODO
end

function fx_ll_hq.GetAttributeByRowAndColumnFromCsvTable(csvMeta, row, column)
   -- fx_ll_hq.print('row: ' .. row .. ' column: ' .. column .. '\n')
   return csv.get_attribute(csvMeta,row, column)
end

function fx_ll_hq.SetAttributeByRowAndColumnToCsvTable(csvMeta, row, column, value)
   --fx_ll_hq.print('row: ' .. row .. ' column: ' .. column .. '\n')
   return csv.set_attribute(csvMeta,row, column, value)
end


function fx_ll_hq.CopyPasteContentOfFile(file_path_from, file_path_to)
   if fx_ll_hq.file_exists_file_path(file_path_from) and fx_ll_hq.file_exists_file_path(file_path_to) then
      local content = fx_ll_hq.GetFileContextString(file_path_from)
      fx_ll_hq.SaveStringToCsvFile(content, file_path_to)
      return true
   else
      --fx_ll_hq.print('While copying/pasting content, one of files does not exist\n')
      return false
   end
end

function fx_ll_hq.CopyPasteContentOfOldUserDatabaseToNewUserDatabasePrompt(file_path_from, file_path_to)
   local retval = reaper.ShowMessageBox("Do you want to copy content of old User Database to new User Database?", "File does not exist", 4)
   if retval == 6 then
       fx_ll_hq.CopyPasteContentOfFile(file_path_from, file_path_to)
   end
end


function fx_ll_hq.SetUserDatabaseFile()
   local retval, retval_csv = reaper.GetUserInputs("Set User Database File", 1, "File Name:,extrawidth=100", fx_ll_hq.GetVar(fx_ll_hq.csvGlobalVariables, "file_name_user_database", true, 1))
   if retval then
       --fx_ll_hq.print("retval: " .. tostring(retval) .. " retval_csv: " .. tostring(retval_csv) .. "\n")
       if not fx_ll_hq.file_exists_in_same_dir_as_script_name(retval_csv) then
           local retval = reaper.ShowMessageBox("File does not exist. Do you want to create it? \n(No == Set global variable to new file name)", "File does not exist", 3)
           --fx_ll_hq.print(retval)
           if retval == 6 then
               --fx_ll_hq.print("File does not exists. User chose to create it\n")
               fx_ll_hq.create_file_if_not_present(fx_ll_hq.GetPathToFileSameDirectoryAsScript(retval_csv))
               fx_ll_hq.SetVar(fx_ll_hq.csvGlobalVariables, fx_ll_hq.file_path_global_variables, fx_ll_hq.gv_identifier_user_database, true, 1, retval_csv)
               if not fx_ll_hq.SetUserDatabaseFilePrompt() then
                   fx_ll_hq.CopyPasteContentOfOldUserDatabaseToNewUserDatabasePrompt(fx_ll_hq.file_path_user_database, fx_ll_hq.GetPathToFileSameDirectoryAsScript(retval_csv))
               end
           elseif retval == 2 then
               --fx_ll_hq.print("Cancel, nothing happens\n")
               return
           else
               --fx_ll_hq.print("File does not exists. User chose to only set global variable typed string\n")
           end
       else
           --fx_ll_hq.print("File exists, setting global variable to it\n")
           fx_ll_hq.SetVar(fx_ll_hq.csvGlobalVariables, fx_ll_hq.file_path_global_variables, fx_ll_hq.gv_identifier_user_database, true, 1, retval_csv)
           if not fx_ll_hq.SetUserDatabaseFilePrompt() then
               fx_ll_hq.CopyPasteContentOfOldUserDatabaseToNewUserDatabasePrompt(fx_ll_hq.file_path_user_database, fx_ll_hq.GetPathToFileSameDirectoryAsScript(retval_csv))
           end
       end 
   end
end

---comment
---@param flag_create_new_file any if set true, process  will allow to directly create 
function fx_ll_hq.SetupUserDatabaseFromReferenceDatabaseWithExistingPluginsOnly(flag_create_new_file)

   USER_FX_IDENTIFIER_TAB = Fill_fx_list()

   local user_database_path, user_database_name

   if flag_create_new_file then
      local keep_file_name_if_not_exist, flag_cancel ,flag_first_time, flag_new_file
      --fx_ll_hq.print("file_name_user_database: " .. tostring(fx_ll_hq.file_name_user_database) .. "\n")
      user_database_path, user_database_name, keep_file_name_if_not_exist, flag_cancel ,flag_first_time, flag_new_file = fx_ll_hq.CreateNewFileIfUserAgreesOrIncrementName(fx_ll_hq.script_path, fx_ll_hq.file_name_user_database,-1, -1, -1, -1, -1)
      --fx_ll_hq.print("user_database_path: " .. tostring(user_database_path) .. " user_database_name:" .. tostring(user_database_name) .. " flag_cancel == " .. tostring(flag_cancel) .. " flag_first_time == " .. tostring(flag_first_time) .. " flag_new_file == " .. tostring(flag_new_file) .. "\n")

      if not flag_cancel and flag_new_file and not flag_first_time then
         fx_ll_hq.SetVar(fx_ll_hq.csvGlobalVariables, fx_ll_hq.file_path_global_variables, fx_ll_hq.gv_identifier_user_database, true, 1, user_database_name)
      elseif flag_cancel then
         return
      end
   else
      user_database_path = fx_ll_hq.file_path_user_database
      user_database_name = fx_ll_hq.file_name_user_database
   end

   --fx_ll_hq.print("CHECK: user_database_path: " .. user_database_path .. " user_database_name:" .. user_database_name .. "\n")
  --fx_ll_hq.print("fx_ll_hq.file_name_community_database == " .. fx_ll_hq.file_name_community_database .. "\n")

   local fx_identifier, par_id, ll_val, hq_val
   local user_database_tab = {}
   user_database_tab[1] = fx_ll_hq.database_fomat_table

   local cnt_rows_community_database = fx_ll_hq.ReturnCountRowsInFile(fx_ll_hq.file_path_community_database)
   --fx_ll_hq.print("cnt_rows_community_database == " .. cnt_rows_community_database .. "\n")
   for i = 1, cnt_rows_community_database do -- index raised to 2 to skip reading first row which serves as header
      fx_identifier, par_id, ll_val, hq_val = fx_ll_hq.GetValuesFromCsvTableLineFxDatabase(fx_ll_hq.csvCommunityDatabase,i)
      if fx_identifier == nil then
         fx_ll_hq.print("ERROR: On line " .. i .. " of user database file " .. fx_ll_hq.file_name_user_database .. " the fx_name is nil (probably one of the parameters is).\n")
         goto continue
     end
      --fx_ll_hq.print("Check table values: " .. fx_name .. ' ' .. developer .. ' ' .. format .. ' ' .. par_id .. ' ' .. ll_val .. ' ' .. hq_val .. '\n')
      if fx_ll_hq.DoesFXExistForMatchingFXFromList(fx_identifier,par_id,ll_val,hq_val) then
         user_database_tab[#user_database_tab + 1] = { fx_identifier, fx_name, developer, format, par_id, ll_val, hq_val }
      end
      ::continue::
   end
   fx_ll_hq.SaveTableToCsvFile(user_database_tab, user_database_path)
end

function fx_ll_hq.SetReaLlm_MONITORINGFX(state)
   if state then
      reaper.Llm_Set("MONITORINGFX","yes")
   else
      reaper.Llm_Set("MONITORINGFX","no")
   end
end

function fx_ll_hq.ReturnLineFromCsvTableAsTable(csvMeta)
   return csv.ReturnLineFromCsvTableAsTable(csvMeta)
end

function fx_ll_hq.SetReaLlm_FX_LL_HQ_FromUserDatabase()
   fx_ll_hq.print("Init ReaLlm Settings\n")

   fx_ll_hq.SetReaLlm_MONITORINGFX(fx_ll_hq.reallm_pref_action_ProcessMonitorChain)
   reaper.Llm_Set("PDCLIMIT", fx_ll_hq.reallm_pref_action_PDC_Limit)

   -- if fx_ll_hq.reallm_pref_action_SetLlmAndHqmForPlugins == true then
   --    local fx_identifier, par_id, ll_val, hq_val 
   --    local cnt_rows_user_database = fx_ll_hq.ReturnCountNonEmptyRowsInFile(fx_ll_hq.file_path_user_database)
   --    fx_ll_hq.print("cnt_rows_user_database == " .. cnt_rows_user_database .. "\n")
   --    local string
   --    for i = 1, cnt_rows_user_database do
   --       _, fx_identifier, par_id, ll_val, hq_val = fx_ll_hq.GetValuesFromCsvTableLineFxDatabase(fx_ll_hq.csvUserDatabase,i)
   --       string = fx_identifier .. "," .. par_id .. "," .. ll_val .. "," .. hq_val
   --       fx_ll_hq.print("Set LLM and HQM for plugin: " .. string .. "\n")
   --       reaper.Llm_Set("PARAMCHANGE", string)
   --    end
   -- end

   if fx_ll_hq.reallm_pref_action_SetLlmAndHqmForPlugins == true then
      local fx_identifier, par_id, ll_val, hq_val 
      local cnt_rows_user_database = fx_ll_hq.ReturnNumberOfRowsInCsvTable(fx_ll_hq.csvUserDatabase)
      fx_ll_hq.print("cnt_rows_user_database == " .. cnt_rows_user_database .. "\n")
      local string, flag_active
      for i = 1, cnt_rows_user_database do
         _, fx_identifier, par_id, ll_val, hq_val, _, _, flag_active  = fx_ll_hq.GetValuesFromCsvTableLineFxDatabase(fx_ll_hq.csvUserDatabase,i)
         if flag_active == true then
            string = fx_identifier .. fx_ll_hq.separator_reallm .. par_id .. fx_ll_hq.separator_reallm  .. ll_val .. fx_ll_hq.separator_reallm  .. hq_val
            fx_ll_hq.print("Set LLM and HQM for plugin: " .. string .. "\n")
            reaper.Llm_Set("PARAMCHANGE", string)
         end
      end
   end

   -- local format_fx_name_developer_format
   -- local fx_identifier, fx_name, developer, format, par_id, ll_val, hq_val
   -- if fx_ll_hq.file_exists_file_path(fx_ll_hq.file_path_user_database) == false then
   --     local retval = reaper.ShowMessageBox("User database file named " .. fx_ll_hq.file_name_user_database .. " does not exist.\nDo you want to create a new one from existing plugins and Community Database? (YES) OR open database folder and insert another file name (with options)? (NO)", "Create new user database file?", 3)
   --     --fx_ll_hq.print("retval == " .. retval .. '\n')
   --     if retval == 6 then -- YES
   --         fx_ll_hq.SetVar(fx_ll_hq.csvGlobalVariables, fx_ll_hq.file_path_global_variables, fx_ll_hq.gv_identifier_user_database, true, 1, fx_ll_hq.default_file_name_user_database)
   --         fx_ll_hq.SetupUserDatabaseFromReferenceDatabaseWithExistingPluginsOnly(true)
   --         fx_ll_hq.OpenContainingFolderInExplorerPrompt()
   --     elseif retval == 7 then -- NO 
   --         fx_ll_hq.OpenContainingFolderInExplorerPrompt()
   --         fx_ll_hq.SetUserDatabaseFile()
   --     elseif retval == 2 then -- CANCEL
   --         return
   --     end
   -- end
   -- if fx_ll_hq.file_exists_file_path(fx_ll_hq.file_path_user_database) then
   --     local cnt_rows_user_database = fx_ll_hq.ReturnCountRowsInFile(fx_ll_hq.file_path_user_database)
   --     local p_paramchange
   --     for i = 1, cnt_rows_user_database do
   --         fx_identifier, par_id, ll_val, hq_val = fx_ll_hq.GetValuesFromCsvTableLineFxDatabase(fx_ll_hq.csvUserDatabase,i)
   --         if fx_identifier == nil then
   --             fx_ll_hq.print("ERROR: On line " .. i .. " of user database file " .. fx_ll_hq.file_name_user_database .. " the fx_name is nil (probably one of the parameters is).\n")
   --             goto skip
   --         end
   --         --fx_ll_hq.print("Check table values: " .. fx_name .. ' ' .. developer .. ' ' .. format .. ' ' .. par_id .. ' ' .. ll_val .. ' ' .. hq_val .. '\n')
   --         --format_fx_name_developer_format = format .. ": " .. fx_name .. ' (' .. developer .. ')'
   --         --fx_ll_hq.print(format_fx_name_developer_format .. '\n')
   --         if fx_ll_hq.IsNumber(par_id) == false then
   --             fx_ll_hq.print("Error: par_id is not a number. par_id: " .. par_id .. ". Skipping this line for now. Solve later.\n")
   --             goto skip
   --         end
   --         p_paramchange = fx_identifier .. fx_ll_hq.separator_reallm .. par_id .. fx_ll_hq.separator_reallm .. ll_val .. fx_ll_hq.separator_reallm .. hq_val
   --         --fx_ll_hq.print("p_paramchange -- " .. p_paramchange .. '\n')
   --         reaper.Llm_Set("PARAMCHANGE", p_paramchange)
   --         ::skip::
   --     end
   -- else
   --     --fx_ll_hq.print("User database file still does not match it's name in Global Variables file. Please, repeat the process.\n")
   --     return
   -- end
end

function fx_ll_hq.GetLineFromFile(file_path, line_number)
   local f = io.open(file_path, "r")
  local count = 1
  if f == nil then
      return nil
  end
  for line in f:lines() do
   if count == line_number then
      f:close()
      return line
   end
      count = count + 1
  end
  
  f:close()
  return nil
end

function fx_ll_hq.ReturnNumberOfElementsInRowCsvTable(csvMeta, row_number)
   return csv.ReturnNumberOfElementsInRowCsvTable(csvMeta, row_number)
end

function fx_ll_hq.ReturnLineFromCsvTableAsString(csvMeta, row_number)
   return csv.ReturnLineFromCsvTableAsString(csvMeta, row_number)
end

function fx_ll_hq.CompareUserDatabaseTableAndCsvFile(csvMeta)
   local ret = false
   local count_lines_csv_table = fx_ll_hq.ReturnNumberOfRowsInCsvTable(csvMeta)
   local count_lines_csv_file = fx_ll_hq.ReturnCountNonEmptyRowsInFile(fx_ll_hq.file_path_user_database)
   fx_ll_hq.print("Table rows count == " .. count_lines_csv_table .. " csv file rows count == " .. count_lines_csv_file .. '\n')
   if count_lines_csv_table ~= count_lines_csv_file then
      fx_ll_hq.print("count_lines_csv_table ~= count_lines_csv_file\n")
      fx_ll_hq.print( "count_lines_csv_table == " .. count_lines_csv_table .. '\n')
      fx_ll_hq.print( "count_lines_csv_file == " .. count_lines_csv_file .. '\n')
      fx_ll_hq.print("User database table does not match csv file.\n")
       return false
   end
   local string_csv_table
   local string_csv_file
   for i = 1, count_lines_csv_table do
         string_csv_table = fx_ll_hq.ReturnLineFromCsvTableAsString(csvMeta, i)
         string_csv_file = fx_ll_hq.GetLineFromFile(fx_ll_hq.file_path_user_database, i)
         if string_csv_table == nil or string_csv_file == nil then
            fx_ll_hq.print("ERROR string_csv_table == nil\n")
            return false
         end
         -- fx_ll_hq.print("string_csv_file:find(string_csv_table, 1, true) == " .. string_csv_file:find(string_csv_table, 1, true) .. '\n')
         if string_csv_file:find(string_csv_table, 1, true) ~= 1 then
             fx_ll_hq.print("string_csv_table ~= string_csv_file\n")
             fx_ll_hq.print("string_csv_table == " .. string_csv_table .. '\n')
             fx_ll_hq.print("string_csv_file == " .. string_csv_file .. '\n')
         else
               fx_ll_hq.print("string_csv_table == string_csv_file\n")
               fx_ll_hq.print("string_csv_table == " .. string_csv_table .. '\n')
               fx_ll_hq.print("string_csv_file == " .. string_csv_file .. '\n')
            ret = true
         end
   end

   if ret == true then
       fx_ll_hq.print("User database table matches csv file.\n")
   else
      fx_ll_hq.print("User database table does not match csv file.\n")
   end
   return ret
end

function IsPathValid(path)
   local success, message = os.rename(path, path)
   if success then
     return true
   else
     return false
   end
end

function fx_ll_hq.IsDatabaseTableValid(csvMeta)
   -- TODO make sure this self even exists
   -- fx_ll_hq.print("#fx_ll_hq.database_fomat_table == " .. #fx_ll_hq.database_fomat_table .. '\n')
   local count_rows_csv_table = fx_ll_hq.ReturnNumberOfRowsInCsvTable(csvMeta)
   if count_rows_csv_table == 0 then return true end -- empty is valid
   for i = 1, count_rows_csv_table do
      if csv.ReturnNumberOfElementsInRowCsvTable(csvMeta, i) ~= #fx_ll_hq.database_fomat_table then
         fx_ll_hq.print("Database table is not valid. Number of elements in row " .. i .. " is not equal to number of elements in database format table. (" .. csv.ReturnNumberOfElementsInRowCsvTable(csvMeta, i) .. " ~= " .. #fx_ll_hq.database_fomat_table .. ")\n")
         return false
      end
   end
   return true
end

function fx_ll_hq.ExtractFileNameFromPath(file_path)
   --fx_ll_hq.print("EFN file_path == " .. file_path .. '\n')
   -- file_name is last part of file_path with extension after last escape character
   local file_name = file_path:match("^.+[/\\](.+)$")
   --fx_ll_hq.print("EFN file_name == " .. tostring(file_name) .. '\n')
   return file_name
end

---comment
---@return any return string file path or nil if cancelled dialogue
function fx_ll_hq.OpenSystemFileOpenDialogue_ReturnFilePath()
   local retval, file_path = reaper.GetUserFileNameForRead(fx_ll_hq.get_script_path(), "Select user database file", "")
   if retval == false then
      return nil
   else
      --fx_ll_hq.print("file_path == " .. file_path .. '\n')
      return file_path
   end
end


function fx_ll_hq.VerifyNewDatabaseFile(file_path_new)
   
   if fx_ll_hq.ReturnCountNonEmptyRowsInFile(file_path_new) == 0 then
      fx_ll_hq.print("New database file is empty. Valid.\n")
      return true
   end
   local csvTemp = csv.new()
   if csv.load_csvfile(csvTemp, file_path_new) then
      --fx_ll_hq.print("New database file is a valid csv file and was loaded.\n")
      --fx_ll_hq.print("fx_ll_hq.IsDatabaseTableValid(csvTemp) == " .. tostring(fx_ll_hq.IsDatabaseTableValid(csvTemp)) .. "\n")
      return fx_ll_hq.IsDatabaseTableValid(csvTemp)
   else
      --fx_ll_hq.print("New database file is not a valid csv file or could not be loaded. Please, review the file.\n")
      return false
   end
end

function fx_ll_hq.LoadNewDatabaseFile(csvMeta, file_path)
   csv.load_csvfile(csvMeta, file_path)
end

function fx_ll_hq.LoadOverwriteNewDatabaseFile(csvMeta, file_path)
   csv.load_overwrite_csvfile(csvMeta, file_path)
end
--- 
function fx_ll_hq.IsDatabaseFileValidFeedbackTextReturn(file_path, text_default, flag_include_default_text)
   --fx_ll_hq.print("IsDatabaseFileValidFeedbackTextReturn: file_path == " .. tostring(file_path) .. " text_default == " .. tostring(text_default) .. "\n")
   ----fx_ll_hq.print("reaper.file_exists(file_path) == " .. tostring(reaper.file_exists(file_path)) .. "\n")
   if fx_ll_hq.file_exists_file_path(file_path) then
     --fx_ll_hq.print("file exists in script root directory\n")
     if fx_ll_hq.VerifyNewDatabaseFile(file_path) then
       --fx_ll_hq.print("file is in valid database format valid\n")
       --return text_default .. " (valid)"
       if flag_include_default_text == true then
         return true, text_default .. " (valid file)"
       else
         return true, " (valid file)"
       end
     else
       --fx_ll_hq.print("file is not in valid database format invalid\n")
       --return text_default .. " (invalid)"
         if flag_include_default_text == true then
            return false, text_default .. " (invalid file)"
         else
            return false, " (invalid file)"
         end
     end
   else
     --fx_ll_hq.print("file does not exist in script root directory\n")
     -- return text_default .. " (invalid)"
     if flag_include_default_text == true then
      return false, text_default .. " (invalid file)"
      else
         return false, " (invalid file)"
      end
   end
 end

 function fx_ll_hq.add_row_to_csv_table(csvMeta, row_content)
   --fx_ll_hq.print("add_row_to_csv_table: row_content == " .. tostring(row_content) .. "\n")
   local ret = csv.add_row(csvMeta, row_content)
   --fx_ll_hq.print("add_row_to_csv_table: row_content_table == " .. fx_ll_hq.TableToString_1D(row_content_table, true) .. "\n")
   return ret
 end

 function fx_ll_hq.add_empty_row_to_csv_table(csvMeta)
   --fx_ll_hq.print("add_row_to_csv_table: row_content == " .. tostring(row_content) .. "\n")
   local ret = csv.add_empty_row(csvMeta)
   --fx_ll_hq.print("add_row_to_csv_table: row_content_table == " .. fx_ll_hq.TableToString_1D(row_content_table, true) .. "\n")
   return ret
 end

 function fx_ll_hq.RemoveRowFromCsvTable(csvMeta, row)
   fx_ll_hq.print("RemoveRowFromCsvTable: row == " .. tostring(row) .. "\n")
   csv.RemoveRowFromCsvTable(csvMeta, row)
   local new_rows_count = csv.ReturnNumberOfRowsInCsvTable(csvMeta)
   return new_rows_count
 end

 function fx_ll_hq.WriteCsvFile(csvMeta, file_path)
   csv.write_csvfile(csvMeta, file_path)
 end

 function fx_ll_hq.ReturnNumberOfRowsInCsvTable(csvMeta)
   return csv.ReturnNumberOfRowsInCsvTable(csvMeta)
 end

 function fx_ll_hq.PrintCsvTableDatabase(csvMeta)
   csv.display_csvfile(csvMeta)
 end

 function fx_ll_hq.UpdateOrCreateNewLineInUserDatabase(row_number, fx_identifier, paramnumber, ll_val, hq_val, def_ll_val, def_hq_val, flag_filter, flag_active)
   local flag_new_line = true
   local user_database_rows_count = fx_ll_hq.ReturnNumberOfRowsInCsvTable(fx_ll_hq.csvUserDatabase)
   
   fx_ll_hq.print("user_database_rows_count == " .. tostring(user_database_rows_count) .. "\n")

   for row_user = 1, user_database_rows_count do

      local row_user_fx_identifier = csv.get_attribute(fx_ll_hq.csvUserDatabase, row_user, fx_ll_hq.GetPositionOfElementInIterativeTable(fx_ll_hq.database_fomat_table, "FX Identifier"))
      if not row_user_fx_identifier then 
         fx_ll_hq.print("ERROR row_user_identifier == nil\n")
         return -1
      end
      local row_user_parameter_index = csv.get_attribute(fx_ll_hq.csvUserDatabase, row_user, fx_ll_hq.GetPositionOfElementInIterativeTable(fx_ll_hq.database_fomat_table, "Parameter Index"))
      fx_ll_hq.print("row_user_fx_identifier == " .. tostring(row_user_fx_identifier) .. " row_user_parameter_index == " .. tostring(row_user_parameter_index) .. "\n")
      fx_ll_hq.print("fx_identifier == " .. tostring(fx_identifier) .. " paramnumber == " .. tostring(paramnumber) .. "\n")
      fx_ll_hq.print("row_user_identifier:find(fx_identifier, 1, true) == " .. tostring(tostring(row_user_fx_identifier):find(fx_identifier, 1, true)) .. "\n")

      if fx_identifier == "" then
         flag_new_line = false
         goto continue
      end
      if (tostring(row_user_fx_identifier):find(fx_identifier, 1, true) ~= nil and fx_identifier ~= "") and paramnumber == row_user_parameter_index then
         fx_ll_hq.print("matched\n")
         flag_new_line = false
         --csv.set_attribute(fx_ll_hq.csvUserDatabase, row_user, 2, paramnumber)
         csv.set_attribute(fx_ll_hq.csvUserDatabase, row_user, fx_ll_hq.row_num_IDX, row_user)
         csv.set_attribute(fx_ll_hq.csvUserDatabase, row_user, fx_ll_hq.ll_val_IDX, ll_val)
         csv.set_attribute(fx_ll_hq.csvUserDatabase, row_user, fx_ll_hq.hq_val_IDX, hq_val)
         csv.set_attribute(fx_ll_hq.csvUserDatabase, row_user, fx_ll_hq.default_ll_val_IDX, def_ll_val)
         csv.set_attribute(fx_ll_hq.csvUserDatabase, row_user, fx_ll_hq.default_hq_val_IDX, def_hq_val)
         csv.set_attribute(fx_ll_hq.csvUserDatabase, row_user, fx_ll_hq.active_IDX, flag_active)
         csv.set_attribute(fx_ll_hq.csvUserDatabase, row_user, fx_ll_hq.filter_IDX, flag_filter)
         --goto continue
      end
      ::continue::
   end
   if flag_new_line then
      if row_number == nil then row_number = -1 end
      local new_row_tab = {row_number, fx_identifier, paramnumber, ll_val, hq_val, def_ll_val, def_hq_val, flag_active, flag_filter}
      csv.add_row(fx_ll_hq.csvUserDatabase, new_row_tab)
   end
   --::continue::
   return flag_new_line

 end

 function fx_ll_hq.ImportReferenceDatabaseToUserDatabaseTable(recv_file_path_reference_database)
   local rows_count = fx_ll_hq.ReturnNumberOfRowsInCsvTable(fx_ll_hq.csvUserDatabase)
   local count_new_rows = 0
   fx_ll_hq.print("ImportReferenceDatabaseToUserDatabaseTable: recv_file_path_reference_database == " .. tostring(recv_file_path_reference_database) .. "\n")
   local csvTempReferenceDatabase = csv.new()
   local ret = csv.load_csvfile(csvTempReferenceDatabase, recv_file_path_reference_database)
   local table_refresh
   if ret then
      local reference_database_rows_count = fx_ll_hq.ReturnNumberOfRowsInCsvTable(csvTempReferenceDatabase)
      fx_ll_hq.print("reference_database_rows_count == " .. tostring(reference_database_rows_count) .. "\n")
      fx_ll_hq.print("IMPORT rows_count == " .. tostring(rows_count) .. "\n")
      for row_reference = 1, reference_database_rows_count do
         fx_ll_hq.print("for reference loop round " .. tostring(row_reference) .. "\n")
         local row_reference_number = csv.get_attribute(csvTempReferenceDatabase, row_reference, fx_ll_hq.GetPositionOfElementInIterativeTable(fx_ll_hq.database_fomat_table, "Row"))
         local row_reference_identifier = csv.get_attribute(csvTempReferenceDatabase, row_reference, fx_ll_hq.GetPositionOfElementInIterativeTable(fx_ll_hq.database_fomat_table, "FX Identifier"))
         local reference_identifier_parameter_index = csv.get_attribute(csvTempReferenceDatabase, row_reference, fx_ll_hq.GetPositionOfElementInIterativeTable(fx_ll_hq.database_fomat_table, "Parameter Index"))
         local reference_ll_val = csv.get_attribute(csvTempReferenceDatabase, row_reference, fx_ll_hq.GetPositionOfElementInIterativeTable(fx_ll_hq.database_fomat_table, "Low Latency Value"))
         local reference_hq_val = csv.get_attribute(csvTempReferenceDatabase, row_reference, fx_ll_hq.GetPositionOfElementInIterativeTable(fx_ll_hq.database_fomat_table, "High Quality Value"))
         local reference_def_ll_val = csv.get_attribute(csvTempReferenceDatabase, row_reference, fx_ll_hq.GetPositionOfElementInIterativeTable(fx_ll_hq.database_fomat_table, "Default Low Latency Value"))
         local reference_def_hq_val = csv.get_attribute(csvTempReferenceDatabase, row_reference, fx_ll_hq.GetPositionOfElementInIterativeTable(fx_ll_hq.database_fomat_table, "Default High Quality Value"))
         local reference_flag_active = csv.get_attribute(csvTempReferenceDatabase, row_reference, fx_ll_hq.GetPositionOfElementInIterativeTable(fx_ll_hq.database_fomat_table, "Active"))
         local reference_flag_filter = csv.get_attribute(csvTempReferenceDatabase, row_reference, fx_ll_hq.GetPositionOfElementInIterativeTable(fx_ll_hq.database_fomat_table, "Filter"))
         
         if fx_ll_hq.UpdateOrCreateNewLineInUserDatabase(row_reference_number, row_reference_identifier, reference_identifier_parameter_index, reference_ll_val, reference_hq_val, reference_def_ll_val, reference_def_hq_val, reference_flag_active, reference_flag_filter) then
            count_new_rows = count_new_rows + 1
         end
      end
      fx_ll_hq.print("count_new_rows == " .. tostring(count_new_rows) .. "\n")
      fx_ll_hq.print("rows_count + count_new_rows == " .. tostring(rows_count + count_new_rows) .. "\n")
      table_refresh = true
   else
      fx_ll_hq.print("Reference Database file could not be loaded (ImportReferenceDatabaseToUserDatabaseTable) \n")
      table_refresh = false
   end
   return rows_count + count_new_rows, table_refresh
 end

function fx_ll_hq.FastCheckExistsLastTouchedParameter()
   return reaper.GetLastTouchedFX()
end

 function fx_ll_hq.CaptureLastTouchedFxParameter()
   local valid_capture = false
   --local retval, tracknumber, itemnumber, fxnumber = reaper.GetFocusedFX2()
   
   --fx_ll_hq.print("tracknumber == " .. tostring(tracknumber) .. "\n")
   local retval_param, minval, maxval
   local fx_identifier, param_name, paramnumber, txt
   local retval, tracknumber, fxnumber, paramnumber = reaper.GetLastTouchedFX()
   --if not retval then return -1 end
   --fx_ll_hq.print("paramnumber == " .. tostring(paramnumber) .. "\n")
   local title_string = 'Last Touched: '
   if retval then
      if (tracknumber >> 16) == 0 then -- Track FX or Input FX
        local track = reaper.CSurf_TrackFromID(tracknumber, false)
        local _, track_name = reaper.GetTrackName(track)
        if tracknumber == 0 then track_name = 'Master Track' else track_name = 'Track '..tostring(tracknumber)..' - '..track_name end
        local _, fx_name = reaper.TrackFX_GetFXName(track, fxnumber, "")
        _, fx_identifier = reaper.TrackFX_GetFXName(track, fxnumber, "")
        local _, param_name = reaper.TrackFX_GetParamName(track, fxnumber, paramnumber, "")
        local fx_id = "FX: " if (fxnumber >> 24) == 1 then fx_id = "Input FX: " end
        local _, f_value = reaper.TrackFX_GetFormattedParamValue(track, fxnumber, paramnumber,'')
        retval_param, minval, maxval = reaper.TrackFX_GetParam(track, fxnumber, paramnumber)
        txt = track_name..'\n'..fx_id..fx_name..'\nParam: '..param_name..' Value: '..f_value
      else -- ITEM FX >>>>>
        local track = reaper.CSurf_TrackFromID((tracknumber & 0xFFFF), false)
        local _, track_name = reaper.GetTrackName(track)
        track_name = 'Track '..tostring(tracknumber & 0xFFFF) ..' - ' ..track_name
        local takenumber = (fxnumber >> 16)
        fxnumber = (fxnumber & 0xFFFF)
        local item_index = (tracknumber >> 16)-1
        local item = reaper.GetTrackMediaItem(track, item_index)
        local take = reaper.GetTake(item, takenumber)
        local _, fx_name = reaper.TakeFX_GetFXName(take, fxnumber, "")
        _, fx_identifier = reaper.TakeFX_GetFXName(take, fxnumber, "")
        local _, take_param_name = reaper.TakeFX_GetParamName(take, fxnumber, paramnumber, "")
        local _, f_value = reaper.TakeFX_GetFormattedParamValue(take, fxnumber, paramnumber,'')
        retval_param, minval, maxval = reaper.TakeFX_GetParam(take, fxnumber, paramnumber)
        txt = track_name..'\nItem '..tostring(item_index+1).."  Take "..tostring(takenumber+1)..'\nFX: '..fx_name..'\nParam: '..take_param_name..' Value: '..f_value
      end
    end

    if fx_identifier ~= nil then
      valid_capture = true
    end

    fx_ll_hq.print("fx_identifier == " .. tostring(fx_identifier) .. "paramnumber == " .. tostring(paramnumber) .. " minval == " .. tostring(minval) .. " maxval == " .. tostring(maxval) .. "\n")

   local flag_new_track
   if valid_capture then
      fx_ll_hq.print("fx_identifier == " .. tostring(fx_identifier) .. " paramnumber == " .. tostring(paramnumber) .. " minval == " .. tostring(minval) .. " maxval == " .. tostring(maxval) .. "\n")
      local flag_active, flag_filter = true, true
      flag_new_track = fx_ll_hq.UpdateOrCreateNewLineInUserDatabase(nil, fx_identifier, paramnumber, minval, maxval, minval, maxval, flag_active, flag_filter)
   end

   return 1, flag_new_track
end

function fx_ll_hq.CheckKeyNumbers(ctx, keys)
   CTRL = r.ImGui_IsKeyDown(ctx, r.ImGui_Key_LeftCtrl())
   if not CTRL then return end
   for i = 1, #keys do
       if r.ImGui_IsKeyPressed(ctx, keys[i]) then
           SLOT = i < 10 and i or 100
       end
   end
 end

 function fx_ll_hq.SaveTableValuesToCsvFile(csvMeta)
   fx_ll_hq.WriteCsvFile(csvMeta, fx_ll_hq.file_path_user_database)
 end

 function fx_ll_hq.SafeSaveTableToCsvFileAndReload(csvMeta, file_path)
   fx_ll_hq.SaveTableValuesToCsvFile(csvMeta)
   -- fx_ll_hq.LoadOverwriteNewDatabaseFile(csvMeta, file_path)
   fx_ll_hq.UpdateRowsNumbersCsvTableDatabase(fx_ll_hq.csvUserDatabase)
   local count_changes = 0
   return count_changes
 end

 function fx_ll_hq.ResetTableFromFile(csvMeta, file_path)
   fx_ll_hq.LoadOverwriteNewDatabaseFile(csvMeta, file_path)
   local rows_count = fx_ll_hq.ReturnNumberOfRowsInCsvTable(csvMeta)
   local table_refresh = true
   local count_changes = 0
   return count_changes, rows_count, table_refresh
 end

 function fx_ll_hq.SetExtState(key, value)
   if value == nil then value = "" end
   r.SetExtState("fx_ll_hq", key, value, true)
 end

 function fx_ll_hq.GetExtState(key)
   local value = r.GetExtState("fx_ll_hq", key)
   if value == "" then value = nil end
   return value
 end

 ---comment returns the state of the modifier keys (probably optimized for Windows)
 ---@return boolean ctrl
 ---@return boolean shift
 ---@return boolean alt
 ---@return boolean win
 function fx_ll_hq.GetModKeys(ctx)
   -- fx_ll_hq.print("ImGui.GetKeyMods(ctx) == " .. tostring(r.ImGui_GetKeyMods(ctx)) .. '\n')
   local mod_keys = r.ImGui_GetKeyMods(ctx)
   local alt =  reaper.ImGui_GetKeyMods(ctx) & reaper.ImGui_Mod_Alt() > 0
   local shift = reaper.ImGui_GetKeyMods(ctx) & reaper.ImGui_Mod_Shift() > 0
   local ctrl = reaper.ImGui_GetKeyMods(ctx) & reaper.ImGui_Mod_Ctrl() > 0
   local win = reaper.ImGui_GetKeyMods(ctx) & reaper.ImGui_Mod_Super() > 0
   -- shift: 8192
   -- ctrl: 4096
   -- alt: 16384
   -- win: 32768
   -- fx_ll_hq.print("shift == " .. tostring(shift) .. '\n')
   -- fx_ll_hq.print("ctrl == " .. tostring(ctrl) .. '\n')
   -- fx_ll_hq.print("alt == " .. tostring(alt) .. '\n')
   -- fx_ll_hq.print("win == " .. tostring(win) .. '\n')
   return ctrl, shift, alt, win
 end

 function fx_ll_hq.CheckKeyPressed(ctx, keys)
   local CTRL, SHIFT, ALT, WIN = fx_ll_hq.GetModKeys(ctx)
   if not CTRL or SHIFT or ALT or WIN then return end --- MUST BE WITH CTRL MODIFIER!!!
   for char,key_id in pairs(keys) do
       if r.ImGui_IsKeyPressed(ctx, key_id) then
         fx_ll_hq.print("key_id == " .. tostring(key_id) .. "\n")
           return key_id, CTRL, SHIFT, ALT, WIN
       end
   end
   return nil
 end


function fx_ll_hq.GetSelfCsvTable(csvMeta)
   return csv.GetSelfCsvTable(csvMeta)
end

function fx_ll_hq.ClearSelfCsvTable(csvMeta)
   csv.ClearSelfCsvTable(csvMeta)
end

function fx_ll_hq.SetSelfCsvTable(csvMeta, csv_table)
   csv.SetSelfCsvTable(csvMeta, csv_table)
end

function fx_ll_hq.CaptureVariousValuesOfLastTouchedFxParameter(row, flag_capture_paramnumber)
   local row_fx_identifier_column = fx_ll_hq.GetPositionOfElementInIterativeTable(fx_ll_hq.database_fomat_table, "FX Identifier")
   local row_fx_identifier = fx_ll_hq.GetAttributeByRowAndColumnFromCsvTable(fx_ll_hq.csvUserDatabase, row, row_fx_identifier_column)
   local row_paramnumber_column = fx_ll_hq.GetPositionOfElementInIterativeTable(fx_ll_hq.database_fomat_table, "Parameter Index")
   local row_paramnumber = fx_ll_hq.GetAttributeByRowAndColumnFromCsvTable(fx_ll_hq.csvUserDatabase, row, row_paramnumber_column)

   -- fx_ll_hq.print("row_fx_identifier == " .. row_fx_identifier .. "\n")
   -- fx_ll_hq.print("row_paramnumber == " .. row_paramnumber .. "\n")


   local valid_capture = false
   --local retval, tracknumber, itemnumber, fxnumber = reaper.GetFocusedFX2()
   
   --fx_ll_hq.print("tracknumber == " .. tostring(tracknumber) .. "\n")
   local retval_param, minval, maxval
   local fx_identifier, param_name, paramnumber, txt, f_value, track, track_name, item_index, item, take, takenumber
   local retval, tracknumber, fxnumber, paramnumber = reaper.GetLastTouchedFX()
   --if not retval then return -1 end
   --fx_ll_hq.print("paramnumber == " .. tostring(paramnumber) .. "\n")
   if retval then
      if (tracknumber >> 16) == 0 then -- Track FX or Input FX
        track = reaper.CSurf_TrackFromID(tracknumber, false)
        _, track_name = reaper.GetTrackName(track)
        if tracknumber == 0 then track_name = 'Master Track' else track_name = 'Track '..tostring(tracknumber)..' - '..track_name end
        local _, fx_name = reaper.TrackFX_GetFXName(track, fxnumber, "")
        _, fx_identifier = reaper.TrackFX_GetFXName(track, fxnumber, "")
        _, param_name = reaper.TrackFX_GetParamName(track, fxnumber, paramnumber, "")
        local fx_id = "FX: " if (fxnumber >> 24) == 1 then fx_id = "Input FX: " end
        _, f_value = reaper.TrackFX_GetFormattedParamValue(track, fxnumber, paramnumber,'')
        retval_param, minval, maxval = reaper.TrackFX_GetParam(track, fxnumber, paramnumber)
        txt = track_name..'\n'..fx_id..fx_name..'\nParam: '..param_name..' Value: '..f_value
      else -- ITEM FX >>>>>
        track = reaper.CSurf_TrackFromID((tracknumber & 0xFFFF), false)
        _, track_name = reaper.GetTrackName(track)
        track_name = 'Track '..tostring(tracknumber & 0xFFFF) ..' - ' ..track_name
        takenumber = (fxnumber >> 16)
        fxnumber = (fxnumber & 0xFFFF)
        item_index = (tracknumber >> 16)-1
        item = reaper.GetTrackMediaItem(track, item_index)
        take = reaper.GetTake(item, takenumber)
        local _, fx_name = reaper.TakeFX_GetFXName(take, fxnumber, "")
        _, fx_identifier = reaper.TakeFX_GetFXName(take, fxnumber, "")
        _, param_name = reaper.TakeFX_GetParamName(take, fxnumber, paramnumber, "")
        _, f_value = reaper.TakeFX_GetFormattedParamValue(take, fxnumber, paramnumber,'')
        retval_param, minval, maxval = reaper.TakeFX_GetParam(take, fxnumber, paramnumber)
        txt = track_name..'\nItem '..tostring(item_index+1).."  Take "..tostring(takenumber+1)..'\nFX: '..fx_name..'\nParam: '..param_name..' Value: '..f_value
      end
   end

   -- fx_ll_hq.print("fx_identifier == " .. tostring(fx_identifier) .. "paramnumber == " .. tostring(paramnumber) .. " minval == " .. tostring(minval) .. " maxval == " .. tostring(maxval) .. " param_name == " .. tostring(param_name) .. "\n")


    if row_fx_identifier ~= "" and fx_identifier ~= nil and fx_identifier:find(row_fx_identifier, 1, true) == 1 then
      -- fx_ll_hq.print("fx_identifier == " .. tostring(fx_identifier) .. " row_fx_identifier == " .. tostring(row_fx_identifier) .. "\n")
      if (not flag_capture_paramnumber and paramnumber ~= nil and paramnumber == row_paramnumber) or (flag_capture_paramnumber == true and paramnumber ~= row_paramnumber) then
         valid_capture = true
         -- fx_ll_hq.print("VALID CAPTURE fx_identifier == " .. tostring(fx_identifier) .. " paramnumber == " .. tostring(paramnumber) .. " minval == " .. tostring(minval) .. " maxval == " .. tostring(maxval) .. "\n")
      else
         -- fx_ll_hq.print("INVALID CAPTURE (capturing the same paramnumber) fx_identifier == " .. tostring(fx_identifier) .. " paramnumber == " .. tostring(paramnumber) .. " minval == " .. tostring(minval) .. " maxval == " .. tostring(maxval) .. "\n")
      end
    else
      -- fx_ll_hq.print("INVALID CAPTURE fx_identifier == " .. tostring(fx_identifier) .. " paramnumber == " .. tostring(paramnumber) .. " minval == " .. tostring(minval) .. " maxval == " .. tostring(maxval) .. "\n")
    end

   return valid_capture, retval_param, param_name, paramnumber, fx_identifier, minval, maxval, f_value, track, track_name, item_index, item, take, takenumber, txt

end

function fx_ll_hq.ReturnObservedStringLastTouchedParameter()
   local retval, tracknumber, fxnumber, paramnumber = reaper.GetLastTouchedFX()
   local tooltip
   if retval then
     tooltip = "Last touched parameter is on track " .. tracknumber .. ", FX " .. fxnumber .. ", parameter " .. paramnumber
   else
     tooltip = "No last touched parameter recorded"
   end
   return tooltip
end

function fx_ll_hq.UpdateRowsNumbersCsvTableDatabase(csvMeta)
   csv.UpdateRowsNumbersCsvTableDatabase(csvMeta)
   -- csv.MakeRowsSequencePermament_ReNumberRows(csvMeta)
end

function fx_ll_hq.MakeRowsSequencePermament_ReNumberRows(csvMeta, snapshot_rows_numbers)
   if snapshot_rows_numbers then
      for i = 1, #snapshot_rows_numbers do
         if snapshot_rows_numbers[i] ~= i then
            fx_ll_hq.print("Table was not sorted, not updating rows numbers\n")
            return
         end
      end
   end
   csv.MakeRowsSequencePermament_ReNumberRows(csvMeta)
   -- local column = fx_ll_hq.row_num_IDX
   -- local prev_row_tab_number
   -- local num_shift = 0
   -- local row_tab_number
   -- for row = 1, rows_count do
   --    row_tab_number = fx_ll_hq.GetAttributeByRowAndColumnFromCsvTable(fx_ll_hq.csvUserDatabase, row, column)
   --    fx_ll_hq.SetAttributeByRowAndColumnToCsvTable(fx_ll_hq.csvUserDatabase, row, column, row_index_without_removed_rows + num_shift)
   --    prev_row_tab_number = row_tab_number
   -- end
end

function fx_ll_hq.MoveRowInCsvTable(csvMeta, row_to, row_from)
   row_to = tonumber(row_to)
   row_from = tonumber(row_from)
   fx_ll_hq.print("MoveRowInCsvTable\n")
   fx_ll_hq.print("row_from == " .. tostring(row_from) .. "\n")
   fx_ll_hq.print("row_to == " .. tostring(row_to) .. "\n")
   -- csv.exchange_rows_content(fx_ll_hq.csvUserDatabase,row_to, row_from)
   csv.move_row(csvMeta, row_from, row_to)
   local table_refresh = true
   return table_refresh
end

function fx_ll_hq.ExchangeRowsInCsvTable(csvMeta, row_to, row_from)
   row_to = tonumber(row_to)
   row_from = tonumber(row_from)
   fx_ll_hq.print("ExchangeRowsInCsvTable\n")
   fx_ll_hq.print("row_from == " .. tostring(row_from) .. "\n")
   fx_ll_hq.print("row_to == " .. tostring(row_to) .. "\n")
   csv.exchange_rows(csvMeta,row_to, row_from)
   local table_refresh = true
   return table_refresh
end

function fx_ll_hq.SortCsvTable(csvMeta, ctx)
   csv.SortCsvTable(csvMeta, ctx)
   local table_refresh = true
   return table_refresh
end

function fx_ll_hq.MakeBackup(path) -- TODO FINNISH
   local startupStr = ''
   local f = io.open(path, 'r')
   if f then
     startupStr = f:read('*all')
     f:close()
   end
   -- make a backup
   if startupStr ~= '' then
     f = io.open(fx_ll_hq.get_script_path() ..'/Backups/FX LL HQ - UserLibraryBackup.csv', 'wb')
     if f then
       f:write(startupStr)
       f:close()
     end
   end
 end

 local function sockmonkey_FilePathExists(file)
   local ok, err, code = os.rename(file, file)
   if not ok then
     if code == 13 then
     -- Permission denied, but it exists
       return true
     end
   end
   return ok, err
 end

 local function sockmonkey_FileExists(path)
   return sockmonkey_FilePathExists(path)
 end

 function fx_ll_hq.WriteOrUpdateEntryInStartupFile_ReaLlm_Init_Settings(value)
    -- the following gets the action-command-id of Cockos/lyrics.lua installed in main-section
   --  actionName = fx_ll_hq.SearchPhraseForReaLlmInitAction
   -- local cmdID = findByName()
   --local cmdID = r.NamedCommandLookup('40044')
   -- fx_ll_hq.print("cmdID == " .. cmdID .. "\n")

   local entry = { fx_ll_hq.CommabdID_InitializeReaLlmWithUserSettings, value }

   -- r.Main_OnCommand(cmdID, 0) -- TODO make it launch some script
   if sockmonkey_FileExists(fx_ll_hq.startupFilePath) then
      fx_ll_hq.WriteOrUpdateEntryToStartupFile(entry)
   else
      fx_ll_hq.print("File on path " .. fx_ll_hq.startupFilePath .. " does not exist\n")
   end
   

 end

function string.replace(text, old, new)
   local b,e = text:find(old,1,true)
   if b==nil then
      return text
   else
      return text:sub(1,b-1) .. new .. text:sub(e+1)
   end
 end


 function fx_ll_hq.WriteOrUpdateEntryToStartupFile(entry)
   fx_ll_hq.MakeBackup(fx_ll_hq.startupFilePath)
   local file_content =  fx_ll_hq.GetFileContextString(fx_ll_hq.startupFilePath)
   local f = io.open(fx_ll_hq.startupFilePath, 'wb')
   local outputString = ''
   local cmdStr = ""
   if f then
      if entry then
         fx_ll_hq.print("entry[1] == " .. tostring(entry[1]) .. " entry[2] == " .. tostring(entry[2]) .. "\n")
         cmdStr = cmdStr .. 'reaper.Main_OnCommand('
         if tonumber(entry[1]) then cmdStr = cmdStr .. entry[1]
         else cmdStr = cmdStr .. 'reaper.NamedCommandLookup("' .. entry[1] .. '")'
         end
         cmdStr = cmdStr .. ', 0) -- ' .. fx_ll_hq.CommabdID_InitializeReaLlmWithUserSettings
      end

      local comment = entry[2] == true and '' or '-- '
      
      fx_ll_hq.print("cmdStr == " .. tostring(cmdStr) .. "\n")

      local commentedCmdStr = '-- ' .. cmdStr
      fx_ll_hq.print("commentedCmdStr == " .. tostring(commentedCmdStr) .. "\n")

      if entry[2] == true then
         fx_ll_hq.print("(1) here\n")
         if file_content:find(commentedCmdStr, 1, true) == nil then
            fx_ll_hq.print("(2) here\n")
            if file_content:find(cmdStr, 1, true) == nil then
               outputString = cmdStr .. "\n" .. file_content
               fx_ll_hq.print("(3) here\n")
            else
               fx_ll_hq.print("(4) here\n")
            end
         else
            fx_ll_hq.print("(5) here\n")
            outputString = string.replace(file_content, commentedCmdStr, cmdStr)
         end
      else
         fx_ll_hq.print("(6) here\n")
         if file_content:find(commentedCmdStr, 1, true) == nil then
            fx_ll_hq.print("(7) here\n")
            if file_content:find(cmdStr, 1, true) == nil then
               fx_ll_hq.print("(8) here\n")
               outputString = commentedCmdStr.. "\n" .. file_content
            else
               fx_ll_hq.print("(9) here\n")
               outputString = string.replace(file_content, cmdStr, commentedCmdStr)
            end
         end
      end

      fx_ll_hq.print("outputString == " .. tostring(outputString) .. "\n")

      if outputString == '' then
         fx_ll_hq.print("outputString == ''\n")
         outputString = file_content
      end
      f:write(outputString)
      f:close()
   end
 end

function fx_ll_hq.MarkFilterCsvTableDatabase(csvMeta, filter_text)
   --fx_ll_hq.print("filter_text: " .. tostring(filter_text) .. " #fx_identifier_tab: " .. tostring(#fx_identifier_tab) .. "\n")
   filter_text = fx_ll_hq.Lead_Trim_ws(filter_text)
   --fx_ll_hq.print("here\n")
   local is_filter_text_empty = filter_text == nil or filter_text == ''
   --fx_ll_hq.print("is_filter_text_empty: " .. tostring(is_filter_text_empty) .. "\n")
   --if filter_text == "" then return t end
   local count_rows_user_database = fx_ll_hq.ReturnNumberOfRowsInCsvTable(csvMeta)
   if not is_filter_text_empty then
      for i = 1, count_rows_user_database do
         --if not table[i] then goto continue end
         local content = fx_ll_hq.GetAttributeByRowAndColumnFromCsvTable(csvMeta, i, fx_ll_hq.fx_identifier_IDX)
         if not content then goto continue end
         local name = tostring(content):lower()
         local found = true
         for word in filter_text:gmatch("%S+") do
            if not name:find(word:lower(), 1, true) then
                  found = false
                  break
            end
         end
         if found then
            fx_ll_hq.SetAttributeByRowAndColumnToCsvTable(csvMeta, i, fx_ll_hq.filter_IDX, true)
         else
            fx_ll_hq.SetAttributeByRowAndColumnToCsvTable(csvMeta, i, fx_ll_hq.filter_IDX, false)
         end
         ::continue::
      end
   end
end

function fx_ll_hq.UnmarkFilterCsvTableDatabase(csvMeta)
   local count_rows_user_database = fx_ll_hq.ReturnNumberOfRowsInCsvTable(csvMeta)
   for i = 1, count_rows_user_database do
      fx_ll_hq.SetAttributeByRowAndColumnToCsvTable(csvMeta, i, fx_ll_hq.filter_IDX, true)
   end
end


--=========================================
local tm2;
---comment
---@param tmr any time in seconds
---@return boolean
function fx_ll_hq.timer(tmr);--sec
    if not tonumber(tmr)then return false end;
    local ret;
    local tm = os.clock();
    if not tm2 then tm2 = tm end;
    if tm >= tm2+math.abs(tmr)then tm2 = nil ret = true end;
    return ret == true;
end;
--=========================================
   

return fx_ll_hq