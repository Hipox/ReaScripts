-- @description Simple-SET.lua
-- @author Hipox
-- @version 1.0
-- @about
-- @noindex

-- https://riptutorial.com/lua/example/19065/using-a-table-as-a-set
SimpleSET = {}

function SimpleSET.initialize_set(elements_table)
 local set = {} -- empty set
-- --create set
--  local set = {pear=true, plum=true}

--  -- or initialize by adding the value of a variable:
--  local fruit = 'orange'
--  local other_set = {[fruit] = true} -- adds 'orange'
  for _, element in ipairs(elements_table) do
      set[element] = true
  end
  return set
end
 
function SimpleSET. add_member_to_set(set, element)
-- --add more 
--   set.peach = true
--   set.apple = true
  -- alternatively
  -- set['banana'] = true
  -- set['strawberry'] = true
  set[element] = true
end

function SimpleSET.remove_member_from_set(set, element)
--remove
  set[element] = nil
end

function SimpleSET.verify_member_in_set(set, element)
--verify
  if set[element] then
      reaper.ShowConsoleMsg("Set contains member " .. element .. "\n")
      return true
  else
      reaper.ShowConsoleMsg("Set does not contain member " .. element .. "\n")
      return false
  end
end


function SimpleSET.iterate_over_set(set)
-- iterate
 for element in pairs(set) do
     reaper.ShowConsoleMsg(element .. "\n")
 end
end

return
