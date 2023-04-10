-- local path = ({reaper.get_action_context()})[2]:match('^.+[\\//]')
-- package.path = path .. "?.lua"
-- local fx_ll_hq = require("Hipox - FX LL HQ - Functions")


-- function CoreFunctionsLoaded(script)
-- 	local sep = (reaper.GetOS() == "Win64" or reaper.GetOS() == "Win32") and "\\" or "/"
-- 	local root_path = debug.getinfo(1, 'S').source:sub(2, -5):match("(.*" .. sep .. ")")
-- 	local script_path = root_path .. ".." .. sep .. "Core" .. sep .. script
-- 	local file = io.open(script_path, 'r')

-- 	if file then file:close() dofile(script_path) else return nil end
-- 	return not not _G["EK_HasExtState"]
-- end

-- local loaded = CoreFunctionsLoaded("ek_Core functions.lua")
-- if not loaded then
-- 	if loaded == nil then reaper.MB('Core functions is missing. Please install "ek_Core functions" it via ReaPack (Action: Browse packages)', '', 0) end
-- 	return
-- end

-- if not CoreFunctionsLoaded("ek_Core functions startup.lua") then
-- 	reaper.MB('Global startup action is missing. Please install "ek_Global startup action" it via ReaPack (Action: Browse packages)', '', 0)
-- 	return
-- end

-- if not reaper.APIExists("ImGui_WindowFlags_NoCollapse") then
--     reaper.MB('Please install "ReaImGui: ReaScript binding for Dear ImGui" via ReaPack', '', 0)
-- 	return
-- end





--fx_ll_hq.OpenSystemFileOpenDialogue_ReturnFilePath()
-- --fx_ll_hq.print(tostring(fx_ll_hq.ReturnNumberOfElementsInRowCsvTable(fx_ll_hq.csvGlobalVariables, 1)) .. "\n")
----fx_ll_hq.print(tostring(fx_ll_hq.ReturnLineFromCsvTableAsString(fx_ll_hq.csvGlobalVariables, 1)) .. "\n")

-- fx_ll_hq.IsDatabaseTableValid(fx_ll_hq.csvUserDatabase)
--local buf = reaper.Llm_Get("P_PDCLATENCY",buf, reaper.GetMasterTrack(0))
local strbuf
reaper.ShowConsoleMsg("hello\n")
--reaper.Llm_Set("PDCLIMIT", 2)
local ret = reaper.Llm_Get("PDCLATENCY", strbuf)
reaper.ShowConsoleMsg("ret: " .. tostring(ret) .. "\n")