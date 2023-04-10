local path = ({reaper.get_action_context()})[2]:match('^.+[\\//]')
package.path = path .. "?.lua"
local fx_ll_hq = require("Hipox - FX LL HQ - Functions")

--TODO ask user if he/she wants to make a copy of actual database file and set it as new user database file 

fx_ll_hq.SetupUserDatabaseFromReferenceDatabaseWithExistingPluginsOnly(true)
fx_ll_hq.OpenContainingFolderInExplorerPrompt()
