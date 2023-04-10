local fx_ll_hq_dev = {}

local reaper = reaper
local path = ({reaper.get_action_context()})[2]:match('^.+[\\//]')
package.path = path .. "?.lua"
local csv = require("Simple-CSV")
local fx_ll_hq = require("FX LL HQ - Functions")

--[[
   Save Table to File
   Load Table from File
   v 1.0\
   
   Lua 5.2 compatible
   
   Only Saves Tables, Numbers and Strings
   Insides Table References are saved
   Does not save Userdata, Metatables, Functions and indices of these
   ----------------------------------------------------
   table.save( table , filename )
   
   on failure: returns an error msg
   
   ----------------------------------------------------
   table.load( filename or stringtable )
   
   Loads a table that has been saved via the table.save function
   
   on success: returns a previously saved table
   on failure: returns as second argument an error msg
   ----------------------------------------------------
   
   Licensed under the same terms as Lua itself.
]]--
--do
    -- declare local variables
    --// exportstring( string )
    --// returns a "Lua" portable version of the string
    local function exportstring( s )
       return string.format("%q", s)
    end
 
    --// The Save Function
    function table.save(  tbl,filename )
       local charS,charE = "   ","\n"
       local file,err = io.open( filename, "wb" )
       if err then return err end
       if file == nil then return end
 
       -- initiate variables for save procedure
       local tables,lookup = { tbl },{ [tbl] = 1 }
       file:write( "return {"..charE )
 
       for idx,t in ipairs( tables ) do
          file:write( "-- Table: {"..idx.."}"..charE )
          file:write( "{"..charE )
          local thandled = {}
 
          for i,v in ipairs( t ) do
             thandled[i] = true
             local stype = type( v )
             -- only handle value
             if stype == "table" then
                if not lookup[v] then
                   table.insert( tables, v )
                   lookup[v] = #tables
                end
                file:write( charS.."{"..lookup[v].."},"..charE )
             elseif stype == "string" then
                file:write(  charS..exportstring( v )..","..charE )
             elseif stype == "number" then
                file:write(  charS..tostring( v )..","..charE )
             end
          end
 
          for i,v in pairs( t ) do
             -- escape handled values
             if (not thandled[i]) then
             
                local str = ""
                local stype = type( i )
                -- handle index
                if stype == "table" then
                   if not lookup[i] then
                      table.insert( tables,i )
                      lookup[i] = #tables
                   end
                   str = charS.."[{"..lookup[i].."}]="
                elseif stype == "string" then
                   str = charS.."["..exportstring( i ).."]="
                elseif stype == "number" then
                   str = charS.."["..tostring( i ).."]="
                end
             
                if str ~= "" then
                   stype = type( v )
                   -- handle value
                   if stype == "table" then
                      if not lookup[v] then
                         table.insert( tables,v )
                         lookup[v] = #tables
                      end
                      file:write( str.."{"..lookup[v].."},"..charE )
                   elseif stype == "string" then
                      file:write( str..exportstring( v )..","..charE )
                   elseif stype == "number" then
                      file:write( str..tostring( v )..","..charE )
                   end
                end
             end
          end
          file:write( "},"..charE )
       end
       file:write( "}" )
       file:close()
    end
    
    --// The Load Function
    function table.load( sfile )
       local ftables,err = loadfile( sfile )
       if err then return _,err end
       local tables = ftables()
       for idx = 1,#tables do
          local tolinki = {}
          for i,v in pairs( tables[idx] ) do
             if type( v ) == "table" then
                tables[idx][i] = tables[v[1]]
             end
             if type( i ) == "table" and tables[i[1]] then
                table.insert( tolinki,{ i,tables[i[1]] } )
             end
          end
          -- link indices
          for _,v in ipairs( tolinki ) do
             tables[idx][v[2]],tables[idx][v[1]] =  tables[idx][v[1]],nil
          end
       end
       return tables[1]
    end
 -- close do
--end
 
 -- ChillCode

function fx_ll_hq.TransformToRegexString(str)
   local ret = "^" .. str:gsub("%(", "%%(")
   ret = ret:gsub("%)", "%%)")
   ret = ret:gsub("%.", "%%.")
   ret = ret:gsub("%+", "%%+")
   ret = ret:gsub("%-", "%%-")
   ret = ret:gsub("%*", "%%*")
   ret = ret:gsub("%?", "%%?")
   ret = ret:gsub("%[", "%%[")
   ret = ret:gsub("%]", "%%]")
   --ret = ret:gsub("%^", "%%^")
   ret = ret:gsub("%$", "%%$")
   ret = ret:gsub("%|", "%%|")
   ret = ret:gsub("%\\", "%%\\")
   ret = ret:gsub(" ", "[ ]")
   ret = ret:gsub(":", "[:]")

   return ret
