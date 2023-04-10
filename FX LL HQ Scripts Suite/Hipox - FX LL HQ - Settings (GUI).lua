-- @description Hipox - FX LL HQ - Settings (GUI).lua
-- @author Hipox
-- @version 1.0
-- @about

--[[ TODO 
[ ] remember and restore open/close of CollapsingHeaders (let user pick in settings if they want to)
[ ] implement setters and getters for all API ReaLlm for current settings change
  [ ] also add a way to recognize (resp. store the state of PARAMCHANGE activated or not) PARAMSTATE and if user need to, give him advice/possibility to restart Reaper (save and restart)
  [ ] implement readable printout of getters like Safe plugins (so user know which track and plugin has this parameter set) and stuff like that
[ ] Script: sockmonkey72_StartupManager.lua - implement from this adding/removing from startup actions possibility for 
[ ] Replace Reference File in Settings with only dialogue to import data from Reference file
[ ] Add action in Settings file to create new User Database based on some file (from menu) 
[ ] Add option to save database as new file (and optionally set as new database?)
[X] change verification of user database or file database to just count and compare number of elements in a first row, not exact count of chars
[X] option to autosave on script end without asking user
[ ] search for a specific line in current user database and display just that (same as fx chooser, but in table view. If filter empty, then show all rows)
[ ] add option to restart reaper (extract from Reaper Update Utility) and start again after changing something in ReaLlm to see changes
[ ] amalgamation modules into single lua script afterwards
[ ] implement color signal when Capture already existing element in table or when searching for some element inside the table
[ ] block action add row and import etc. while not valid database
[ ] add options for dckability of script etc.
[ ] implement drag and drop feature for rows (from sockmonkeys Script: sockmonkey72_StartupManager.lua) or from some other, this is a little bit clumsy
[ ] implement backup from Script: sockmonkey72_StartupManager.lua when overwriting database file and upgrade it to make iterative backups maybe
[ ] implement 'safe mode' for param changes
[ ] include new parameters for ReaLlm: https://forum.cockos.com/showpost.php?p=2666545&postcount=277
[ ] repair analysis, problems like: JS: RCJacH Scripts/JSFX/Audio/NoiseBuzz.jsfx" "JS: NoiseBuzz
[ ] repair search / filter in table view! When removing lines it does not work properly
[ ] add buttons to trigger global ll and hq mode and also create a toggle script for these two
[ ] when capturing different paramnumber, update also min and max values
[X] Hide section after User Database Manager header when user database lib path is invalid.
[ ] Add button 'Create new user database'
[ ] Make another column and function to mark and delete all marked table rows that are not valid plugins in user's installation.
[ ] Create another mark column that replaces 'removed rows' table and don't forget to rpelace the functionality
  [ ] then load rows into the table by reading their values  
[ ] Create another mark column that disables the entry from being applied (make it inactive).
[ ] Create another column containing parameter's name and it's 'regular' value (the other value) or make it as a popup when hover over.
[ ] Make hover notes over 'Capture' buttons more describing ( less numbers, more words like Track 'Abc' instead of Track 2) and param names.
[ ] Add option in menu to direct them to donation page (PayPal probably)
[ ] Add option in menu to direct them to reaper forum thread about this script.
[ ] reset parameter, ll val and hq val and default values when name of plugin changes (by user probably)
[ ] repair search - not following changes in order in table properly
[ ] When search active, block action 'Make tracks order permanent'
[ ] Add option to have 'Make Tracks Order Permanent' automatic when search is not active AND tracks are sorted only by column (ascending) (probably just verify row_number's are in ascending order and apply then if...).
This has to be applied only in two scenarios - when some track is removed or some track is moved (and obviously on import from another database)
If either of these scenarios happen, a snapshot BEFORE has to be taken and verify that tracks before this action were definitely in ascending order. Also, search has to be OFF. Only then let this happen (make rows order permanent).
[ ] Add scaling of whole GUI option
https://github.com/ocornut/imgui/issues/6176
[ ] Copy & include ReaLlm's destrings for GET and SET, description can't get better (print them like a hint or in the console)
[ ] Explore ReaLlm's DO action if can be used
[ ] move all Database Files to another folder inside this directory
]]--

local reaper, r = reaper, reaper
local path = ({reaper.get_action_context()})[2]:match('^.+[\\//]')
package.path = path .. "?.lua"
local fx_ll_hq = require("Hipox - FX LL HQ - Functions")
local fx_ll_hq_gui = require("Hipox - FX LL HQ - GUI Functions")
local SimpleSet = require("Simple-SET")
local count_changes = 0


dofile(reaper.GetResourcePath() ..
       '/Scripts/ReaTeam Extensions/API/imgui.lua')('0.8')

local ctx = reaper.ImGui_CreateContext('My script', reaper.ImGui_ConfigFlags_DockingEnable())

local sans_serif = reaper.ImGui_CreateFont('sans-serif', 13)
reaper.ImGui_Attach(ctx, sans_serif)

function SL(ctx, xpos, pad)
  r.ImGui_SameLine(ctx,xpos, pad) 
end


local ImGui = {}
for name, func in pairs(reaper) do
  name = name:match('^ImGui_(.+)$')
  if name then ImGui[name] = func end
end

local TEXT_BASE_WIDTH  = ImGui.CalcTextSize(ctx, 'A')
local TEXT_BASE_HEIGHT = ImGui.GetTextLineHeightWithSpacing(ctx)
local FLT_MIN, FLT_MAX = ImGui.NumericLimits_Float()
local INT_MIN, INT_MAX = ImGui.NumericLimits_Int()



local flag_try_again = false
local default_value_trigger_tab = {}
local COUNTER = 0
local table_refresh = false
local rows_count = fx_ll_hq.ReturnNumberOfRowsInCsvTable(fx_ll_hq.csvUserDatabase)
local cols_count = #fx_ll_hq.fx_database_table_header_row
local file_path_user_selected_reference_database = ""
local flag_capture_parameter_live = false
local flag_timed_reallm_update = false
local flag_refresh_table = false

local database_search_set_focus = false
local dabase_search_text_buffer = ''

local strbuf, llm_pdc_latency, llm_pdc_limit, llm_safe_plugins, reallmID, llm_state, llm_graph, llm_p_state
local current_state_monitoring_fx = false

local filtered_database = {}
local flag_filtered_database = false
local prev_dabase_search_text_buffer = ""

--- variables ---

local user_database_label_default = 'User Database File Path'
local ret_user_database_file_path = fx_ll_hq.file_path_user_database
local ret_user_database_file_name = fx_ll_hq.file_name_user_database
local is_user_database_file_valid_static
local flag_dialogue_stop = false
local flag_cancel_dialogue_stop = false
local is_user_database_file_valid, ret_user_database_label = fx_ll_hq.IsDatabaseFileValidFeedbackTextReturn(fx_ll_hq.file_path_user_database, user_database_label_default, false)
if is_user_database_file_valid ~= nil then
  is_user_database_file_valid_static = is_user_database_file_valid
  --fx_ll_hq.print("is_user_database_file_valid_static == " .. tostring(is_user_database_file_valid_static) .. "\n")
end

local database_configurator_label_default = 'User Database Configurator'
local database_configurator_label = database_configurator_label_default
--- end of variables ---

--------------------------------- GUI TOOLS ---------------------------------

local keys = {
  ["1"] = r.ImGui_Key_1(),
  ["2"] = r.ImGui_Key_2(),
  ["3"] = r.ImGui_Key_3(),
  ["4"] = r.ImGui_Key_4(),
  ["5"] = r.ImGui_Key_5(),
  ["6"] = r.ImGui_Key_6(),
  ["7"] = r.ImGui_Key_7(),
  ["8"] = r.ImGui_Key_8(),
  ["9"] = r.ImGui_Key_9(),
  ["`"] = r.ImGui_Key_GraveAccent(),
  ["0"] = r.ImGui_Key_0(),
  ["S"] = r.ImGui_Key_S()
}

local function ExecuteKeyActionCtrl(key_pressed)
  if key_pressed == keys["S"] then
    fx_ll_hq.print("CTRL + S pressed\n")
    count_changes = fx_ll_hq.SafeSaveTableToCsvFileAndReload(fx_ll_hq.csvUserDatabase, fx_ll_hq.file_path_user_database)
  end
end

local function ExecuteKeyActionShift(key_pressed)
  if key_pressed == keys["S"] then
    fx_ll_hq.print("CTRL + SHIFT + S pressed\n")
    count_changes = fx_ll_hq.SafeSaveTableToCsvFileAndReload(fx_ll_hq.csvUserDatabase, fx_ll_hq.file_path_user_database)
  end
end

local function ExecuteKeyActionAlt(key_pressed)
  if key_pressed == keys["S"] then
    fx_ll_hq.print("ALT + S pressed\n")
    count_changes = fx_ll_hq.SafeSaveTableToCsvFileAndReload(fx_ll_hq.csvUserDatabase, fx_ll_hq.file_path_user_database)
  end
end

local function ExecuteKeyActionCtrlShift(key_pressed)
  if key_pressed == keys["S"] then
    fx_ll_hq.print("CTRL + SHIFT + S pressed\n")
    count_changes = fx_ll_hq.SafeSaveTableToCsvFileAndReload(fx_ll_hq.csvUserDatabase, fx_ll_hq.file_path_user_database)
  end
end



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

-- local config  = {}
-- local widgets = {}
-- local layout  = {}
local popups  = {}
local tables  = {}
-- local misc    = {}
-- local app     = {}
local cache   = {}

function demo.loop()
  demo.PushStyle()
  demo.open = demo.ShowDemoWindow(true)
  demo.PopStyle()

  if demo.open then
    reaper.defer(demo.loop)
  end
end

-- --local count_extra_table_colmuns = 1
-- local input_filters = {}
-- for i = 1, #fx_ll_hq.database_format_table_filterSearch_idxs do
--   input_filters[i] = ""
-- end


-- ??????????????????????? TODO IS THIS NECESSARY ?????????????????????
local fx_identifier_tab = fx_ll_hq.Fill_fx_list()

local fx_identifier_unique_tab = {}
for i, identifier in ipairs(fx_identifier_tab) do
  --fx_ll_hq.print("fx_identifier_tab[i] == " .. tostring(fx_identifier_tab[i]) .. "\n")
  --fx_ll_hq.print("identifier == " .. tostring(identifier) .. "\n")
  fx_identifier_unique_tab[identifier] = true
end
fx_identifier_tab = fx_ll_hq.ConvertUniqueTableToIterativeTable(fx_identifier_unique_tab)
fx_ll_hq.print("#fx_identifier_tab == " .. tostring(#fx_identifier_tab) .. "\n")
-- ????????????????????????????????


--check values above with print
fx_ll_hq.print("fx_ll_hq.global_mode_switch_ProcessTrackFXs == " .. tostring(fx_ll_hq.global_mode_switch_ProcessTrackFXs) .. " fx_ll_hq.global_mode_switch_ProcessTakeFXs == " .. tostring(fx_ll_hq.global_mode_switch_ProcessTakeFXs) .. "\n")


-- local paths_section_header_open, global_mode_switch_settings_header_open, reallm_current_settings_header_open, reallm_startup_settings_header_open, user_database_configurator_header_open
-- GUI RESTORE STATE --
if not tables.collapsible_headers then
  local paths_section_header_open_ret = fx_ll_hq.GetVar(fx_ll_hq.csvGlobalVariables, "paths_section_header_open", true, 1) == 1
  local global_mode_switch_settings_header_open_ret = fx_ll_hq.GetVar(fx_ll_hq.csvGlobalVariables, "global_mode_switch_settings_header_open", true, 1) == 1
  local reallm_current_settings_header_open_ret =  fx_ll_hq.GetVar(fx_ll_hq.csvGlobalVariables, "reallm_current_settings_header_open", true, 1) == 1
  local reallm_startup_settings_header_open_ret = fx_ll_hq.GetVar(fx_ll_hq.csvGlobalVariables, "reallm_startup_settings_header_open", true, 1) == 1
  local user_database_configurator_header_open_ret = fx_ll_hq.GetVar(fx_ll_hq.csvGlobalVariables, "user_database_configurator_header_open", true, 1) == 1

  fx_ll_hq.print("here\n")
  tables.collapsible_headers = {
    paths_section_header_open = paths_section_header_open_ret and ImGui.TreeNodeFlags_DefaultOpen() or nil,
    global_mode_switch_settings_header_open = global_mode_switch_settings_header_open_ret and ImGui.TreeNodeFlags_DefaultOpen() or nil,
    reallm_current_settings_header_open = reallm_current_settings_header_open_ret and ImGui.TreeNodeFlags_DefaultOpen() or nil,
    reallm_startup_settings_header_open = reallm_startup_settings_header_open_ret and ImGui.TreeNodeFlags_DefaultOpen() or nil,
    user_database_configurator_header_open = user_database_configurator_header_open_ret and ImGui.TreeNodeFlags_DefaultOpen() or nil,
  }
  
end

function demo.EachEnum(enum)
  local enum_cache = cache[enum]
  if not enum_cache then
    enum_cache = {}
    cache[enum] = enum_cache

    for func_name, func in pairs(reaper) do
      local enum_name = func_name:match(('^ImGui_%s_(.+)$'):format(enum))
      if enum_name then
        table.insert(enum_cache, { func(), enum_name })
      end
    end
    table.sort(enum_cache, function(a, b) return a[1] < b[1] end)
  end

  local i = 0
  return function()
    i = i + 1
    if not enum_cache[i] then return end
    return table.unpack(enum_cache[i])
  end
end

-- Note that shortcuts are currently provided for display only
-- (future version will add explicit flags to BeginMenu() to request processing shortcuts)
function demo.ShowExampleMenuFile()
  local rv, value

  ImGui.MenuItem(ctx, '(demo menu)', nil, false, false)
  if ImGui.MenuItem(ctx, 'New') then end
  if ImGui.MenuItem(ctx, 'Open', 'Ctrl+O') then end
  if ImGui.BeginMenu(ctx, 'Open Recent') then
    ImGui.MenuItem(ctx, 'fish_hat.c')
    ImGui.MenuItem(ctx, 'fish_hat.inl')
    ImGui.MenuItem(ctx, 'fish_hat.h')
    if ImGui.BeginMenu(ctx,'More..') then
      ImGui.MenuItem(ctx, 'Hello')
      ImGui.MenuItem(ctx, 'Sailor')
      if ImGui.BeginMenu(ctx, 'Recurse..') then
        demo.ShowExampleMenuFile()
        ImGui.EndMenu(ctx)
      end
      ImGui.EndMenu(ctx)
      end
    ImGui.EndMenu(ctx)
  end
  if ImGui.MenuItem(ctx, 'Save All', 'Ctrl/Cmd+S') then 
    count_changes = fx_ll_hq.SafeSaveTableToCsvFileAndReload(fx_ll_hq.csvUserDatabase, fx_ll_hq.file_path_user_database)
    rows_count = fx_ll_hq.ReturnNumberOfRowsInCsvTable(fx_ll_hq.csvUserDatabase)
    --TODO preferences save trigger
  end

  if ImGui.MenuItem(ctx, 'Save User Database', 'Alt+S') then 
    count_changes = fx_ll_hq.SafeSaveTableToCsvFileAndReload(fx_ll_hq.csvUserDatabase, fx_ll_hq.file_path_user_database)
    --TODO preferences save trigger
  end

  if ImGui.MenuItem(ctx, 'Save User Database As...', 'Ctrl/Cmd+Shift+S') then 
    count_changes = fx_ll_hq.SafeSaveTableToCsvFileAndReload(fx_ll_hq.csvUserDatabase, fx_ll_hq.file_path_user_database)
  end

  if ImGui.MenuItem(ctx, 'Save User Database & Exit', 'Ctrl/Cmd+Q') then 
    count_changes = fx_ll_hq.SafeSaveTableToCsvFileAndReload(fx_ll_hq.csvUserDatabase, fx_ll_hq.file_path_user_database)
    return true
  end


  if ImGui.MenuItem(ctx, 'Save As..') then end

  ImGui.Separator(ctx)
  if ImGui.BeginMenu(ctx, 'Options') then


    rv, value = ImGui.MenuItem(ctx, "Don't show popup when altering User Database Path (autosave)", '', fx_ll_hq.value_checkbox_edit_popup_1)
    if rv then
      fx_ll_hq.print("value_checkbox_edit_popup_1 = " .. tostring(value) .. "\n")
      fx_ll_hq.value_checkbox_edit_popup_1 = value
    end

    rv, value = ImGui.MenuItem(ctx, "Don't show popup when closing script (autosave)", '', fx_ll_hq.value_checkbox_close_script_1)
    if rv then
      fx_ll_hq.print("value_checkbox_close_script_1 = " .. tostring(value) .. "\n")
      fx_ll_hq.value_checkbox_close_script_1 = value
    end


    rv,demo.menu.enabled = ImGui.MenuItem(ctx, 'Enabled', '', demo.menu.enabled)
    if ImGui.BeginChild(ctx, 'child', 0, 60, true) then
      for i = 0, 9 do
        ImGui.Text(ctx, ('Scrolling Text %d'):format(i))
      end
      ImGui.EndChild(ctx)
    end
    rv,demo.menu.f = ImGui.SliderDouble(ctx, 'Value', demo.menu.f, 0.0, 1.0)
    rv,demo.menu.f = ImGui.InputDouble(ctx, 'Input', demo.menu.f, 0.1)
    rv,demo.menu.n = ImGui.Combo(ctx, 'Combo', demo.menu.n, 'Yes\0No\0Maybe\0')
    ImGui.EndMenu(ctx)
  end

  if ImGui.BeginMenu(ctx, 'Colors') then
    local sz = ImGui.GetTextLineHeight(ctx)
    local draw_list = ImGui.GetWindowDrawList(ctx)
    for i, name in demo.EachEnum('Col') do
      local x, y = ImGui.GetCursorScreenPos(ctx)
      ImGui.DrawList_AddRectFilled(draw_list, x, y, x + sz, y + sz, ImGui.GetColor(ctx, i))
      ImGui.Dummy(ctx, sz, sz)
      ImGui.SameLine(ctx)
      ImGui.MenuItem(ctx, name)
    end
    ImGui.EndMenu(ctx)
  end

  -- Here we demonstrate appending again to the "Options" menu (which we already created above)
  -- Of course in this demo it is a little bit silly that this function calls BeginMenu("Options") twice.
  -- In a real code-base using it would make senses to use this feature from very different code locations.
  if ImGui.BeginMenu(ctx, 'Options') then -- <-- Append!
    rv,demo.menu.b = ImGui.Checkbox(ctx, 'SomeOption', demo.menu.b)
    ImGui.EndMenu(ctx)
  end

  if ImGui.BeginMenu(ctx, 'Disabled', false) then -- Disabled
    error('never called')
  end
  if ImGui.MenuItem(ctx, 'Checked', nil, true) then end
  ImGui.Separator(ctx)
  if ImGui.MenuItem(ctx, 'Quit', 'Alt+F4') then end
end

local show_app = {
  -- Examples Apps (accessible from the "Examples" menu)
  -- main_menu_bar      = false,
  -- dockspace          = false,
  documents          = false,
  console            = false,
  log                = false,
  layout             = false,
  property_editor    = false,
  long_text          = false,
  auto_resize        = false,
  constrained_resize = false,
  simple_overlay     = false,
  fullscreen         = false,
  window_titles      = false,
  custom_rendering   = false,

  -- Dear ImGui Tools/Apps (accessible from the "Tools" menu)
  metrics      = false,
  debug_log    = false,
  stack_tool   = false,
  style_editor = false,
  about        = false,
}

  -- if show_app.main_menu_bar      then                               demo.ShowExampleAppMainMenuBar()       end
  -- if show_app.dockspace          then show_app.dockspace          = demo.ShowExampleAppDockSpace()         end -- Process the Docking app first, as explicit DockSpace() nodes needs to be submitted early (read comments near the DockSpace function)
  if show_app.documents          then show_app.documents          = demo.ShowExampleAppDocuments()         end -- Process the Document app next, as it may also use a DockSpace()
  if show_app.console            then show_app.console            = demo.ShowExampleAppConsole()           end
  if show_app.log                then show_app.log                = demo.ShowExampleAppLog()               end
  if show_app.layout             then show_app.layout             = demo.ShowExampleAppLayout()            end
  if show_app.property_editor    then show_app.property_editor    = demo.ShowExampleAppPropertyEditor()    end
  if show_app.long_text          then show_app.long_text          = demo.ShowExampleAppLongText()          end
  if show_app.auto_resize        then show_app.auto_resize        = demo.ShowExampleAppAutoResize()        end
  if show_app.constrained_resize then show_app.constrained_resize = demo.ShowExampleAppConstrainedResize() end
  if show_app.simple_overlay     then show_app.simple_overlay     = demo.ShowExampleAppSimpleOverlay()     end
  if show_app.fullscreen         then show_app.fullscreen         = demo.ShowExampleAppFullscreen()        end
  if show_app.window_titles      then                               demo.ShowExampleAppWindowTitles()      end
  if show_app.custom_rendering   then show_app.custom_rendering   = demo.ShowExampleAppCustomRendering()   end

  if show_app.metrics    then show_app.metrics    = ImGui.ShowMetricsWindow(ctx,   show_app.metrics)    end
  if show_app.debug_log  then show_app.debug_log  = ImGui.ShowDebugLogWindow(ctx,  show_app.debug_log)  end
  if show_app.stack_tool then show_app.stack_tool = ImGui.ShowStackToolWindow(ctx, show_app.stack_tool) end
  if show_app.about      then show_app.about      = ImGui.ShowAboutWindow(ctx,     show_app.about)      end
  if show_app.style_editor then
    rv, show_app.style_editor = ImGui.Begin(ctx, 'Dear ImGui Style Editor', true)
    if rv then
      demo.ShowStyleEditor()
      ImGui.End(ctx)
    end
  end


  -- Demonstrate the various window flags. Typically you would just use the default!
  local window_flags = ImGui.WindowFlags_None()
  if demo.no_titlebar       then window_flags = window_flags | ImGui.WindowFlags_NoTitleBar()            end
  if demo.no_scrollbar      then window_flags = window_flags | ImGui.WindowFlags_NoScrollbar()           end
  if not demo.no_menu       then window_flags = window_flags | ImGui.WindowFlags_MenuBar()               end
  if demo.no_move           then window_flags = window_flags | ImGui.WindowFlags_NoMove()                end
  if demo.no_resize         then window_flags = window_flags | ImGui.WindowFlags_NoResize()              end
  if demo.no_collapse       then window_flags = window_flags | ImGui.WindowFlags_NoCollapse()            end
  if demo.no_nav            then window_flags = window_flags | ImGui.WindowFlags_NoNav()                 end
  if demo.no_background     then window_flags = window_flags | ImGui.WindowFlags_NoBackground()          end
  -- if demo.no_bring_to_front then window_flags = window_flags | ImGui.WindowFlags_NoBringToFrontOnFocus() end
  if demo.no_docking        then window_flags = window_flags | ImGui.WindowFlags_NoDocking()             end
  if demo.topmost           then window_flags = window_flags | ImGui.WindowFlags_TopMost()               end
  if demo.unsaved_document  then window_flags = window_flags | ImGui.WindowFlags_UnsavedDocument()       end
  if demo.no_close          then open = false end -- disable the close button


-- Helper to display a little (?) mark which shows a tooltip when hovered.
-- In your own code you may want to display an actual icon if you are using a merged icon fonts (see docs/FONTS.md)
function HelpMarker(desc)
  ImGui.TextDisabled(ctx, '(?)')
  if ImGui.IsItemHovered(ctx, ImGui.HoveredFlags_DelayShort()) then
    ImGui.BeginTooltip(ctx)
    ImGui.PushTextWrapPos(ctx, ImGui.GetFontSize(ctx) * 35.0)
    ImGui.Text(ctx, desc)
    ImGui.PopTextWrapPos(ctx)
    ImGui.EndTooltip(ctx)
  end
end

if fx_ll_hq.GetExtState("current_state_monitoring_fx") == nil then
  current_state_monitoring_fx = false
else
  current_state_monitoring_fx = fx_ll_hq.GetExtState("current_state_monitoring_fx") == "true" and true or false
end
local function UpdateObservedValuesReaLlm()
  llm_pdc_latency = reaper.Llm_Get("PDCLATENCY", strbuf)
  llm_pdc_limit = reaper.Llm_Get("PDCLIMIT", strbuf)
  --lm_pdc_mode_check = reaper.Llm_Get("P_PDCMODECHECK", strbuf) -- not now, not working, experimental
  llm_safe_plugins = reaper.Llm_Get("SAFE", strbuf)
  reallmID = reaper.NamedCommandLookup("_AK5K_REALLM")
  if reallmID == 0 then return end
  llm_state = reaper.GetToggleCommandState(reallmID)
  llm_graph = reaper.Llm_Get("GRAPH", strbuf)
  llm_p_state = reaper.Llm_Get("STATE", strbuf)
end

---comment default is increase
---@param is_decrease any
local function modify_changes_counter(is_decrease)
  if is_decrease then
    count_changes = count_changes - 1
  else
    count_changes = count_changes + 1
  end
end

local function SaveGUIStateForElement()

  for identifier, state in pairs(tables.collapsible_headers) do -- collapsibe headers
    if state and state ~= 0 then state = 1 else state = 0 end

    fx_ll_hq.print('identifier == ' .. identifier .. ' ' .. " state == "  ..  tostring(state) .. '\n')
    fx_ll_hq.SetVar(fx_ll_hq.csvGlobalVariables, fx_ll_hq.file_path_global_variables, identifier, true, 1, state)
  end
end

-- local function SetExtStatesOnExit()
--   fx_ll_hq.SetExtState("current_state_monitoring_fx", "false")
-- end

local function exit()
  -- SetExtStatesOnExit()
  SaveGUIStateForElement()
  fx_ll_hq.SaveGlobalSharedVariables()
  fx_ll_hq.ExecuteAtExit()
  if ret_user_database_file_path ~= nil and fx_ll_hq.file_exists_file_path(ret_user_database_file_path) and fx_ll_hq.IsDatabaseFileValidFeedbackTextReturn(ret_user_database_file_path, "", false) then
    fx_ll_hq.SetVar(fx_ll_hq.csvGlobalVariables, fx_ll_hq.file_path_global_variables, "file_name_user_database", true, 1, fx_ll_hq.ExtractFileNameFromPath(ret_user_database_file_path))
  else
    local ret =  reaper.ShowMessageBox("User Database File Path is invalid and will be reverted to previous setting. To change the path, launch this script again and select a valid database file.\n"..
    "Without valid file database file all scripts in this suite won't work properly.\n"..
    "If you don't have a database file, you can create one by clicking on the 'Create New Database' button.\n", "Hipox - FX LL HQ - Settings - User Database Error", 0)
  end
    --count_changes = 0 -- !!!!!!!!!!!!!!!!!!
  if not fx_ll_hq.value_checkbox_close_script_1 and not fx_ll_hq.CompareUserDatabaseTableAndCsvFile(fx_ll_hq.csvUserDatabase) --[[count_changes and count_changes > 0]] then
    local ret = reaper.ShowMessageBox('You have made some changes to the user database file content.\nDo you want to save & exit (yes) or just exit (no)? ', 'Hipox - FX LL HQ - Settings - Unsaved Changes', 4)
    fx_ll_hq.print('ret == ' .. ret .. '\n')
    if ret == 6 then -- yes
      count_changes = fx_ll_hq.SafeSaveTableToCsvFileAndReload(fx_ll_hq.csvUserDatabase, fx_ll_hq.file_path_user_database)
      --fx_ll_hq.SaveTableToCsvFile(fx_ll_hq.csvUserDatabase, ret_user_database_file_path)
    else -- no
      fx_ll_hq.print("exit without save\n")
    end
  else
    count_changes = fx_ll_hq.SafeSaveTableToCsvFileAndReload(fx_ll_hq.csvUserDatabase, fx_ll_hq.file_path_user_database)
  end
end

UpdateObservedValuesReaLlm()
------------------------------ GUI --------------------------------
local function myWindow()
  local rv, value
  local key_pressed, ctrl_mod, shift_mod, alt_mod, win_mod = fx_ll_hq.CheckKeyPressed(ctx, keys)
  flag_filtered_database = false
  if key_pressed ~= nil then
    if ctrl_mod and shift_mod then
      ExecuteKeyActionCtrlShift(key_pressed)
    elseif ctrl_mod then
      ExecuteKeyActionCtrl(key_pressed)
    elseif shift_mod then
      ExecuteKeyActionShift(key_pressed)
    else
      ExecuteKeyActionAlt(key_pressed)
    end
  end

  if flag_timed_reallm_update then
    if fx_ll_hq.timer(0.3) then
      UpdateObservedValuesReaLlm()
      flag_timed_reallm_update = false
    end
  end

  -- Menu Bar
  if ImGui.BeginMenuBar(ctx) then
    if ImGui.BeginMenu(ctx, 'Menu') then
      demo.ShowExampleMenuFile()
      ImGui.EndMenu(ctx)
    end
    if ImGui.BeginMenu(ctx, 'Examples') then
      -- rv,show_app.main_menu_bar =
      --   ImGui.MenuItem(ctx, 'Main menu bar', nil, show_app.main_menu_bar)
      rv,show_app.console =
        ImGui.MenuItem(ctx, 'Console', nil, show_app.console, false)
      rv,show_app.log =
        ImGui.MenuItem(ctx, 'Log', nil, show_app.log)
      rv,show_app.layout =
        ImGui.MenuItem(ctx, 'Simple layout', nil, show_app.layout)
      rv,show_app.property_editor =
        ImGui.MenuItem(ctx, 'Property editor', nil, show_app.property_editor)
      rv,show_app.long_text =
        ImGui.MenuItem(ctx, 'Long text display', nil, show_app.long_text)
      rv,show_app.auto_resize =
        ImGui.MenuItem(ctx, 'Auto-resizing window', nil, show_app.auto_resize)
      rv,show_app.constrained_resize =
        ImGui.MenuItem(ctx, 'Constrained-resizing window', nil, show_app.constrained_resize)
      rv,show_app.simple_overlay =
        ImGui.MenuItem(ctx, 'Simple overlay', nil, show_app.simple_overlay)
      rv,show_app.fullscreen =
        ImGui.MenuItem(ctx, 'Fullscreen window', nil, show_app.fullscreen)
      rv,show_app.window_titles =
        ImGui.MenuItem(ctx, 'Manipulating window titles', nil, show_app.window_titles)
      rv,show_app.custom_rendering =
        ImGui.MenuItem(ctx, 'Custom rendering', nil, show_app.custom_rendering)
      -- rv,show_app.dockspace =
      --   ImGui.MenuItem(ctx, 'Dockspace', nil, show_app.dockspace, false)
      rv,show_app.documents =
        ImGui.MenuItem(ctx, 'Documents', nil, show_app.documents, false)
      ImGui.EndMenu(ctx)
    end
    -- if ImGui.MenuItem(ctx, 'MenuItem') then end -- You can also use MenuItem() inside a menu bar!
    if ImGui.BeginMenu(ctx, 'Tools') then
      rv,show_app.metrics      = ImGui.MenuItem(ctx, 'Metrics/Debugger', nil, show_app.metrics)
      rv,show_app.debug_log    = ImGui.MenuItem(ctx, 'Debug Log',        nil, show_app.debug_log)
      rv,show_app.stack_tool   = ImGui.MenuItem(ctx, 'Stack Tool',       nil, show_app.stack_tool)
      rv,show_app.style_editor = ImGui.MenuItem(ctx, 'Style Editor',     nil, show_app.style_editor)
      rv,show_app.about        = ImGui.MenuItem(ctx, 'About Dear ImGui', nil, show_app.about)
      ImGui.EndMenu(ctx)
    end
    -- if ImGui.SmallButton(ctx, 'doc example') then
    --   local doc = ('%s/Data/reaper_imgui_doc.html'):format(reaper.GetResourcePath())
    --   if reaper.CF_ShellExecute then
    --     reaper.CF_ShellExecute(doc)
    --   else
    --     reaper.MB(doc, 'ReaImGui Documentation', 0)
    --   end
    -- end
    if ImGui.SmallButton(ctx, 'Online Documentation') then
      --local doc = ('%s/Data/reaper_imgui_doc.html'):format(reaper.GetResourcePath())
      local URL = 'https://docs.google.com/document/d/1NRt6v2dBRD5kZAwnFXdKfG7v-LBXB2XZA-wAuGIVUHc/edit?usp=sharing'
      if reaper.CF_ShellExecute then
        reaper.CF_ShellExecute(URL)
      else
        reaper.MB(URL, 'FX LL HQ Online Documentation action could not proceed. Please, refer to offline file. TODO: link directly to a file.', 0)
        local doc = ('%s/FX LL HQ - Documentation.pdf'):format(fx_ll_hq.get_script_path())
        if reaper.CF_ShellExecute then
          reaper.CF_ShellExecute(doc)
        else
          reaper.MB(doc, 'Offline doc file not found.', 0)
        end
      end
    end
    ImGui.EndMenuBar(ctx)
  end

    -- ImGui.SeparatorText(ctx, 'ReaLlm Current Settings (directly applies to current session)')
    if ImGui.CollapsingHeader(ctx, 'ReaLlm Current Settings (directly applies to current session)', nil, tables.collapsible_headers.reallm_current_settings_header_open) then
      if tables.collapsible_headers.reallm_current_settings_header_open == 0 then
        tables.collapsible_headers.reallm_current_settings_header_open = ImGui.TreeNodeFlags_DefaultOpen()
      end
        HelpMarker('Set and observe ReaLlm settings. ReaLlm must be installed and enabled for this to work.\n' .. 
        'If ReaLlm settings are edited externally while script is running, or if suspiciously weird numbers encountered, click on Update button.\n\n' .. 
        'IMPORTANT!\nIf any settings on Monitor Chain are changed (like switching a plugin to/from Safe mode (ReaLlm), then directly after this action proceed with some trivial action in Reaper to change Undo count (like play&pause action, but not change track selection!)')
  
      reaper.ImGui_SameLine(ctx)
      if reaper.ImGui_Button(ctx, 'Update') then
        UpdateObservedValuesReaLlm()
      end
      if ImGui.IsItemHovered(ctx) then
        ImGui.SetTooltip(ctx, 'If ReaLlm settings are edited externally while script is running, click on Update button.')
      end
  
      reaper.ImGui_SameLine(ctx)
      local new_pdc_val
      ImGui.PushItemWidth(ctx,100)
      rv, new_pdc_val = ImGui.InputDouble(ctx, 'PDC Limit', llm_pdc_limit, 0.1)
      ImGui.PopItemWidth(ctx)
      if rv then
        reaper.Llm_Set("PDCLIMIT", new_pdc_val)
        UpdateObservedValuesReaLlm()
      end
  
      reaper.ImGui_SameLine(ctx)
      local power_llm
      rv,power_llm = ImGui.Checkbox(ctx, 'ReaLlm ON/OFF', llm_state)
      --fx_ll_hq.print("rv == " .. tostring(rv) .. "power_llm == " .. tostring(power_llm) .. "\n")
      if rv then
        reaper.Main_OnCommand(reallmID, 0)
        if power_llm then
          flag_timed_reallm_update = true
        end
        UpdateObservedValuesReaLlm()
      end
  
  
  
      -- reaper.ImGui_SameLine(ctx)
      -- if reaper.ImGui_Button(ctx, llm_pdc_latency) then
      --   fx_ll_hq.print("updating parameter\n")
      -- end
      -- if ImGui.IsItemHovered(ctx) then
      --   ImGui.SetTooltip(ctx, 'Click to update')
      -- end
      -- reaper.ImGui_SameLine(ctx)
      -- if reaper.ImGui_Button(ctx, llm_pdc_limit) then
      --   fx_ll_hq.print("updating parameter\n")
      -- end
  
      reaper.ImGui_SameLine(ctx)
      --fx_ll_hq.print("current_state_monitoring_fx == " .. tostring(current_state_monitoring_fx) .. "\n")
      rv,current_state_monitoring_fx = ImGui.Checkbox(ctx, 'Process Monitor Chain##' .. " current settings", current_state_monitoring_fx)
      --fx_ll_hq.print("rv == " .. tostring(rv) .. "current_state_monitoring_fx == " .. tostring(current_state_monitoring_fx) .. "\n")
      if rv then
        --reaper.Main_OnCommand(reallmID, 0)
        if current_state_monitoring_fx then
          fx_ll_hq.SetExtState("current_state_monitoring_fx", "true")
          
          reaper.Llm_Set("MONITORINGFX","true")
          
       else
          fx_ll_hq.SetExtState("current_state_monitoring_fx", "false")
          reaper.Llm_Set("MONITORINGFX","")
       end
        --reaper.Main_OnCommand(reallmID, 0)
        UpdateObservedValuesReaLlm()
        flag_timed_reallm_update = true
        
      end
  
     
      -- reaper.ImGui_SameLine(ctx)
      -- rv,rea_state = ImGui.Checkbox(ctx, 'Set Parameter On ReaLimit', rea_state)
      -- --fx_ll_hq.print("rv == " .. tostring(rv) .. "current_state_monitoring_fx == " .. tostring(current_state_monitoring_fx) .. "\n")
      -- if rv then
      --   --reaper.Main_OnCommand(reallmID, 0)
      --   if rea_state then
          
      --     reaper.Llm_Set("PARAMCHANGE", "VST: ReaLimit (Cockos),1,0,1")
          
      --  else
      --   reaper.Llm_Set("PARAMCHANGE", "VST: ReaLimit (Cockos),1,16,16")
      --  end
      --   --reaper.Main_OnCommand(reallmID, 0)
      --   UpdateObservedValuesReaLlm()
      -- end
  
      reaper.ImGui_SameLine(ctx)
      ImGui.PushItemWidth(ctx,50)
      rv, __ = reaper.ImGui_InputText(ctx, "ReaLlm PDC Latency", llm_pdc_latency, ImGui.InputTextFlags_ReadOnly())
      if ImGui.IsItemHovered(ctx) then
        ImGui.SetTooltip(ctx, 'No Input, observe')
      end
      ImGui.PopItemWidth(ctx)
  
      reaper.ImGui_SameLine(ctx)
      if reaper.ImGui_Button(ctx, 'Print extended info Llm_Get to Console') then
        UpdateObservedValuesReaLlm()
        fx_ll_hq.print("--INFO FROM Llm_Get API Function---\n" .. "llm_state == " .. tostring(llm_state) .. "\n" .. "llm_pdc_latency == " .. tostring(llm_pdc_latency) .. "\n" .. "llm_pdc_limit == " .. tostring(llm_pdc_limit) .. "\n" .. "---llm_p_state---\n" .. tostring(llm_p_state) .. "\n" ..  "---llm_safe_plugins---\n" .. tostring(llm_safe_plugins) .. "\n" .. "---llm_graph---\n" .. tostring(llm_graph) .. "\n")
      end
  
  
    else
      if tables.collapsible_headers.reallm_current_settings_header_open ~= 0 then
        tables.collapsible_headers.reallm_current_settings_header_open = 0
      end
    end
  
    -- ImGui.SeparatorText(ctx, 'ReaLlm Startup Preferences Settings (applies to startup preferences only)')
    if ImGui.CollapsingHeader(ctx, 'FX LL HQ - ReaLlm Set Preferences Action - Settings', nil, tables.collapsible_headers.reallm_startup_settings_header_open) then
      if tables.collapsible_headers.reallm_startup_settings_header_open == 0 then
        tables.collapsible_headers.reallm_startup_settings_header_open = 1
      end
      tables.collapsible_headers.reallm_startup_settings_header_open = ImGui.TreeNodeFlags_DefaultOpen()
      -- TODO Script: sockmonkey72_StartupManager.lua - implement from this mtfckr

      HelpMarker("Adjust parameters for execution of ReaLlm Set Preferences Action - Settings\n\n" ..
      "Allow Automatic Startup - Allow ReaLlm to automatically start at REAPER startup\n" ..
      "Process Monitor Chain - Process Monitor Chain\n" ..
      "Set Low Latency & High Quality Mode for plugins - Set Low Latency & High Quality Mode for plugins\n" )

      reaper.ImGui_SameLine(ctx)
      ImGui.PushItemWidth(ctx,100)
      rv, value = ImGui.InputDouble(ctx, 'PDC Limit##' .. 'pref settings', fx_ll_hq.reallm_pref_action_PDC_Limit, 0.1)
      ImGui.PopItemWidth(ctx)
      if rv then
        fx_ll_hq.reallm_pref_action_PDC_Limit = value
      end

      reaper.ImGui_SameLine(ctx)
      rv, value = ImGui.Checkbox(ctx, 'Allow Automatic Startup', fx_ll_hq.reallm_pref_action_AllowAutomaticStartup)
      if rv then 
        fx_ll_hq.reallm_pref_action_AllowAutomaticStartup = value;
        fx_ll_hq.WriteOrUpdateEntryInStartupFile_ReaLlm_Init_Settings(value)
      end
      reaper.ImGui_SameLine(ctx)
      rv, value = ImGui.Checkbox(ctx, 'Process Monitor Chain##' .. "pref settings", fx_ll_hq.reallm_pref_action_ProcessMonitorChain)
      if rv then fx_ll_hq.reallm_pref_action_ProcessMonitorChain = value end
      reaper.ImGui_SameLine(ctx)
      rv, value = ImGui.Checkbox(ctx, 'Set Low Latency & High Quality Mode for plugins', fx_ll_hq.reallm_pref_action_SetLlmAndHqmForPlugins)
      if rv then fx_ll_hq.reallm_pref_action_SetLlmAndHqmForPlugins = value end
    else
      if tables.collapsible_headers.reallm_startup_settings_header_open ~= 0 then
        tables.collapsible_headers.reallm_startup_settings_header_open = 0
      end
    end

  -- ImGui.SeparatorText(ctx, 'Global Mode Switch Settings')
  if ImGui.CollapsingHeader(ctx, 'Global Mode Switch Settings', nil, tables.collapsible_headers.global_mode_switch_settings_header_open) then
    if tables.collapsible_headers.global_mode_switch_settings_header_open == 0 then
      tables.collapsible_headers.global_mode_switch_settings_header_open = ImGui.TreeNodeFlags_DefaultOpen()
    end

    HelpMarker("Adjust parameters for execution of Global Mode Switch Action - Settings\n\n" ..
    "Process Tracks - When action triggered, do you want to affect Track FXs?\n" ..
    "Process Takes - When action triggered, do you want to affect Take FXs?" )
    reaper.ImGui_SameLine(ctx)
    rv,value = ImGui.Checkbox(ctx, 'Process Track FXs', fx_ll_hq.global_mode_switch_ProcessTrackFXs)
    if rv then
      fx_ll_hq.global_mode_switch_ProcessTrackFXs = value
    end
    reaper.ImGui_SameLine(ctx)
    rv, value = ImGui.Checkbox(ctx, 'Process Take FXs', fx_ll_hq.global_mode_switch_ProcessTakeFXs)
    if rv then
      fx_ll_hq.global_mode_switch_ProcessTakeFXs = value
    end
    reaper.ImGui_SameLine(ctx)
    rv, value = ImGui.Checkbox(ctx, 'Process Input FX', fx_ll_hq.global_mode_switch_ProcessInputFx)
    if rv then
      fx_ll_hq.global_mode_switch_ProcessInputFx = value
    end

  else
    if tables.collapsible_headers.global_mode_switch_settings_header_open ~= 0 then
      tables.collapsible_headers.global_mode_switch_settings_header_open = 0
    end
  end



  -- if reaper.ImGui_Button(ctx, 'Click me!') then
  --   click_count = click_count + 1
  -- end
  -- if click_count % 2 == 1 then
  --   reaper.ImGui_SameLine(ctx)
  --   reaper.ImGui_Text(ctx, [[hello dear imgui! \o/]])
  -- end
  -- reaper.ImGui_SameLine(ctx)
  -- if reaper.ImGui_Button(ctx, 'Save to File') then
  --   fx_ll_hq.print("Save triggered\n")
  --   fx_ll_hq.SaveTableValuesToCsvFile()
  -- end
  -- reaper.ImGui_SameLine(ctx)
  -- if reaper.ImGui_Button(ctx, 'Save & Exit') then
  --   fx_ll_hq.print("Save & Exit triggered\n")
  --   fx_ll_hq.SaveTableValuesToCsvFile()
  --   --reaper.atexit(exit)
  --   return true
  -- end
  -- reaper.ImGui_SameLine(ctx)
  -- if reaper.ImGui_Button(ctx, 'Exit') then
  --   fx_ll_hq.print("Exit triggered\n")
  --   --reaper.atexit(exit)
  --   return true
  -- end
  -- if click_count % 2 == 1 then
  --   reaper.ImGui_SameLine(ctx)
  --   reaper.ImGui_Text(ctx, [[hello dear imgui! \o/]])
  -- end

  -- if ImGui.CollapsingHeader(ctx, 'Paths Section', nil, tables.collapsible_headers.paths_section_header_open) then
  --   if tables.collapsible_headers.paths_section_header_open == 0 then
  --     tables.collapsible_headers.paths_section_header_open = ImGui.TreeNodeFlags_DefaultOpen()
  --   end

  --   if tables.collapsible_headers.paths_section_header_open ~= 0 then
  --     tables.collapsible_headers.paths_section_header_open = 0
  --   end
  -- end

---------------------

function demo.PopStyleCompact()
  ImGui.PopStyleVar(ctx, 2)
end


local ret

function demo.PushStyleCompact()
  local frame_padding_x, frame_padding_y = ImGui.GetStyleVar(ctx, ImGui.StyleVar_FramePadding())
  local item_spacing_x,  item_spacing_y  = ImGui.GetStyleVar(ctx, ImGui.StyleVar_ItemSpacing())
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_FramePadding(), frame_padding_x, math.floor(frame_padding_y * 0.60))
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_ItemSpacing(),  item_spacing_x,  math.floor(item_spacing_y  * 0.60))
end

---------------------


  --print is_user_database_file_valid
  if ImGui.CollapsingHeader(ctx, database_configurator_label .. ret_user_database_label, nil, tables.collapsible_headers.user_database_configurator_header_open) --[[and is_user_database_file_valid_static]] then --[[and fx_ll_hq.VerifyNewDatabaseFile(ret_user_database_file_path) then]]
    if tables.collapsible_headers.user_database_configurator_header_open == 0 then
      tables.collapsible_headers.user_database_configurator_header_open = ImGui.TreeNodeFlags_DefaultOpen()
    end

    
    -- fx_ll_hq.print("ret == " ..  tostring(ret) .. "\n")
    -- fx_ll_hq.print("database_configurator_label == " .. database_configurator_label .. "\n")
    --ret, database_configurator_label = fx_ll_hq.IsDatabaseFileValidFeedbackTextReturn(ret_user_database_file_path, database_configurator_label_default, true)


    ret_user_database_file_path, ret_user_database_file_name, ret_user_database_label, is_user_database_file_valid, flag_dialogue_stop, flag_cancel_dialogue_stop, rows_count, table_refresh = fx_ll_hq_gui.PathHandler_forDatabase(ctx, ret_user_database_file_name, ret_user_database_file_path, ret_user_database_label, user_database_label_default, is_user_database_file_valid_static, count_changes, rows_count, table_refresh, flag_refresh_table)
    flag_refresh_table = false
    if is_user_database_file_valid ~= nil then
      is_user_database_file_valid_static = is_user_database_file_valid
      if is_user_database_file_valid and not flag_dialogue_stop then
        -- SET NEW USER DATABASE FILE
        
        fx_ll_hq.print("is_user_database_file_valid == " .. tostring(is_user_database_file_valid) .. "\n")
        fx_ll_hq.print("ret_user_database_file_path == " .. ret_user_database_file_path .. "\n")
        fx_ll_hq.print("ret_user_database_file_name == " .. ret_user_database_file_name .. "\n")
        if flag_cancel_dialogue_stop == false then
          rows_count = fx_ll_hq.ReturnNumberOfRowsInCsvTable(fx_ll_hq.csvUserDatabase)
          fx_ll_hq.print("rows_count OLD == " .. tostring(rows_count) .. "\n")
          fx_ll_hq.SetVar(fx_ll_hq.csvGlobalVariables, fx_ll_hq.file_path_global_variables, fx_ll_hq.gv_identifier_user_database, true, 1, ret_user_database_file_name)
          fx_ll_hq.file_path_user_database = ret_user_database_file_path
          fx_ll_hq.LoadOverwriteNewDatabaseFile(fx_ll_hq.csvUserDatabase, ret_user_database_file_path)
          rows_count = fx_ll_hq.ReturnNumberOfRowsInCsvTable(fx_ll_hq.csvUserDatabase)
          count_changes = 0
          fx_ll_hq.print("rows_count NEW == " .. tostring(rows_count) .. "\n")
          table_refresh = true
          flag_cancel_dialogue_stop = true
        else
          table_refresh = true
          rows_count = fx_ll_hq.ReturnNumberOfRowsInCsvTable(fx_ll_hq.csvUserDatabase)
        end

        
      else
        rows_count = 0
      end
      --fx_ll_hq.print("is_user_database_file_valid_static == " .. tostring(is_user_database_file_valid_static) .. "\n")
    end

    if is_user_database_file_valid_static then

      ImGui.SeparatorText(ctx, 'Database Manager Section')

      --DoOpenAction()
      --if ImGui.TreeNode(ctx, 'Item width') then
      if not tables.buffers or table_refresh then
        table_refresh = false
        tables.buffers = {
          -- fx_identifiers_buf = {},
          -- par_idx_buf = {},
          -- ll_val_buf = {},
          -- hq_val_buf = {},
          isOpen_buf = {},
          -- isOpen_prev_buf = {},
          --input_buf = {},
          -- flag_first_buf = {},
          -- flag_changed_buf = {},
          -- input_inputText_buf = {},
          set_focus_buf = {},
          --flags1 = ImGui.TableFlags_BordersV(),
          --show_headers = false,

          --flags2 = ImGui.TableFlags_Borders() | ImGui.TableFlags_RowBg(),
          --cell_padding = { 0.0, 0.0 },
          --show_widget_frame_bg = true,
          text_bufs = {}, -- Mini text storage for 3x5 cells
          -- filters_bufs = {},
        }

        -- local num_filterSearch_idxs = #fx_ll_hq.database_format_table_filterSearch_idxs + 1
        -- fx_ll_hq.print("num_filterSearch_idxs == " .. num_filterSearch_idxs .. "\n")

      end

      -- local function UpdateRow(idx, row, value)
      --     fx_ll_hq.print("idx == " .. tostring(idx) .. " row == " .. tostring(row) .. " value == " .. tostring(value) .. "\n")
      --     local new_fx_identifier, new_fx_name, new_developer, new_format, index_tables
          
      --     if idx == 1 then -- fx identifier
      --       new_fx_identifier = value
      --       for i = 1, #USER_FX_IDENTIFIER_TAB do
      --         if USER_FX_IDENTIFIER_TAB[i] == new_fx_identifier then
      --           index_tables = i
      --           new_fx_identifier = value
      --           break
      --         end
      --       end
      --     end

      --     if new_fx_identifier then
      --       --new_format, new_fx_name, new_developer = fx_ll_hq.GetSeparateValuesFromFxListEntry(new_fx_identifier)
      --       tables.buffers.input_bufs[1][row] = new_fx_identifier
      --       fx_ll_hq.print("new_fx_identifier == " .. tostring(new_fx_identifier) .. "\n")
      --     end
      -- end

      if not tables.resz_mixed then
        tables.resz_mixed = {
          flags = ImGui.TableFlags_SizingFixedFit() |
                  ImGui.TableFlags_RowBg() | ImGui.TableFlags_Borders() |
                  ImGui.TableFlags_Resizable() |
                  ImGui.TableFlags_Reorderable() | ImGui.TableFlags_Hideable()
        }
      end
      if not tables.col_widths then
        tables.col_widths = {
          flags1 = ImGui.TableFlags_Borders() | ImGui.TableFlags_Resizable() ,
                  -- ImGui.TableFlags_NoBordersInBodyUntilResize(),
          flags2 = ImGui.TableFlags_None(),
        }
      end
      if not tables.reorder then
        tables.reorder = {
          flags = ImGui.TableFlags_Resizable() |
                  ImGui.TableFlags_Reorderable() |
                  ImGui.TableFlags_Hideable() |
                  ImGui.TableFlags_Sortable()        |
                  ImGui.TableFlags_SortMulti()       |
                  ImGui.TableFlags_SortTristate()    |
                  ImGui.TableFlags_RowBg()           |
                  ImGui.TableFlags_BordersOuter() |
                  ImGui.TableFlags_BordersV() |
                  -- ImGui.TableFlags_NoBordersInBody() |
                  ImGui.TableFlags_ScrollY(),
        }
      end
      demo.PushStyleCompact()
      -- rv,tables.reorder.flags = ImGui.CheckboxFlags(ctx, 'ImGuiTableFlags_Resizable', tables.reorder.flags, ImGui.TableFlags_Resizable())
      
      -- rv,tables.reorder.flags = ImGui.CheckboxFlags(ctx, 'ImGuiTableFlags_Reorderable', tables.reorder.flags, ImGui.TableFlags_Reorderable())

      -- rv,tables.reorder.flags = ImGui.CheckboxFlags(ctx, 'ImGuiTableFlags_Hideable', tables.reorder.flags, ImGui.TableFlags_Hideable())
      --   fx_ll_hq.print("rv = " .. tostring(rv) .. " tables.reorder.flags = " .. tostring(tables.reorder.flags) .. "\n")
        tables.reorder.flags = 1799
      -- rv,tables.reorder.flags = ImGui.CheckboxFlags(ctx, 'ImGuiTableFlags_NoBordersInBody', tables.reorder.flags, ImGui.TableFlags_NoBordersInBody())
      -- rv,tables.reorder.flags = ImGui.CheckboxFlags(ctx, 'ImGuiTableFlags_NoBordersInBodyUntilResize', tables.reorder.flags, ImGui.TableFlags_NoBordersInBodyUntilResize()); ImGui.SameLine(ctx); demo.HelpMarker('Disable vertical borders in columns Body until hovered for resize (borders will always appear in Headers)')
      demo.PopStyleCompact()


      HelpMarker(
        "TABLE VALUES:\n\n"..
        "---General Info---\nFor automated recognition of all variables above use TODO function.\n\n"..
        "---FX Identifier---\nChoose desired effect. You can click on some with mouse, or scroll with up/down keyboard arrows and select marked identifier by pressing enter. If desired, you can also set to non-existent identifier with Shift+Enter keyboard combo.\n\n"..
        "---Parameter Index---\nSelect a parameter index (counted from zero) which might get affected.\n\n"..
        "---Low Latency Value---\nSet value Parameter will be set to when in Low Latency mode.\n\n".. 
        "---High Quality Value---\nSet value Parameter will be set to when in High Quality mode.\n\n"..
        "----------------------------------------------------------------------------------------------\n\n"..
        "TABLE FUNCTIONS:\n\n"..
        "---Add Row---\nAdds a new row to the table.\n\n"..
        "---Reset Table from file---\nIf User Database file is edited directly while script is open, 'Reset Table from file' button will trigger catching it's current state. Unsaved changes will be discarted.\n\n"..
        "---Import data from reference database---\nOpens a file dialogue window to select a reference database file. If selected file is valid, it will be used to fill in the table with data.\n\n"..
        "---Export data to database---\nOpens a file dialogue window to select a database file. If selected file is valid, it will be used to save the table data to it.\n\n"..
        "---Clear table---\nClears the table.\n\n"..
        "---Reset table---\nResets the table to default values.\n\n"..
        "---Copy table to clipboard---\nCopies the table data to clipboard.\n\n"..
        "---Paste table from clipboard---\nPastes the table data from clipboard.\n\n")
      --if ImGui.BeginTable(ctx, 'table_item_width', cols_count, ImGui.TableFlags_Borders()) then

      -- reaper.ImGui_SameLine(ctx)
      -- if reaper.ImGui_Button(ctx, 'Import data from reference database') then
      --   local file_path = fx_ll_hq.OpenSystemFileOpenDialogue_ReturnFilePath()
      --   if file_path ~= nil and fx_ll_hq.file_exists_file_path(file_path) and fx_ll_hq.IsDatabaseFileValidFeedbackTextReturn(file_path, "", false) then
      --     --fx_ll_hq.print("ret_file_path == " .. file_path_OUT .. "\n")
      --     fx_ll_hq.print("reference valid file_path == " .. file_path .. "\n")

      --   else
      --     fx_ll_hq.print("reference invalid file_path or cancelled\n")
      --   end
        
      -- end

      reaper.ImGui_SameLine(ctx)
      if reaper.ImGui_Button(ctx, 'Add Row') then
        -- local row_content = fx_ll_hq.emptyNewRowDatabase
        fx_ll_hq.print("rows_count before add == " .. tostring(rows_count) .. "\n")
        -- row_content[fx_ll_hq.row_num_IDX] = fx_ll_hq.ReturnNumberOfRowsInCsvTable(fx_ll_hq.csvUserDatabase) + 1
        fx_ll_hq.add_empty_row_to_csv_table(fx_ll_hq.csvUserDatabase)
        rows_count = rows_count + 1
        fx_ll_hq.print("rows_count after add == " .. tostring(rows_count) .. "\n")
        -- fx_ll_hq.UpdateRowsNumbersCsvTableDatabase()
        --count_changes = count_changes + 1
        --table_refresh = true
      end

      -- fx_ll_hq.print("!!! ")

      reaper.ImGui_SameLine(ctx)

      if reaper.ImGui_Button(ctx, 'Reset Table from file') then
        count_changes, rows_count, table_refresh = fx_ll_hq.ResetTableFromFile(fx_ll_hq.csvUserDatabase, fx_ll_hq.file_path_user_database)
      end

      reaper.ImGui_SameLine(ctx)

      if not popups.modal then
        popups.modal = {
          dont_ask_me_next_time = false,
          item  = 1,
          color = 0x66b30080,
        }
      end

      if ImGui.Button(ctx, 'Import data from reference database') or flag_try_again then
        fx_ll_hq.print("rows count == " .. tostring(rows_count) .. "\n")
        fx_ll_hq.PrintCsvTableDatabase(fx_ll_hq.csvUserDatabase)

          file_path_user_selected_reference_database = fx_ll_hq.OpenSystemFileOpenDialogue_ReturnFilePath()
          if file_path_user_selected_reference_database ~= nil and fx_ll_hq.file_exists_file_path(file_path_user_selected_reference_database) and fx_ll_hq.VerifyNewDatabaseFile(file_path_user_selected_reference_database) then
            --fx_ll_hq.print("ret_file_path == " .. file_path_OUT .. "\n")
            fx_ll_hq.print("reference valid file_path == " .. file_path_user_selected_reference_database .. "\n")
            ImGui.OpenPopup(ctx, 'Import reference database?')
            --ImGui.OpenPopup(ctx, 'Stacked 2')
          elseif file_path_user_selected_reference_database == nil then
            fx_ll_hq.print("cancelled from 'Open Dialogue'\n")
          else
            fx_ll_hq.print("reference invalid file_path\n")
            ImGui.OpenPopup(ctx, 'Invalid file')
          end
          flag_try_again = false
      end


      -- local unused_open = true
      -- if ImGui.BeginPopupModal(ctx, 'Stacked 2', unused_open) then
      --   ImGui.Text(ctx, 'Hello from Stacked The Second!')
      --   if ImGui.Button(ctx, 'Close') then
      --     ImGui.CloseCurrentPopup(ctx)
      --   end
      --   ImGui.EndPopup(ctx)
      -- end

      -- Always center this window when appearing
      local center = {ImGui.Viewport_GetCenter(ImGui.GetWindowViewport(ctx))}
      ImGui.SetNextWindowPos(ctx, center[1], center[2], ImGui.Cond_Appearing(), 0.5, 0.5)

      if ImGui.BeginPopupModal(ctx, 'Import reference database?', nil, ImGui.WindowFlags_AlwaysAutoResize()) then

          ImGui.Text(ctx, 'Matching rows will be replaced.\nNot matching rows will be added.\n\n' .. 'Overwrite current user database table?')
          ImGui.Separator(ctx)

          --static int unused_i = 0;
          --ImGui.Combo("Combo", &unused_i, "Delete\0Delete harder\0");

          -- ImGui.PushStyleVar(ctx, ImGui.StyleVar_FramePadding(), 0, 0)
          -- rv,popups.modal.dont_ask_me_next_time =
          --   ImGui.Checkbox(ctx, "Don't ask me next time", popups.modal.dont_ask_me_next_time)
          -- ImGui.PopStyleVar(ctx)

          if ImGui.Button(ctx, 'OK', 120, 0) then
            flag_try_again = false
            ImGui.CloseCurrentPopup(ctx)
            fx_ll_hq.print("OK from 'Import reference database?'\n")
            rows_count, table_refresh = fx_ll_hq.ImportReferenceDatabaseToUserDatabaseTable(file_path_user_selected_reference_database)
            count_changes = count_changes + 1
          end
          
          ImGui.SameLine(ctx)
          ImGui.SetItemDefaultFocus(ctx)
          if ImGui.Button(ctx, 'Cancel', 120, 0) then
            flag_try_again = false
            ImGui.CloseCurrentPopup(ctx)
            fx_ll_hq.print("Cancel from 'Import reference database?'\n")
          end
          ImGui.EndPopup(ctx)

          --flag_try_again_not_first_time = false
        
      end

      if ImGui.BeginPopupModal(ctx, 'Invalid file', nil, ImGui.WindowFlags_AlwaysAutoResize()) then
          ImGui.Text(ctx, 'Chosen file is not a valid database file.\nPlease, choose another one.')
          ImGui.Separator(ctx)

          --static int unused_i = 0;
          --ImGui.Combo("Combo", &unused_i, "Delete\0Delete harder\0");

          -- ImGui.PushStyleVar(ctx, ImGui.StyleVar_FramePadding(), 0, 0)
          -- rv,popups.modal.dont_ask_me_next_time =
          --   ImGui.Checkbox(ctx, "Don't ask me next time", popups.modal.dont_ask_me_next_time)
          -- ImGui.PopStyleVar(ctx)
          -- ImGui.SetCursorPosX( (ImGui.GetWindowWidth(ctx) - ImGui.CalcTextSize(ctx, text).x) / 2);
          -- if ImGui.Button(ctx, 'Try again', ImGui.ImVec2(0.0,0.5)) then ImGui.CloseCurrentPopup(ctx) end
          ImGui.SetItemDefaultFocus(ctx)
          if ImGui.Button(ctx, 'Try again',120,0) then
            flag_try_again = true
            --ImGui.CloseCurrentPopup(ctx)
            fx_ll_hq.print("Try again from 'Invalid file'\n")
          end
          ImGui.SameLine(ctx)
          if ImGui.Button(ctx, 'Cancel',120,0) then
            fx_ll_hq.print("Cancel from 'Invalid file'\n")
            flag_try_again = false
            ImGui.CloseCurrentPopup(ctx) 
          end
          ImGui.EndPopup(ctx)
      end

      ImGui.SameLine(ctx)
      if ImGui.Button(ctx, 'Erase content from table') then
        fx_ll_hq.ClearSelfCsvTable(fx_ll_hq.csvUserDatabase)
        rows_count = 0
        modify_changes_counter()
      end

      -- if flag_capture_parameter_live then
      --   ButtonColor = default_button_color_toggle_on
      -- else
      --   ButtonColor = default_button_color_toggle_off
      -- end

      -- r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(), ButtonColor) -- DEFAULT BG
      ImGui.SameLine(ctx)
      if ImGui.Button(ctx, 'Capture Last Touched FX Parameter') then
        first_loop_capture = true
        if flag_capture_parameter_live then 
          flag_capture_parameter_live = false 
        else
          flag_capture_parameter_live = true
        end
      end

      if ImGui.IsItemHovered(ctx) then
        ImGui.SetTooltip(ctx, fx_ll_hq.ReturnObservedStringLastTouchedParameter())
      end

      ImGui.SameLine(ctx)
      if ImGui.Button(ctx, 'Save User Database Table to File') then
        count_changes = fx_ll_hq.SafeSaveTableToCsvFileAndReload(fx_ll_hq.csvUserDatabase, ret_user_database_file_path)
      end

      ImGui.SameLine(ctx)
      if ImGui.Button(ctx, 'SetReaLlm_FX_LL_HQ_FromUserDatabase') then
          fx_ll_hq.SetReaLlm_FX_LL_HQ_FromUserDatabase()
      end

      if ImGui.Button(ctx, 'Make Table Sequence Permanent') then
        fx_ll_hq.MakeRowsSequencePermament_ReNumberRows()
        table_refresh = true
      end

      ImGui.SameLine(ctx)
      if ImGui.Button(ctx, 'Test') then
        fx_ll_hq.UpdateRowsNumbersCsvTableDatabase(fx_ll_hq.csvUserDatabase)
          -- fx_ll_hq.SetReaLlm_FX_LL_HQ_FromUserDatabase()
          -- local column_row = fx_ll_hq.row_num_IDX
          -- fx_ll_hq.SetAttributeByRowAndColumnToCsvTable(fx_ll_hq.csvUserDatabase, 3, column_row, 7)
          -- table_refresh = true
        -- fx_ll_hq.GetModKeys(ctx)
        -- local test_val = true
        --   fx_ll_hq.print("TYPE == " .. type(test_val) .. "\n")
        --fx_ll_hq.CompareUserDatabaseTableAndCsvFile(fx_ll_hq.csvUserDatabase, rows_count)
        -- local table = fx_ll_hq.GetSelfCsvTable(fx_ll_hq.csvUserDatabase)
        -- table = {}
        -- fx_ll_hq.SetSelfCsvTable(fx_ll_hq.csvUserDatabase, table)
        -- fx_ll_hq.print("table == " .. tostring(table) .. "\n")
        -- fx_ll_hq.print("table[1] == " .. tostring(table[1][2]) .. "\n")
      end


      

      -- r.ImGui_PopStyleColor(ctx)

      if flag_capture_parameter_live then
        flag_capture_parameter_live = false
        local ret_capture, flag_new_track = fx_ll_hq.CaptureLastTouchedFxParameter()
        fx_ll_hq.print("ret_capture == " .. tostring(ret_capture) .. "\n")
        if ret_capture == 1 then
          flag_capture_parameter_live = false
          if flag_new_track then
            rows_count = rows_count + 1
          end
          fx_ll_hq.UpdateRowsNumbersCsvTableDatabase(fx_ll_hq.csvUserDatabase)
          table_refresh = true
          modify_changes_counter()
        end
      end


          --- Search in Database ---
      -- if r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Escape()) or database_search_set_focus then
      --     --SET_FOCUS = nil
      --     --ADDFX_Sel_Entry = 1
      --     --tables.buffers.input_inputText_buf[row] = 'aaaaaaaaaaaaa'
      --     --r.ImGui_SetKeyboardFocusHere(ctx)
      --     database_search_isOpen = false
      -- end
      --ImGui.PushItemWidth(ctx, -FLT_MIN) -- Right-aligned
      rv, value = r.ImGui_InputText(ctx, "Filter User Database Table##autoComplete_textInput_database" , dabase_search_text_buffer, r.ImGui_InputTextFlags_AutoSelectAll())

      if rv then
        dabase_search_text_buffer = value
      end

      -- ImGui.PushItemWidth(ctx, -FLT_MIN) -- Right-aligned
      

      -- fx_ll_hq.print(" fx_ll_hq.GetAttributeByRowAndColumnFromCsvTable(fx_ll_hq.csvUserDatabase,row,column_tab) == " ..  fx_ll_hq.GetAttributeByRowAndColumnFromCsvTable(fx_ll_hq.csvUserDatabase,row,column_tab) .. "\n")
      -- fx_ll_hq.print(" fx_ll_hq.GetAttributeByRowAndColumnFromCsvTable(fx_ll_hq.csvUserDatabase,1,1) == " ..  fx_ll_hq.GetAttributeByRowAndColumnFromCsvTable(fx_ll_hq.csvUserDatabase,1,1) .. "\n")
      -- value, filtered_database = fx_ll_hq_gui.autoComplete_database_search(fx_ll_hq.csvUserDatabase,dabase_search_text_buffer)
      

      if dabase_search_text_buffer ~= "" then
        fx_ll_hq.print("SEARCH ACTIVATED dabase_search_text_buffer == " ..  dabase_search_text_buffer .. "\n")
        fx_ll_hq.MarkFilterCsvTableDatabase(fx_ll_hq.csvUserDatabase, dabase_search_text_buffer)
        -- fx_ll_hq.print("#filtered_database == " ..  #filtered_database .. "\n")
        flag_filtered_database = true
      end

      if prev_dabase_search_text_buffer ~= "" and dabase_search_text_buffer == "" then
        fx_ll_hq.UnmarkFilterCsvTableDatabase(fx_ll_hq.csvUserDatabase)
        flag_filtered_database = false
      end

      prev_dabase_search_text_buffer = dabase_search_text_buffer

      -- Helper to display a little (?) mark which shows a tooltip when hovered.
      -- In your own code you may want to display an actual icon if you are using a merged icon fonts (see docs/FONTS.md)
      function demo.HelpMarker(desc)
        ImGui.TextDisabled(ctx, '(?)')
        if ImGui.IsItemHovered(ctx, ImGui.HoveredFlags_DelayShort()) then
          ImGui.BeginTooltip(ctx)
          ImGui.PushTextWrapPos(ctx, ImGui.GetFontSize(ctx) * 35.0)
          ImGui.Text(ctx, desc)
          ImGui.PopTextWrapPos(ctx)
          ImGui.EndTooltip(ctx)
        end
      end

    
      function demo.CompareTableItems(a, b)
        local next_id = 0
        while true do
          local ok, col_user_id, col_idx, sort_order, sort_direction = ImGui.TableGetColumnSortSpecs(ctx, next_id)
          --fx_ll_hq.print("col_idx == " .. col_idx .. "\n")
          if not ok then break end
          next_id = next_id + 1
      
          -- Here we identify columns using the ColumnUserID value that we ourselves passed to TableSetupColumn()
          -- We could also choose to identify columns based on their index (col_idx), which is simpler!
          -- local key
          -- if col_user_id == MyItemColumnID_row_num then
          --   key = 1
          -- elseif col_user_id == MyItemColumnID_fx_identifier then
          --   key = 2
          -- elseif col_user_id == MyItemColumnID_par_idx then
          --   key = 3
          -- elseif col_user_id == MyItemColumnID_ll_val then
          --   key = 4
          -- elseif col_user_id == MyItemColumnID_hq_val then
          --   key = 5
          -- else
          --   error('unknown user column ID')
          -- end
      
          local is_ascending = sort_direction == ImGui.SortDirection_Ascending()

          if a[col_idx+1] < b[col_idx+1] then
            return is_ascending
          elseif a[col_idx+1] > b[col_idx+1] then
            return not is_ascending
          end
        end
      
        -- table.sort is instable so always return a way to differenciate items.
        -- Your own compare function may want to avoid fallback on implicit sort specs e.g. a Name compare if it wasn't already part of the sort specs.
        return a[1] < b[1]
      end

      -- local template_items_names = {
      --   'Banana', 'Apple', 'Cherry', 'Watermelon', 'Grapefruit', 'Strawberry', 'Mango',
      --   'Kiwi', 'Orange', 'Pineapple', 'Blueberry', 'Plum', 'Coconut', 'Pear', 'Apricot'
      -- }

      -- if ImGui.TreeNode(ctx, 'Sorting') then
        if not tables.sorting then
          tables.sorting = {
            flags = ImGui.TableFlags_Resizable()       |
                    ImGui.TableFlags_Reorderable()     |
                    ImGui.TableFlags_Hideable()        |
                    ImGui.TableFlags_Sortable()        |
                    ImGui.TableFlags_SortMulti()       |
                    ImGui.TableFlags_RowBg()           |
                    ImGui.TableFlags_BordersOuter()    |
                    ImGui.TableFlags_BordersV()        |
                    -- ImGui.TableFlags_NoBordersInBody() |
                    ImGui.TableFlags_ScrollY(),
            items = {},
          }
    
          -- -- Create item list
          -- for n = 0, 49 do
          --   local template_n = n % #template_items_names
          --   local item = {
          --     id = n,
          --     name = template_items_names[template_n + 1],
          --     quantity = (n * n - n) % 20, -- Assign default quantities
          --   }
          --   table.insert(tables.sorting.items, item)
          -- end

          -- Create item list
          -- for row = 1, rows_count do
          --   local item = {
          --     fx_ll_hq.GetAttributeByRowAndColumnFromCsvTable(fx_ll_hq.csvUserDatabase, row, 1),
          --     fx_ll_hq.GetAttributeByRowAndColumnFromCsvTable(fx_ll_hq.csvUserDatabase, row, 2),
          --     fx_ll_hq.GetAttributeByRowAndColumnFromCsvTable(fx_ll_hq.csvUserDatabase, row, 3),
          --     fx_ll_hq.GetAttributeByRowAndColumnFromCsvTable(fx_ll_hq.csvUserDatabase, row, 4),
          --     fx_ll_hq.GetAttributeByRowAndColumnFromCsvTable(fx_ll_hq.csvUserDatabase, row, 5),
          --   }
          --   table.insert(tables.sorting.items, item)
          -- end


        end
    
        -- -- Options
        -- demo.PushStyleCompact()
        -- rv,tables.sorting.flags = ImGui.CheckboxFlags(ctx, 'ImGuiTableFlags_SortMulti', tables.sorting.flags, ImGui.TableFlags_SortMulti())
        -- ImGui.SameLine(ctx); demo.HelpMarker('When sorting is enabled: hold shift when clicking headers to sort on multiple column. TableGetSortSpecs() may return specs where (SpecsCount > 1).')
        -- rv,tables.sorting.flags = ImGui.CheckboxFlags(ctx, 'ImGuiTableFlags_SortTristate', tables.sorting.flags, ImGui.TableFlags_SortTristate())
        -- ImGui.SameLine(ctx); demo.HelpMarker('When sorting is enabled: allow no sorting, disable default sorting. TableGetSortSpecs() may return specs where (SpecsCount == 0).')
        -- demo.PopStyleCompact()
    
        -- local set_number_of_rows_visible = 15
        -- local visible_rows_count = fx_ll_hq.ReturnNumberOfRowsInCsvTable(fx_ll_hq.csvUserDatabase, removed_rows_tab)
        -- if visible_rows_count < set_number_of_rows_visible then
        --   -- set next number to double from int

        --   set_number_of_rows_visible =  visible_rows_count * 2
        -- end
        -- fx_ll_hq.print("set_number_of_rows_visible == " .. set_number_of_rows_visible .. "\n")
        --fx_ll_hq.print("cols_count == " .. cols_count .. "\n")
        if ImGui.BeginTable(ctx, 'table_sorting', cols_count+1, tables.sorting.flags) then
          -- Declare columns
          -- We use the "user_id" parameter of TableSetupColumn() to specify a user id that will be stored in the sort specifications.
          -- This is so our sort function can identify a column given our own identifier. We could also identify them based on their index!
          -- Demonstrate using a mixture of flags among available sort-related flags:
          -- - ImGuiTableColumnFlags_DefaultSort
          -- - ImGuiTableColumnFlags_NoSort / ImGuiTableColumnFlags_NoSortAscending / ImGuiTableColumnFlags_NoSortDescending
          -- - ImGuiTableColumnFlags_PreferSortAscending / ImGuiTableColumnFlags_PreferSortDescending
          -- ImGui.TableSetupColumn(ctx, 'Row',      ImGui.TableColumnFlags_PreferSortDescending()          | ImGui.TableColumnFlags_WidthFixed(),   0.0, MyItemColumnID_row_num)
          -- ImGui.TableSetupColumn(ctx, 'FX Identifier',     ImGui.TableColumnFlags_DefaultSort()           |                                       ImGui.TableColumnFlags_WidthFixed(),   0.0, MyItemColumnID_fx_identifier)
          -- ImGui.TableSetupColumn(ctx, 'Parameter Index',   ImGui.TableColumnFlags_DefaultSort()              | ImGui.TableColumnFlags_WidthFixed(),   0.0, MyItemColumnID_par_idx)
          -- ImGui.TableSetupColumn(ctx, 'Low Latency Value', ImGui.TableColumnFlags_NoSort()  | ImGui.TableColumnFlags_WidthStretch(), 0.0, MyItemColumnID_ll_val)
          -- ImGui.TableSetupColumn(ctx, 'High Quality Value', ImGui.TableColumnFlags_NoSort() | ImGui.TableColumnFlags_WidthStretch(), 0.0, MyItemColumnID_hq_val)

          ImGui.TableSetupColumn(ctx, fx_ll_hq.fx_database_table_header_row[fx_ll_hq.row_num_IDX], ImGui.TableColumnFlags_WidthFixed() | ImGui.TableColumnFlags_PreferSortDescending(), TEXT_BASE_WIDTH * 12.0,1)
          ImGui.TableSetupColumn(ctx, fx_ll_hq.fx_database_table_header_row[fx_ll_hq.fx_identifier_IDX], ImGui.TableColumnFlags_WidthStretch() | ImGui.TableColumnFlags_DefaultSort(), nil, 2)
          ImGui.TableSetupColumn(ctx, fx_ll_hq.fx_database_table_header_row[fx_ll_hq.par_idx_IDX], ImGui.TableColumnFlags_WidthFixed() | ImGui.TableColumnFlags_DefaultSort(),100, 3)
          ImGui.TableSetupColumn(ctx, fx_ll_hq.fx_database_table_header_row[fx_ll_hq.ll_val_IDX], ImGui.TableColumnFlags_WidthFixed() | ImGui.TableColumnFlags_NoSort(), 200, 4)
          ImGui.TableSetupColumn(ctx, fx_ll_hq.fx_database_table_header_row[fx_ll_hq.hq_val_IDX], ImGui.TableColumnFlags_WidthFixed() | ImGui.TableColumnFlags_NoSort(), 200, 5)
          ImGui.TableSetupColumn(ctx, fx_ll_hq.fx_database_table_header_row[fx_ll_hq.active_IDX], ImGui.TableColumnFlags_WidthFixed() | ImGui.TableColumnFlags_NoSort(), 200, 6)
          ImGui.TableSetupColumn(ctx, " X ", ImGui.TableColumnFlags_WidthFixed(),  50, 7)
          ImGui.TableSetupScrollFreeze(ctx, 0, 1) -- Make row always visible
          ImGui.TableHeadersRow(ctx)

          -- ImGui.TableSetupScrollFreeze(ctx, 0, 1) -- Make row always visible
          -- ImGui.TableHeadersRow(ctx)
    
          -- Sort our data if sort specs have been changed!
          if ImGui.TableNeedSort(ctx) then
            --table.sort(tables.sorting.items, demo.CompareTableItems)
            table_refresh = fx_ll_hq.SortCsvTable(fx_ll_hq.csvUserDatabase, ctx)
          end
    
          -- Demonstrate using clipper for large vertical lists
          -- local clipper = ImGui.CreateListClipper(ctx)
          -- ImGui.ListClipper_Begin(clipper, INT_MAX, -1)
          -- while ImGui.ListClipper_Step(clipper) do
          --   local display_start, display_end = ImGui.ListClipper_GetDisplayRange(clipper)
            -- fx_ll_hq.print("display_start == " .. display_start .. "\n")
            -- fx_ll_hq.print("display_end == " .. display_end .. "\n")
            
            -- for row_n = display_start, display_end - 1 do
            --   --fx_ll_hq.print("row_n == " .. row_n .. "\n")
            --   local row = row_n + 1
            --   -- Display a data item
            --   local item = tables.sorting.items[row_n + 1]
            -- local table_order
            -- local row
            -- for i = 1, #table_order do
            --   row = table_order[i][1]
            for row = 1, rows_count do -----------------------------------------------------------------------------------------TABLE LOOP FOR LOOPS START
              -- if row > rows_count then row = 1 end
              --if row == 1 then flag_init_row = true end
              -- fx_ll_hq.print("LOOP BEGINNING rows_count == " .. rows_count .. " row == " .. row .. "\n")
              if fx_ll_hq.GetAttributeByRowAndColumnFromCsvTable(fx_ll_hq.csvUserDatabase, row, fx_ll_hq.filter_IDX) == false then
                -- fx_ll_hq.print("row removed == " .. row .. "\n")
                goto continue_table_next_row
              end
              -- fx_ll_hq.print("test after first get\n")
              

    
              -- ImGui.TableNextRow(ctx)
              -- if flag_init_row then
              --   flag_init_row = false
              --   -- Setup ItemWidth once (instead of setting up every time, which is also possible but less efficient)
              --   -- ImGui.TableSetColumnIndex(ctx, 0)
              --   -- ImGui.PushItemWidth(ctx, TEXT_BASE_WIDTH * 3.0) -- Small
              --   -- ImGui.TableSetColumnIndex(ctx, 1)
              --   -- ImGui.PushItemWidth(ctx, 0 - ImGui.GetContentRegionAvail(ctx) * 0.5)
              --   for i = 1, cols_count do
              --     ImGui.TableSetColumnIndex(ctx, i-1)
              --     ImGui.PushItemWidth(ctx, -FLT_MIN) -- Right-aligned
              --     --ID = row .. "_" .. i
              --   end
              -- end
              -- fx_ll_hq.print("fx_ll_hq.GetAttributeByRowAndColumnFromCsvTable(fx_ll_hq.csvUserDatabase, " .. row .. ", " .. fx_ll_hq.row_num_IDX .. ") == " .. fx_ll_hq.GetAttributeByRowAndColumnFromCsvTable(fx_ll_hq.csvUserDatabase, row, fx_ll_hq.row_num_IDX) .. "\n")
              ImGui.PushID(ctx, fx_ll_hq.GetAttributeByRowAndColumnFromCsvTable(fx_ll_hq.csvUserDatabase, row, fx_ll_hq.row_num_IDX))
              ImGui.TableNextRow(ctx)
              ImGui.TableNextColumn(ctx)
              ImGui.PushItemWidth(ctx, -FLT_MIN) -- Right-aligned
    
              --- Row ---
              r.ImGui_Selectable(ctx, ('%04d'):format(fx_ll_hq.GetAttributeByRowAndColumnFromCsvTable(fx_ll_hq.csvUserDatabase, row, fx_ll_hq.row_num_IDX)), false)

              if r.ImGui_BeginDragDropSource(ctx, r.ImGui_DragDropFlags_SourceAllowNullID()) then
                r.ImGui_SetDragDropPayload(ctx, 'row', row)
                r.ImGui_EndDragDropSource(ctx)
              end
        
              if r.ImGui_BeginDragDropTarget(ctx) then
                local rv, payload = r.ImGui_AcceptDragDropPayload(ctx, 'row')
                
                if rv then
                  local shift = reaper.ImGui_GetKeyMods(ctx) & reaper.ImGui_Mod_Shift() > 0
                  if shift then
                    table_refresh = fx_ll_hq.ExchangeRowsInCsvTable(fx_ll_hq.csvUserDatabase, row, payload)
                  else
                    table_refresh = fx_ll_hq.MoveRowInCsvTable(fx_ll_hq.csvUserDatabase, row, payload)
                  end
                  
                end
                r.ImGui_EndDragDropTarget(ctx)
              end
              --- FX Identifier ---
              ImGui.TableNextColumn(ctx)
              ImGui.PushItemWidth(ctx, -FLT_MIN) -- Right-aligned
              --fx_ll_hq.print("fx_ll_hq.fx_identifier_IDX FX Identifier == " .. tostring(fx_ll_hq.fx_identifier_IDX) .. "\n")
              --id_tab = fx_ll_hq.fx_identifier_IDX - 1
              --fx_ll_hq.print("id_tab FX Identifier == " .. tostring(id_tab) .. "\n")
              --ImGui.TableSetColumnIndex(ctx, id_tab)
              -- ALWAYS SET FOCUS ON INPUT AFTER KEY CONFIRM OR CANCEL OPERATIONS
              if r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Escape()) or tables.buffers.set_focus_buf[row] then
                  --SET_FOCUS = nil
                  --ADDFX_Sel_Entry = 1
                  --tables.buffers.input_inputText_buf[row] = 'aaaaaaaaaaaaa'
                  --r.ImGui_SetKeyboardFocusHere(ctx)
                  tables.buffers.isOpen_buf[row] = false
              end
    
              rv, value = r.ImGui_InputText(ctx, "##autoComplete_textInput_tableRow__" .. row, fx_ll_hq.GetAttributeByRowAndColumnFromCsvTable(fx_ll_hq.csvUserDatabase,row,fx_ll_hq.fx_identifier_IDX), r.ImGui_InputTextFlags_AutoSelectAll())
              if rv then
                fx_ll_hq.SetAttributeByRowAndColumnToCsvTable(fx_ll_hq.csvUserDatabase, row, fx_ll_hq.fx_identifier_IDX, value)
              end

              tables.buffers.isOpen_buf[row], value, tables.buffers.set_focus_buf[row] = fx_ll_hq_gui.autoComplete(ctx, tables.buffers.isOpen_buf[row], fx_ll_hq.GetAttributeByRowAndColumnFromCsvTable(fx_ll_hq.csvUserDatabase,row,fx_ll_hq.fx_identifier_IDX), fx_identifier_tab,row)
    
              fx_ll_hq.SetAttributeByRowAndColumnToCsvTable(fx_ll_hq.csvUserDatabase, row, fx_ll_hq.fx_identifier_IDX, value)
    
              if rv then
                fx_ll_hq.SetAttributeByRowAndColumnToCsvTable(fx_ll_hq.csvUserDatabase, row, fx_ll_hq.fx_identifier_IDX, value)
                modify_changes_counter()
              end

    
              --- Parameter ID --- 
              ImGui.TableNextColumn(ctx)
              ImGui.PushItemWidth(ctx, -FLT_MIN) -- Right-aligned
              
              
              if ImGui.SmallButton(ctx, 'Capture##' .. row .. "_" .. fx_ll_hq.par_idx_IDX)  then
                fx_ll_hq.print("Capture Parameter Index row " .. row .. " fx_ll_hq.par_idx_IDX " .. fx_ll_hq.par_idx_IDX .. "\n")
                local ret_capture, _, _, paramnumber, _, minval, maxval = fx_ll_hq.CaptureVariousValuesOfLastTouchedFxParameter(row, true)

                if ret_capture == false then
                  fx_ll_hq.print("CaptureVariousValuesOfLastTouchedFxParameter(row) == false\n")
                else
                  fx_ll_hq.print("CaptureVariousValuesOfLastTouchedFxParameter(row) == true\n")
                  fx_ll_hq.print("paramnumber == " .. tostring(paramnumber) .. "\n")
                  fx_ll_hq.SetAttributeByRowAndColumnToCsvTable(fx_ll_hq.csvUserDatabase, row, fx_ll_hq.par_idx_IDX, paramnumber)
                  fx_ll_hq.SetAttributeByRowAndColumnToCsvTable(fx_ll_hq.csvUserDatabase, row, fx_ll_hq.GetPositionOfElementInIterativeTable(fx_ll_hq.database_fomat_table, "Low Latency Value"), minval)
                  fx_ll_hq.SetAttributeByRowAndColumnToCsvTable(fx_ll_hq.csvUserDatabase, row, fx_ll_hq.GetPositionOfElementInIterativeTable(fx_ll_hq.database_fomat_table, "High Quality Value"), maxval)
                  fx_ll_hq.SetAttributeByRowAndColumnToCsvTable(fx_ll_hq.csvUserDatabase, row, fx_ll_hq.GetPositionOfElementInIterativeTable(fx_ll_hq.database_fomat_table, "Default Low Latency Value"), minval)
                  fx_ll_hq.SetAttributeByRowAndColumnToCsvTable(fx_ll_hq.csvUserDatabase, row, fx_ll_hq.GetPositionOfElementInIterativeTable(fx_ll_hq.database_fomat_table, "Default High Quality Value"), maxval)
                  fx_ll_hq.SetAttributeByRowAndColumnToCsvTable(fx_ll_hq.csvUserDatabase, row, fx_ll_hq.GetPositionOfElementInIterativeTable(fx_ll_hq.database_fomat_table, "Active"), true)
                end
              end

              if ImGui.IsItemHovered(ctx) then
                ImGui.SetTooltip(ctx, fx_ll_hq.ReturnObservedStringLastTouchedParameter())
              end
              
              --id_tab = fx_ll_hq.par_idx_IDX - 1
              --ImGui.TableSetColumnIndex(ctx, id_tab)
              --fx_ll_hq.print("row == " .. row .. " " .. "id_tab == " .. id_tab .. "\n")
              --fx_ll_hq.print("fx_ll_hq.GetAttributeByRowAndColumnFromCsvTable(fx_ll_hq.csvUserDatabase, row == " ..  row .. ", id_tab == " .. id_tab .. ") == " .. fx_ll_hq.GetAttributeByRowAndColumnFromCsvTable(fx_ll_hq.csvUserDatabase, row, id_tab) .. "\n")
              -- fx_ll_hq.print("row == " .. row .. " " .. "fx_ll_hq.par_idx_IDX == " .. fx_ll_hq.par_idx_IDX .. "\n")
              ImGui.SameLine(ctx)
              rv,value = ImGui.InputInt(ctx, '##int_' .. row .. "_" .. fx_ll_hq.par_idx_IDX, fx_ll_hq.GetAttributeByRowAndColumnFromCsvTable(fx_ll_hq.csvUserDatabase, row, fx_ll_hq.par_idx_IDX), 1,0)
              if rv then
                fx_ll_hq.SetAttributeByRowAndColumnToCsvTable(fx_ll_hq.csvUserDatabase, row, fx_ll_hq.par_idx_IDX, value)
                modify_changes_counter()
              end

              --- Low Latency Value --- 
              -- column_tab = fx_ll_hq.GetPositionOfElementInIterativeTable(fx_ll_hq.database_fomat_table, "Low Latency Value")
              -- id_tab = fx_ll_hq.ll_val_IDX - 1
              -- ImGui.TableSetColumnIndex(ctx, id_tab)
              ImGui.TableNextColumn(ctx)
              ImGui.PushItemWidth(ctx, -FLT_MIN) -- Right-aligned
              if ImGui.SmallButton(ctx, 'Capture##' .. row .. "_" .. fx_ll_hq.ll_val_IDX)  then
                fx_ll_hq.print("Capture Low Latency Value row " .. row .. " fx_ll_hq.ll_val_IDX " .. fx_ll_hq.ll_val_IDX .. "\n")
                local ret_capture, value_capture = fx_ll_hq.CaptureVariousValuesOfLastTouchedFxParameter(row)
                if ret_capture == false then
                  fx_ll_hq.print("CaptureVariousValuesOfLastTouchedFxParameter(row) == false\n")
                else
                  fx_ll_hq.print("CaptureVariousValuesOfLastTouchedFxParameter(row) == true\n")
                  fx_ll_hq.print("value == " .. tostring(value_capture) .. "\n")
                  fx_ll_hq.SetAttributeByRowAndColumnToCsvTable(fx_ll_hq.csvUserDatabase, row, fx_ll_hq.ll_val_IDX, value_capture)
                end
              end
    
              if ImGui.IsItemHovered(ctx) then
                ImGui.SetTooltip(ctx, fx_ll_hq.ReturnObservedStringLastTouchedParameter())
              end
    
              ImGui.SameLine(ctx)
              if default_value_trigger_tab[row .. "_" .. fx_ll_hq.ll_val_IDX] == true then
                fx_ll_hq.SetAttributeByRowAndColumnToCsvTable(fx_ll_hq.csvUserDatabase, row, fx_ll_hq.ll_val_IDX, fx_ll_hq.GetAttributeByRowAndColumnFromCsvTable(fx_ll_hq.csvUserDatabase, row,  fx_ll_hq.default_ll_val_IDX))
                COUNTER = COUNTER + 1;
              end
              --rv, value = ImGui.SliderDouble(ctx, '##double_' .. row .. "_" .. fx_ll_hq.ll_val_IDX, fx_ll_hq.GetAttributeByRowAndColumnFromCsvTable(fx_ll_hq.csvUserDatabase, row, fx_ll_hq.ll_val_IDX), fx_ll_hq.GetAttributeByRowAndColumnFromCsvTable(fx_ll_hq.csvUserDatabase, row, fx_ll_hq.ll_val_IDX), fx_ll_hq.GetAttributeByRowAndColumnFromCsvTable(fx_ll_hq.csvUserDatabase, row, fx_ll_hq.ll_val_IDX)+1)
              rv, value = ImGui.DragDouble(ctx, '##double_' .. row .. "_" .. fx_ll_hq.ll_val_IDX,  fx_ll_hq.GetAttributeByRowAndColumnFromCsvTable(fx_ll_hq.csvUserDatabase, row, fx_ll_hq.ll_val_IDX), 0.1)
              
              if rv then
                fx_ll_hq.SetAttributeByRowAndColumnToCsvTable(fx_ll_hq.csvUserDatabase, row, fx_ll_hq.ll_val_IDX, value)
              end
              -- if default_value_trigger_tab[row .. "_" .. fx_ll_hq.ll_val_IDX] == true and COUNTER > 3 then
              --   default_value_trigger_tab[row .. "_" .. fx_ll_hq.ll_val_IDX] = nil
              --   COUNTER = 0
              -- end
    
              if r.ImGui_IsItemHovered(ctx) and r.ImGui_IsMouseClicked(ctx,0) and (r.ImGui_IsKeyDown(ctx, r.ImGui_Key_LeftAlt()) or r.ImGui_IsKeyDown(ctx, r.ImGui_Key_RightAlt())) then
                --default_value_trigger_tab[row .. "_" .. fx_ll_hq.ll_val_IDX] = true
                fx_ll_hq.SetAttributeByRowAndColumnToCsvTable(fx_ll_hq.csvUserDatabase, row, fx_ll_hq.ll_val_IDX, fx_ll_hq.GetAttributeByRowAndColumnFromCsvTable(fx_ll_hq.csvUserDatabase, row, fx_ll_hq.default_ll_val_IDX))
              end
              if rv then
                modify_changes_counter()
              end

              --- High Quality Value --- 
              ImGui.TableNextColumn(ctx)
              ImGui.PushItemWidth(ctx, -FLT_MIN) -- Right-aligned
              --id_tab = fx_ll_hq.hq_val_IDX - 1
              -- ImGui.TableSetColumnIndex(ctx, id_tab)
    
              
              if ImGui.SmallButton(ctx, 'Capture##' .. row .. "_" .. fx_ll_hq.hq_val_IDX)  then
                fx_ll_hq.print("Capture High Quality Value row " .. row .. " fx_ll_hq.hq_val_IDX " .. fx_ll_hq.hq_val_IDX .. "\n")
                local ret_capture, value_capture = fx_ll_hq.CaptureVariousValuesOfLastTouchedFxParameter(row)
                if ret_capture == false then
                  fx_ll_hq.print("CaptureVariousValuesOfLastTouchedFxParameter(row) == false\n")
                else
                  fx_ll_hq.print("CaptureVariousValuesOfLastTouchedFxParameter(row) == true\n")
                  fx_ll_hq.print("value == " .. tostring(value_capture) .. "\n")
                  fx_ll_hq.SetAttributeByRowAndColumnToCsvTable(fx_ll_hq.csvUserDatabase, row, fx_ll_hq.hq_val_IDX, value_capture)
                end
              end
    
              if ImGui.IsItemHovered(ctx) then
    
                ImGui.SetTooltip(ctx, fx_ll_hq.ReturnObservedStringLastTouchedParameter())
              end
    
              ImGui.SameLine(ctx)
              -- if default_value_trigger_tab[row .. "_" .. id_tab] == true then
              --   fx_ll_hq.SetAttributeByRowAndColumnToCsvTable(fx_ll_hq.csvUserDatabase, row, id_tab, fx_ll_hq.GetAttributeByRowAndColumnFromCsvTable(fx_ll_hq.csvUserDatabase, row,  fx_ll_hq.GetPositionOfElementInIterativeTable(fx_ll_hq.database_fomat_table, "Default High Quality Value")))
              --   COUNTER = COUNTER + 1;
              -- end
              -- rv, value = ImGui.SliderDouble(ctx, '##double_' .. row .. "_" .. id_tab, fx_ll_hq.GetAttributeByRowAndColumnFromCsvTable(fx_ll_hq.csvUserDatabase, row, id_tab), fx_ll_hq.GetAttributeByRowAndColumnFromCsvTable(fx_ll_hq.csvUserDatabase, row, id_tab), fx_ll_hq.GetAttributeByRowAndColumnFromCsvTable(fx_ll_hq.csvUserDatabase, row, id_tab)-1)
              rv, value = ImGui.DragDouble(ctx, '##double_' .. row .. "_" .. fx_ll_hq.hq_val_IDX,  fx_ll_hq.GetAttributeByRowAndColumnFromCsvTable(fx_ll_hq.csvUserDatabase, row, fx_ll_hq.hq_val_IDX), 0.1)
              if rv then
                fx_ll_hq.SetAttributeByRowAndColumnToCsvTable(fx_ll_hq.csvUserDatabase, row, fx_ll_hq.hq_val_IDX, value)
              end
              -- if default_value_trigger_tab[row .. "_" .. id_tab] == true and COUNTER > 3 then
              --   default_value_trigger_tab[row .. "_" .. id_tab] = nil
              --   COUNTER = 0
              -- end
              if r.ImGui_IsItemHovered(ctx) and r.ImGui_IsMouseClicked(ctx,0) and (r.ImGui_IsKeyDown(ctx, r.ImGui_Key_LeftAlt()) or r.ImGui_IsKeyDown(ctx, r.ImGui_Key_RightAlt())) then
                --default_value_trigger_tab[row .. "_" .. id_tab] = true
                fx_ll_hq.SetAttributeByRowAndColumnToCsvTable(fx_ll_hq.csvUserDatabase, row, fx_ll_hq.hq_val_IDX, fx_ll_hq.GetAttributeByRowAndColumnFromCsvTable(fx_ll_hq.csvUserDatabase, row,  fx_ll_hq.default_hq_val_IDX))
    
              end
              if rv then
                modify_changes_counter()
              end


              --- Flag Active ---

              ImGui.TableNextColumn(ctx)
              ImGui.PushItemWidth(ctx, -FLT_MIN) -- Right-aligned
              --id_tab = fx_ll_hq.GetPositionOfElementInIterativeTable(fx_ll_hq.fx_database_table_header_row, "Flag Active") - 1
              -- ImGui.TableSetColumnIndex(ctx, id_tab)
              rv, value = ImGui.Checkbox(ctx, '##checkboxActive' .. row .. "_" .. fx_ll_hq.active_IDX, fx_ll_hq.GetAttributeByRowAndColumnFromCsvTable(fx_ll_hq.csvUserDatabase, row, fx_ll_hq.active_IDX))
              if rv then
                fx_ll_hq.SetAttributeByRowAndColumnToCsvTable(fx_ll_hq.csvUserDatabase, row, fx_ll_hq.active_IDX, value)
              end
              if rv then
                modify_changes_counter()
              end

    
              --- Remove row ---
              ImGui.TableNextColumn(ctx)
              ImGui.PushItemWidth(ctx, -FLT_MIN) -- Right-aligned
              -- ImGui.TableSetColumnIndex(ctx, id_tab)
              if r.ImGui_Button(ctx, "X##" .. row) then
                --tables.buffers.remove_row_buf[row] = true
                -- fx_ll_hq.SetAttributeByRowAndColumnToCsvTable(fx_ll_hq.csvUserDatabase, row, column_tab, true)
                -- -- fx_ll_hq.UpdateRowsNumbersCsvTableDatabase()
                -- fx_ll_hq.print("remove row " .. row .. "\n")
    
                -- local count_removed_rows = fx_ll_hq.ReturnNumberOfRowsInCsvTable(fx_ll_hq.csvUserDatabase)

                -- -- for _,_ in pairs(removed_rows_tab) do
                -- --   count_removed_rows = count_removed_rows + 1
                -- -- end
                -- fx_ll_hq.print("New rows count without removed rows == " .. rows_count - count_removed_rows .. "\n")

                rows_count = fx_ll_hq.RemoveRowFromCsvTable(fx_ll_hq.csvUserDatabase, row)
                fx_ll_hq.UpdateRowsNumbersCsvTableDatabase(fx_ll_hq.csvUserDatabase)
                fx_ll_hq.print("New rows count == " .. rows_count .. "\n")
                modify_changes_counter()
                ImGui.PopID(ctx)
                break
              end
    
              ImGui.PopID(ctx)
              ::continue_table_next_row::
            end
          --end
          ImGui.EndTable(ctx)
        end
        --ImGui.TreePop(ctx)
      -- end


      -- DoOpenAction()
      -- --if ImGui.TreeNode(ctx, 'Padding') then
      --   if not tables.padding then
      --     tables.padding = {
      --       flags1 = ImGui.TableFlags_BordersV(),
      --       show_headers = false,
    
      --       flags2 = ImGui.TableFlags_Borders() | ImGui.TableFlags_RowBg(),
      --       cell_padding = { 0.0, 0.0 },
      --       show_widget_frame_bg = true,
      --       text_bufs = {}, -- Mini text storage for 3x5 cells
      --     }
    
      --     for i = 1, 3*5 do
      --       tables.padding.text_bufs[i] = 'edit me'
      --     end
      --   end
    
        -- Second example: set style.CellPadding to (0.0) or a custom value.
        -- FIXME-TABLE: Vertical border effectively not displayed the same way as horizontal one...
        -- HelpMarker('Setting style.CellPadding to (0,0) or a custom value.')
    
        -- demo.PushStyleCompact()
        -- rv,tables.padding.flags2 = ImGui.CheckboxFlags(ctx, 'ImGuiTableFlags_Borders', tables.padding.flags2, ImGui.TableFlags_Borders())
        -- rv,tables.padding.flags2 = ImGui.CheckboxFlags(ctx, 'ImGuiTableFlags_BordersH', tables.padding.flags2, ImGui.TableFlags_BordersH())
        -- rv,tables.padding.flags2 = ImGui.CheckboxFlags(ctx, 'ImGuiTableFlags_BordersV', tables.padding.flags2, ImGui.TableFlags_BordersV())
        -- rv,tables.padding.flags2 = ImGui.CheckboxFlags(ctx, 'ImGuiTableFlags_BordersInner', tables.padding.flags2, ImGui.TableFlags_BordersInner())
        -- rv,tables.padding.flags2 = ImGui.CheckboxFlags(ctx, 'ImGuiTableFlags_BordersOuter', tables.padding.flags2, ImGui.TableFlags_BordersOuter())
        -- rv,tables.padding.flags2 = ImGui.CheckboxFlags(ctx, 'ImGuiTableFlags_RowBg', tables.padding.flags2, ImGui.TableFlags_RowBg())
        -- rv,tables.padding.flags2 = ImGui.CheckboxFlags(ctx, 'ImGuiTableFlags_Resizable', tables.padding.flags2, ImGui.TableFlags_Resizable())
        -- rv,tables.padding.show_widget_frame_bg = ImGui.Checkbox(ctx, 'show_widget_frame_bg', tables.padding.show_widget_frame_bg)
        -- rv,tables.padding.cell_padding[1],tables.padding.cell_padding[2] =
        --   ImGui.SliderDouble2(ctx, 'CellPadding', tables.padding.cell_padding[1],
        --   tables.padding.cell_padding[2], 0.0, 10.0, '%.0f')
        -- demo.PopStyleCompact()
    
        -- ImGui.PushStyleVar(ctx, ImGui.StyleVar_CellPadding(), table.unpack(tables.padding.cell_padding))
        -- if ImGui.BeginTable(ctx, 'table_padding_2', 3, tables.padding.flags2) then
        --   if not tables.padding.show_widget_frame_bg then
        --     ImGui.PushStyleColor(ctx, ImGui.Col_FrameBg(), 0)
        --   end
        --   for cell = 1, 3 * 5 do
        --     ImGui.TableNextColumn(ctx)
        --     ImGui.SetNextItemWidth(ctx, -FLT_MIN)
        --     ImGui.PushID(ctx, cell)
        --     rv,tables.padding.text_bufs[cell] = ImGui.InputText(ctx, '##cell', tables.padding.text_bufs[cell])
        --     ImGui.PopID(ctx)
        --   end
        --   if not tables.padding.show_widget_frame_bg then
        --     ImGui.PopStyleColor(ctx)
        --   end
        --   ImGui.EndTable(ctx)
        -- end
        -- ImGui.PopStyleVar(ctx)
    
        --ImGui.TreePop(ctx)
      --end


      --ImGui.TreePop(ctx)
      --end
      
      -- ImGui.Text(ctx, 'ABOUT THIS DEMO:')
      -- ImGui.BulletText(ctx, 'Sections below are demonstrating many aspects of the library.')
      -- ImGui.BulletText(ctx, 'The "Examples" menu above leads to more demo contents.')
      -- ImGui.BulletText(ctx, 'The "Tools" menu above gives access to: About Box, Style Editor,\n' .. 'and Metrics/Debugger (general purpose Dear ImGui debugging tool).')
      -- for row = 1, rows_count+1 do
      --   fx_ll_hq.SetAttributeByRowAndColumnToCsvTable(fx_ll_hq.csvUserDatabase, row, 1, tables.buffers.input_inputText_buf[row-1])
      --   fx_ll_hq.SetAttributeByRowAndColumnToCsvTable(fx_ll_hq.csvUserDatabase, row, 2, tables.buffers.par_idx_buf[row-1])
      --   fx_ll_hq.SetAttributeByRowAndColumnToCsvTable(fx_ll_hq.csvUserDatabase, row, 3, tables.buffers.ll_val_buf[row-1])
      --   fx_ll_hq.SetAttributeByRowAndColumnToCsvTable(fx_ll_hq.csvUserDatabase, row, 4, tables.buffers.hq_val_buf[row-1])
      -- end
      -- fx_ll_hq.WriteCsvFile(fx_ll_hq.csvUserDatabase, fx_ll_hq.file_path_user_database)
    end
  else
    if tables.collapsible_headers.user_database_configurator_header_open ~= 0 then
      tables.collapsible_headers.user_database_configurator_header_open = 0
    end
  end

