-- TODO from last touched parameter get all relevant information and copy it in the right format (csv) on clipboard
-- Maybe even append to User Database automatically or with message 

-- Inspired by scripts:
-- Edgemeal: Display last touched FX parameter
-- MPL: Set last touched parameter value (via deductive brutforce)
-- Edgemeal: Toggle last touched take FX envelope


local reaper = reaper
local path = ({reaper.get_action_context()})[2]:match('^.+[\\//]')
package.path = path .. "?.lua"
local fx_ll_hq = require("Hipox - FX LL HQ - Functions")

  -------------------------------------------------------
 local function main() local ReaperVal

    local retval, tracknumber, itemnumber, fxnumber = reaper.GetFocusedFX2()
    if not retval then return end
    --fx_ll_hq.print("retval == " .. tostring(retval) .. "\n")
    local retval_param, minval, maxval
    local fx_identifier, param_name, paramnumber
    _,_,_,paramnumber = reaper.GetLastTouchedFX()
    local title_string = 'Last Touched: '
    if retval == 1 then
        --fx_ll_hq.print("FX is Track FX\n")
        local track = reaper.CSurf_TrackFromID(tracknumber, false)
        
        retval_param, minval, maxval = reaper.TrackFX_GetParam(track, fxnumber, paramnumber)
        _, fx_identifier = reaper.TrackFX_GetFXName(track, fxnumber, "")
        _, param_name = reaper.TrackFX_GetParamName(track, fxnumber, paramnumber, "")
        title_string = title_string .. param_name
    elseif retval == 2 then
        --fx_ll_hq.print("FX is Take FX\n")

        if not reaper.APIExists('BR_EnvAlloc') then
            reaper.MB('SWS extension is required for this script!', 'Missing API', 0)
            return
        end
        
        local retval, tracknumber, fxnumber, paramnumber = reaper.GetLastTouchedFX()
        if retval then 
                if (tracknumber >> 16) ~= 0 then -- Item FX
                local show = false
                local track = reaper.CSurf_TrackFromID((tracknumber & 0xFFFF), false)
                local takenumber = (fxnumber >> 16)
                fxnumber = (fxnumber & 0xFFFF)
                local item_index = (tracknumber >> 16)-1
                local item = reaper.GetTrackMediaItem(track, item_index)
                local take = reaper.GetTake(item, takenumber)
                _, param_name = reaper.TakeFX_GetParamName(take, fxnumber, paramnumber, "")
                _, fx_identifier = reaper.TakeFX_GetFXName(take, fxnumber, "")
                title_string = title_string .. param_name
                retval_param, minval, maxval = reaper.TakeFX_GetParam(take, fxnumber, paramnumber)
            end
        end
    elseif retval ~= 4 then
        reaper.ShowMessageBox('Please, touch a desired parameter and try again\n', 'Error', 0)
        return
    end
    if minval == nil or maxval == nil then
        reaper.ShowMessageBox('Please, touch a desired parameter and try again\n', 'Error', 0)
        return
    end
    --fx_ll_hq.print("tracknumber == " .. tostring(tracknumber) .. " itemnumber == " .. tostring(itemnumber) .. " fxnumber == " .. tostring(fxnumber) .. "\n")
    --fx_ll_hq.print("retval_param == " .. tostring(retval_param) .. " minval == " .. tostring(minval) .. " maxval == " .. tostring(maxval) .. "\n")

    local retval, retval_csv = reaper.GetUserInputs(title_string, 2, 'Low Latency Value, High Quality Value', minval .. ',' .. maxval)
    if not retval then return end

    local set_minval, set_maxval = retval_csv:match('([^,]+),([^,]+)')
    --fx_ll_hq.print("set_minval == " .. tostring(set_minval) .. " set_maxval == " .. tostring(set_maxval) .. "\n")
    --fx_ll_hq.print("fx_name == " .. tostring(fx_name) .. " param_name == " .. tostring(param_name) .. "\n")

    -- format matches all characters before the first : , FX Identifier,FX name is after whitespace and until (, developer is after ( and until )
    local format, fx_name_read, developer = fx_identifier:match('([^:]+):%s([^%(]+)%s%(([^%)]+)')

    --fx_ll_hq.print("format == " .. tostring(format) .. " fx_name_read == " .. tostring(fx_name_read) .. " developer == " .. tostring(developer) .. "\n")


    local content = fx_ll_hq.GetFileContextString(fx_ll_hq.file_path_user_database)
    local new_line = fx_identifier .. fx_ll_hq.separator_csv .. paramnumber .. fx_ll_hq.separator_csv .. set_minval .. fx_ll_hq.separator_csv   .. set_maxval
    fx_ll_hq.SaveStringToCsvFile(content .. new_line, fx_ll_hq.file_path_user_database)
end

main()  