end

function fx_ll_hq.ManualChangeGlobalUserDatabaseName()
   local retval, retvals_name = reaper.GetUserInputs("Change global user database name", 1, "Enter new name for global user database (with extension):", "")
   if retval then
      fx_ll_hq.global_user_database_name = retvals_name
      --fx_ll_hq.SaveGlobalUserDatabase()
   end
   return retval
end

function fx_ll_hq.ChangeGlobalUserDatabaseNameWithPrompt(name)
   local ret = reaper.ShowMessageBox("Do you want to change the global user database name to " .. name .. "?", "Change global user database name?", 1)
   if ret == 2 then
      return false
   end
   
   return true
end

-- TODO create a function that checks if fx_summary_all_present_path matches the current fx list and if not, update it
-- TODO create a function that checks online for the latest version of the official database and if not present, download it and put into fxs_toggle_ll_hq_official_database_list_path
-- TODO create a function that generates fx_toggle_ll_hq_user_database_path from matches in fx_summary_all_present_path and fxs_toggle_ll_hq_official_database_list_path

----------------------------------------
fx_ll_hq.fxs_toggle_ll_hq_official_table = {
   {
      fx_name = "ReaComp",
      developer = "Cockos",
      format = "VST",
      par_id = 0,
      ll_val = 0,
      hq_val = 1
   },
   {
      fx_name = "ReaLimit",
      developer = "Cockos",
      format = "VST",
      par_id = 1,
      ll_val = 0,
      hq_val = 1
   },
   {
      --"VST3: SoundID Reference Plugin (Sonarworks) (16ch);7;0.0;1.0")
      fx_name = "SoundID Reference Plugin",
      developer = "Sonarworks",
      format = "VST3",
      par_id = 1,
      ll_val = 0,
      hq_val = 1
   },

}
-------------------------------------------------------------------------


-- function fx_ll_hq.create_fxs_toggle_ll_hq_official_database_file()
--    table.save(fx_ll_hq.fxs_toggle_ll_hq_official_table, fx_ll_hq.file_path_user_database) -- save "fxs_toggle_ll_hq_official_table" table to file
-- end

-- function fx_ll_hq.create_fx_toggle_ll_hq_user_database_file_from_table()
--    table.save(fx_toggle_ll_hq_user_table, fx_ll_hq.file_path_user_database) -- save "USER_FX_IDENTIFIER_TAB" table to file
-- end

-- function fx_ll_hq.load_fxs_toggle_ll_hq_official_database_to_table_from_file()
--    return  table.load(fx_ll_hq.file_path_community_database) -- load the whole "presets" table
-- end

-- function fx_ll_hq.load_fxs_toggle_ll_hq_user_database_to_table_from_file()
--    return table.load(fx_ll_hq.file_path_user_database) -- load the whole "presets" table
-- end

function fx_ll_hq.LoadTabFromCsvFile(file_name)
   --local file_name = 'FX LL HQ List  - List 1.csv'
   local file_path = fx_ll_hq.GetPathToFileSameDirectoryAsScript(file_name)
   --fx_ll_hq.print("file_path == " .. file_path .. '\n')
   table = fx_ll_hq.LoadDatabaseFromCsvFileToTable(file_path)
   if table == nil then
      --fx_ll_hq.print('table == nil\n')
      return
   else
      --fx_ll_hq.print('table ~= nil\n')
      --fx_ll_hq.printXfTableInConsole(table, file_name)
      return table
   end
end

-- EXECUTE SECTION --



--setup_fx_toggle_ll_hq_user_database()
--load_fxs_toggle_ll_hq_user_database_to_table_from_file()

-- fx_toggle_ll_hq_user_table = load_fxs_toggle_ll_hq_user_database_to_table_from_file()

-- print("control printout after load\n")
-- PrintXfTableInConsole(fx_toggle_ll_hq_user_table, 'fx_toggle_ll_hq_user_table')

-- END OF EXECUTE SECTION --



return fx_ll_hq_dev