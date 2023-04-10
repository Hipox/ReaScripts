-- @description Hipox - FX LL HQ - Set All Plugins From User Database CODE.lua
-- @author Hipox
-- @version 1.0
-- @about
-- @noindex Hipox - FX LL HQ - Set All Plugins From User Database CODE

local arg={...}
local reaper = reaper
local reallmID = reaper.NamedCommandLookup("_AK5K_REALLM")
if reallmID == 0 then return end
local reallm_state = reaper.GetToggleCommandState(reallmID)

local path = ({reaper.get_action_context()})[2]:match('^.+[\\//]')
package.path = path .. "?.lua"
local fx_ll_hq = require("Hipox - FX LL HQ - Functions")


local set_ll_mode = arg[1].set_ll_mode --true -- true = set to low latency, false = set to high quality
fx_ll_hq.print("set_ll_mode: " .. tostring(set_ll_mode) .. "\n")
fx_ll_hq.print("here\n")
local flag_re_enable_rallm = false

local process_takes = fx_ll_hq.global_mode_switch_ProcessTakeFXs
local process_tracks = fx_ll_hq.global_mode_switch_ProcessTrackFXs
local process_input_fx = fx_ll_hq.global_mode_switch_ProcessInputFx

local function HandleReaLlmStatePrompt()
    if reallm_state == 1 then
        local retval = reaper.ShowMessageBox("ReaLlm is enabled. Do you want to disable it while this script work, then re-enable it? Safe option!", "Disable ReaLlm?", 4)
        if retval == 6 then
            flag_re_enable_rallm = true
            reaper.Main_OnCommand(reallmID, 0)
        end
    end
end

local function ToggleFXState(fx_identifier, par_id, ll_val, hq_val) -- todo link with params
    local par_id_is_number = fx_ll_hq.IsNumber(par_id)
    if par_id_is_number then
        --fx_ll_hq.print("par_id is a number\n")
    else
        --fx_ll_hq.print("par_id is not a number !!!! Modify string par_id somehow???\n")
    end

    local value_to_set
    if set_ll_mode then
        value_to_set = ll_val
    else
        value_to_set = hq_val
    end

    -- get the number of tracks in the project
    local trackCount = reaper.CountTracks(0)


    -- loop through all tracks
    for i = 0, trackCount - 1 do
    -- get the track
    local track = reaper.GetTrack(0, i)

    if process_tracks then
        -- switch all track FXs
            -- get the number of FX on the track
            local trackFxCount = reaper.TrackFX_GetCount(track)

            -- loop through all FX on the track
            for j = 0, trackFxCount - 1 do
                -- get the FX
                local _,fxName = reaper.TrackFX_GetFXName(track, j, "")
                --string_identifier = "ReaLimit"
                --fx_ll_hq.print("Found FX == " .. fxName .. " and string_identifier == " .. string_identifier .. "and fxName:match(string_identifier) == " .. tostring(fxName:find(string_identifier, 1, true)) .. "\n")
                -- check if the FX is FabFilter Pro-Q3

                -- if fxName:find(string_identifier, 1, true) then
                -- if paramName:find(par_id, 1, true) then
                fx_ll_hq.print("Found FX == " .. fxName .. " and fx_identifier == " .. fx_identifier .. "and fxName:match(fx_identifier) == " .. tostring(fxName:find(fx_identifier, 1, true)) .. "\n")
                if fxName:find(fx_identifier, 1, true) then
                    --fx_ll_hq.print("Matching FX found on track " .. i .. " FX " .. j .. "\n")
                    --if not par_id_is_number then
                        ----fx_ll_hq.print("Found q3 on track " .. i .. " FX " .. j .. '\n')
                        --reaper.TrackFX_SetParam(track, j, q3_par_id, 1)
                        --reaper.TrackFX_CountParams(track, j)
                    --     local paramName
                    --     for k = 0, reaper.TrackFX_GetNumParams(track, j) - 1 do
                    --         _,paramName =  reaper.TrackFX_GetParamName(track, j, k)
                    --         if paramName:find(par_id, 1, true) then
                    --             if value_to_set == nil then
                    --                 local retval, minval, maxval = reaper.TrackFX_GetParam(track, j, k)
                    --                 if retval > minval then
                    --                     value_to_set = minval
                    --                 else
                    --                     value_to_set = maxval
                    --                 end
                    --             end
                    --             ----fx_ll_hq.print("Found param " .. paramName .. " on track " .. i .. " FX " .. j .. " param " .. k .. '\n')
                    --             reaper.TrackFX_SetParam(track, j, k, value_to_set)
                    --         end
                    --     end
                    -- else
                        reaper.TrackFX_SetParam(track, j, par_id, value_to_set)
                    --end
                end
            end
        -- end of switching all track FXs
    end

    if process_input_fx then
        local trackInputFxCount = reaper.TrackFX_GetRecCount(track)

        for j = 0, trackInputFxCount-1 do
            jj = j+16777216
            local _,fxName = reaper.TrackFX_GetFXName(track, jj, "")
            fx_ll_hq.print("Found FX == " .. fxName .. " and fx_identifier == " .. fx_identifier .. "and fxName:match(fx_identifier) == " .. tostring(fxName:find(fx_identifier, 1, true)) .. "\n")
            if fxName:find(fx_identifier, 1, true) then
                reaper.TrackFX_SetParam(track, jj, par_id, value_to_set)
            end
        end
    end


    if process_takes then
        --switch all take FXs
        -- get the number of items on the track
            local itemCount = reaper.CountTrackMediaItems(track)

            -- loop through all items on the track
            for j = 0, itemCount - 1 do
                -- get the item
                local item = reaper.GetTrackMediaItem(track, j)

                -- get the number of takes on the item
                local takeCount = reaper.CountTakes(item)

                -- loop through all takes on the item
                for k = 0, takeCount - 1 do
                    -- get the take
                    local take = reaper.GetMediaItemTake(item, k)

                    -- get the number of FX on the take
                    local fxCount = reaper.TakeFX_GetCount(take)

                    -- loop through all FX on the take
                    for l = 0, fxCount - 1 do
                        -- get the FX
                        local _,fxName = reaper.TakeFX_GetFXName(take, l)

                        -- check if the FX is FabFilter Pro-Q3
                        local paramName
                        if fxName:find(fx_identifier, 1, true) then
                            --fx_ll_hq.print("Matching FX found on track " .. i .. " take " .. tostring(take) .. " FX " .. j .. "\n")
                            -- if not par_id_is_number then
                            --     for m = 0, reaper.TakeFX_GetNumParams(take, l) - 1 do
                            --         _,paramName =  reaper.TakeFX_GetParamName(take, l, m)
                            --         if paramName:find(par_id, 1, true) then
                            --             if value_to_set == nil then
                            --                 local retval, minval, maxval = reaper.TakeFX_GetParam(take, l, m)
                            --                 if retval > minval then
                            --                     value_to_set = minval
                            --                 else
                            --                     value_to_set = maxval
                            --                 end
                            --             end
                            --             ----fx_ll_hq.print("Found param " .. paramName .. " on track " .. i .. "take " .. tostring(take) .. " FX " .. j .. " param " .. k .. '\n')
                            --             reaper.TakeFX_SetParam(take, l, m, value_to_set)
                            --         end
                            --     end
                            -- else
                                reaper.TakeFX_SetParam(take, l, par_id, value_to_set)
                            --end
                        end
                    end
                end
            end
        -- end of switching all take FXs
        end
    end
