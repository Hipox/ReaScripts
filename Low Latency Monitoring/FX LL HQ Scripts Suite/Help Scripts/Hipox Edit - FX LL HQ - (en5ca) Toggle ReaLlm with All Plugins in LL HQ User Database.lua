local reaper = reaper
local reallmID = reaper.NamedCommandLookup("_AK5K_REALLM")
if reallmID == 0 then return end
local state = reaper.GetToggleCommandState(reallmID)

local path = ({reaper.get_action_context()})[2]:match('^.+[\\//]')
package.path = path .. "?.lua"
local fx_ll_hq = require("Hipox - FX LL HQ - Functions")

fx_ll_hq.SetReaLlm_FX_LL_HQ_FromUserDatabase()

-- reaper.Llm_Set("PARAMCHANGE","VST:SoundID Reference Plugin (Sonarworks),7,0.0,1.0")
-- reaper.Llm_Set("PARAMCHANGE","VST: ReaLimit (Cockos),1,0.0,1.0")

fx_ll_hq.SetReaLlm_MONITORINGFX(state)
--reaper.Llm_Set("MONITORINGFX","yes")

reaper.Main_OnCommand(reallmID, 0)

local _, _, sectionID, cmdID = reaper.get_action_context()
reaper.SetToggleCommandState(sectionID, cmdID, ((state < 1) and 1 or 0))
reaper.RefreshToolbar2(sectionID, cmdID);