end

local ret_window = false
local function loop()
  reaper.ImGui_PushFont(ctx, sans_serif)
  reaper.ImGui_SetNextWindowSize(ctx, 400, 80, reaper.ImGui_Cond_FirstUseEver())
  local visible, open = reaper.ImGui_Begin(ctx, 'Hipox - FX LL HQ - Settings', true, window_flags)
  if visible then
    if myWindow() then
      open = false
    end
    reaper.ImGui_End(ctx)
  end
  reaper.ImGui_PopFont(ctx)
  
  if open then
    reaper.defer(loop)
  end
end

local function ModalWindowExitExample()
  if not popups.modal then
    popups.modal = {
      dont_ask_me_next_time = false,
      item  = 1,
      color = 0x66b30080,
    }
  end

  ImGui.TextWrapped(ctx, 'Modal windows are like popups but the user cannot close them by clicking outside.')

  if ImGui.Button(ctx, 'Delete..') then
    ImGui.OpenPopup(ctx, 'Delete?')
  end

  -- Always center this window when appearing
  local center = {ImGui.Viewport_GetCenter(ImGui.GetWindowViewport(ctx))}
  ImGui.SetNextWindowPos(ctx, center[1], center[2], ImGui.Cond_Appearing(), 0.5, 0.5)

  if ImGui.BeginPopupModal(ctx, 'Delete?', nil, ImGui.WindowFlags_AlwaysAutoResize()) then
    ImGui.Text(ctx, 'All those beautiful files will be deleted.\nThis operation cannot be undone!')
    ImGui.Separator(ctx)

    --static int unused_i = 0;
    --ImGui.Combo("Combo", &unused_i, "Delete\0Delete harder\0");

    ImGui.PushStyleVar(ctx, ImGui.StyleVar_FramePadding(), 0, 0)
    rv,popups.modal.dont_ask_me_next_time =
      ImGui.Checkbox(ctx, "Don't ask me next time", popups.modal.dont_ask_me_next_time)
    ImGui.PopStyleVar(ctx)

    if ImGui.Button(ctx, 'OK', 120, 0) then ImGui.CloseCurrentPopup(ctx) end
    ImGui.SetItemDefaultFocus(ctx)
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, 'Cancel', 120, 0) then ImGui.CloseCurrentPopup(ctx) end
    ImGui.EndPopup(ctx)
  end
end

reaper.defer(loop)

reaper.atexit(exit)
