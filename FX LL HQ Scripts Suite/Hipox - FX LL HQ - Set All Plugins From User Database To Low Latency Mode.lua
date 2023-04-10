-- @description Hipox - FX LL HQ - Set All Plugins From User Database To Low Latency Mode.lua
-- @author Hipox
-- @version 1.0
-- @about
-- @noindex

local path = ({reaper.get_action_context()})[2]:match('^.+[\\//]')
package.path = path .. "?.lua"

local set_ll_mode = true

local function get_script_path()
    local info = debug.getinfo(1,'S');
    local script_path = info.source:match[[^@?(.*[\/])[^\/]-$]]
    return script_path
end

loadfile(get_script_path() .. "Hipox - FX LL HQ - Set All Plugins From User Database CODE.lua")({set_ll_mode = set_ll_mode})