end

local function set_fx_ll_hq()
    
    local format_fx_name_developer_format
    local fx_identifier, fx_name, developer, format, par_id, ll_val, hq_val
    if fx_ll_hq.file_exists_file_path(fx_ll_hq.file_path_user_database) == false then
        local retval = reaper.ShowMessageBox("User database file named " .. fx_ll_hq.file_name_user_database .. " does not exist.\nDo you want to create it now?", "Create new user database file?", 4)
        if retval == 6 then
            fx_ll_hq.SetupUserDatabaseFromReferenceDatabaseWithExistingPluginsOnly(true)
            fx_ll_hq.OpenContainingFolderInExplorerPrompt()
        else
            return
        end
    end
    local cnt_rows_user_database = fx_ll_hq.ReturnCountRowsInFile(fx_ll_hq.file_path_user_database)
    local string_identifier, transformed_string_identifier, flag_active
    for i = 1, cnt_rows_user_database do
        _, fx_identifier, par_id, ll_val, hq_val, _, _, flag_active = fx_ll_hq.GetValuesFromCsvTableLineFxDatabase(fx_ll_hq.csvUserDatabase,i)
        if fx_identifier == nil or flag_active == false then
            --fx_ll_hq.print("ERROR: On line " .. i .. " of user database file " .. fx_ll_hq.file_name_user_database .. " the fx_name is nil (probably one of the parameters is).\n")
            goto continue
        end
        --fx_ll_hq.print("Check table values: " .. fx_name .. ' ' .. developer  .. ' ' .. format .. ' ' .. par_id .. ' ' .. ll_val .. ' ' .. hq_val .. '\n')
        --format_fx_name_developer_format = format .. ": " .. fx_name .. ' (' .. developer .. ')'
         --fx_ll_hq.print(format_fx_name_developer_format .. '\n')
         --string_identifier = format_fx_name_developer_format
        ToggleFXState(fx_identifier, par_id, ll_val, hq_val)
        ::continue::
    end
end

-- todo make suite of plugins to set various parameters of reallm

HandleReaLlmStatePrompt()

set_fx_ll_hq()

if flag_re_enable_rallm == true then
    reaper.Main_OnCommand(reallmID, 0)
end

