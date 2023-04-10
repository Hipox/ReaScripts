--creator's github: https://gist.github.com/obikag/6118422#file-simple-csv-lua
local reaper = reaper
--Initialise
SimpleCSV = {}
SimpleCSV.__index = SimpleCSV

local separator = ";"
local emptyString = "_emptyString_"
local ctx

function Lead_Trim_ws(s) return s:match '^%s*(.*)' end
function FormatString(s) return s:format('%q') end

--Create new object
function SimpleCSV.new()
  local self = setmetatable({},SimpleCSV)
	self.csv_table = {}
	return self
end

function SimpleCSV:GetSelfCsvTable()
	return self.csv_table
end

function SimpleCSV:IsSelfCsvTableEmpty()
	return self.csv_table == {}
end

function SimpleCSV:ClearSelfCsvTable()
	self.csv_table = {}
end

function SimpleCSV:SetSelfCsvTable(csv_table)
	self.csv_table = csv_table
end

function IsNumber(value)
	return tonumber(value) and true or false
 end

function IsBoolean(value)
	return type(value) == "boolean" and true or false
end

function ConvertToStorageFormat(value)
	if IsNumber(value) then
		return tostring(value)
	elseif IsBoolean(value) then
		return value and "true" or "false"
	elseif value == "" then
		return emptyString
	elseif type(value) == "string" then
		return value
	elseif value == nil then
		print("ERROR value is nil while converting to storage format")
		return nil
	else
		print("ERROR value is not a number, boolean or string while converting to storage format")
		return nil
	end
end

function ConvertFromStorageFormat(value)
	print("value == " .. tostring(value) .. " type == " .. type(value))
	if IsNumber(value) then
		return tonumber(value)
	elseif type(value) == "string" then
		if value == "true" or value == "false" then
			return value == "true" and true or false
		elseif value == emptyString then
			return ""
		else
			return value
		end
	elseif value == nil then
		print("ERROR value is nil while converting from storage format")
		return nil
	else
		print("ERROR value is not a number, boolean or string while converting from storage format")
		return nil
	end
end

local function print(content)
    reaper.ShowConsoleMsg(tostring(content) .. "\n")
end

local function print_tab(tab, row_elements)
    for i = 1, #tab do
        reaper.ShowConsoleMsg(tab[i] .. "\t")
        if i % row_elements == 0 then
            reaper.ShowConsoleMsg("\n")
        end
    end
end

--[[
Load CSV File into multidimensional table.
parmeter: filepath is the location of the csv file
returns: True is file exists and has been loaded
]]
function SimpleCSV:load_csvfile(filepath)
    print("load: " .. filepath .. "\n")
	local file = io.open(filepath,"r")
	if file then
		for line in file:lines() do
			if line == "" then goto continue end
			local temp = {}
			for item in string.gmatch(line,"[^;]*") do --does not work for strings containing ','
				if item ~= "" then
					item = item:gsub(';',"")
					item = item:gsub("^%s*(.-)%s*$", "%1") -- remove trailing white spaces
					ConvertFromStorageFormat(item)
					table.insert(temp,item)
				end
			end
			table.insert(self.csv_table, temp)
			::continue::
		end
	else
		--print("Cannot open file: "..filepath)
		io.close(file)
		return false
	end
	io.close(file)
	return true
end

function SimpleCSV:load_overwrite_csvfile(filepath)
    --print("load: " .. filepath)
	self.csv_table = {}
	local file = io.open(filepath,"r")
	if file then
		for line in file:lines() do
			if line == "" then goto continue end
			local temp = {}
			for item in string.gmatch(line,"[^;]*") do --does not work for strings containing ','
				if item ~= "" then
					item = item:gsub(';',"")
					item = item:gsub("^%s*(.-)%s*$", "%1") -- remove trailing white spaces
					table.insert(temp,ConvertFromStorageFormat(item))
				end
			end
			table.insert(self.csv_table, temp)
			::continue::
		end
	else
		--print("Cannot open file: "..filepath)
		io.close(file)
		return false
	end
	io.close(file)
	return true
end

--[[
Display csv file loaded into table
returns: None
]]
function SimpleCSV:display_csvfile()
	if next(self.csv_table) ~= nil then
		for rowCount = 1, #self.csv_table do
			print_tab({table.unpack(self.csv_table[rowCount])}, 4)
            --local a , b = table.unpack(self.csv_table[rowCount])
            --print(a .. " " .. b)
		end
	else
		--print("(1) No CSV Table found!!")
	end
end

--[[
Write to a CSV File from the multidimensional table.
parmeter: filepath is the location of the csv file
returns: None
]]
function SimpleCSV:write_csvfile(filepath)
	--print("here\n")
	local outfile = io.open(filepath,"w")
	if outfile then
		if next(self.csv_table) ~= nil then
			for rowCount = 1, #self.csv_table do
				local row = self.csv_table[rowCount]
				if row[1] == nil then
					print("Row " .. rowCount .. " is empty")
					goto continue
				end
				for i,item in pairs(row) do
					item = ConvertToStorageFormat(item)
					if i ~= #row then
						outfile:write(item..';')
					else
						outfile:write(item.."\n")
					end
				end
				::continue::
			end
		else
			print("(SimpleCSV:write_csvfile) CSV Table is empty or not found. Setting file to empty.")
			SimpleCSV:erase_content_csvfile(filepath)
		end
	else
		--print("Cannot write to file: "..filepath)
	end
	io.close(outfile)
end

--[[
Displays the attribute in a particular row and column of the table
parameter: row is the row number in the table
parameter: column is the column number in the table
returns: string value of the attribute
]]
function SimpleCSV:get_attribute(row, column)
	--print("get_attribute: " .. row .. " " .. column)
	if next(self.csv_table) ~= nil then
		if row > #self.csv_table or row < 0 then
			print("(6) Row " .. row .. " is outside of allowed range")
		else
			local row_attr = self.csv_table[row]
			if column > #row_attr or column < 0 then
				print("(7) Column " .. column .. " is outside of allowed range on row " .. row .. "\n")
			else
				return ConvertFromStorageFormat(row_attr[column])
			end
		end
	else
		print("(3) No CSV Table found!!")
		--return nil
	end
	return "No Attribute found"
end

--[[
Changes a specific attribute in table to a given value
parameter: row is the row number in the table
parameter: column is the column number in the table
parameter: value is the attribute to be set
returns: True if value was sucessfully changed
]]
function SimpleCSV:set_attribute(row,column,value)
	-- print("set_attribute: " .. tostring(row) .. " " .. tostring(column) .. " " .. tostring(value))
	if value == nil or value == "" then value = emptyString end
	if next(self.csv_table) ~= nil then
		if row > #self.csv_table or row < 0 then
			--print("Row is outside of allowed range")
		else
			local row_attr = self.csv_table[row]
			if column > #row_attr or column < 0 then
				--print("Column is outside of allowed range")
			else
				row_attr[column] = ConvertToStorageFormat(value)
				return true
			end
		end
	else
		print("(4) No CSV Table found!!")
	end
	return false
end

--[[
Searches the table and gives the location of the first instance of a user-defined attribute
parameter: attr is the attribute given by the user
returns: the row and column of the defined attribute if found
]]
function SimpleCSV:find_attribute(attr)
	if next(self.csv_table) ~= nil then
		local rowIndex = 1
		repeat
			local columns = self.csv_table[rowIndex]
			for columnIndex,item in pairs(columns) do
				if string.lower(attr) == string.lower(item) then
					return "Attribute \""..attr.."\" found in row "..rowIndex..", column "..columnIndex
				end
			end
			rowIndex = rowIndex + 1
		until rowIndex > #self.csv_table
		return "Attribute: \""..attr.."\" not found"
	else
		--print("(5) No CSV Table found!!")
	end
end


--[[
Searches the table and gives the row and column indexes of the first instance of a user-defined attribute
parameter: attr is the attribute given by the user
returns: the row and column indexes as a table
]]
function SimpleCSV:get_location(attr)
	if next(self.csv_table) ~= nil then
		local rowIndex = 1
		repeat
			local columns = self.csv_table[rowIndex]
			for columnIndex,item in pairs(columns) do
                --print("attr = "..attr..", item = "..item.."\n")
				if string.lower(attr) == string.lower(item) then
					return {["row"]=rowIndex,["col"]=columnIndex}
				end
			end
			rowIndex = rowIndex + 1
		until rowIndex > #self.csv_table
		print("Location Not Found: " .. tostring(attr) ..  "\n")
		return {["row"]=0,["col"]=0}
	else
		--print("(6) No CSV Table found!!")
	end
end

function SimpleCSV:get_location_in_first_column(attr)
	if next(self.csv_table) ~= nil then
		local rowIndex = 1
		repeat
			local columns = self.csv_table[rowIndex]
			for columnIndex,item in pairs(columns) do
				if columnIndex == 1 then
					--print("attr = "..attr..", item = "..item.."\n")
					if string.lower(attr) == string.lower(item) then
						return {["row"]=rowIndex,["col"]=columnIndex}
					end
				end
			end
			rowIndex = rowIndex + 1
		until rowIndex > #self.csv_table
		print("Location Not Found: " .. tostring(attr) ..  "\n")
		return {["row"]=0,["col"]=0}
	else
		--print("(6) No CSV Table found!!")
	end
end

function SimpleCSV:exchange_rows(row1, row2)
	if next(self.csv_table) ~= nil then
		if row1 > #self.csv_table or row1 < 0 then
			print("(4) Row " .. row1 .. " is outside of allowed range")
		elseif row2 > #self.csv_table or row2 < 0 then
			print("(5) Row " .. row2 .. " is outside of allowed range")
		else
			local row1_attr = self.csv_table[row1]
			local row2_attr = self.csv_table[row2]
			local temp = {}
			for i=1,#row1_attr do
				temp[i] = row1_attr[i]
			end
			for i=1,#row2_attr do
				row1_attr[i] = row2_attr[i]
			end
			for i=1,#temp do
				row2_attr[i] = temp[i]
			end
		end
	else
		print("(4) No CSV Table found!!")
	end
end

--table.insert(t, new, table.remove(t,old))

function SimpleCSV:move_row(row, new_row)
	if next(self.csv_table) ~= nil then
		if row > #self.csv_table or row < 0 then
			print("(3) Row " .. row .. " is outside of allowed range")
		elseif new_row > #self.csv_table or new_row < 0 then
			print("(2) Row " .. new_row .. " is outside of allowed range")
		else
			local row_attr = self.csv_table[row]
			table.insert(self.csv_table, new_row, table.remove(self.csv_table,row))
		end
	else
		print("(4) No CSV Table found!!")
	end
end

--[[
Searches the table and gives the row and column indexes of all instances of a user-defined attribute
parameter: attr is the attribute given by the user
returns: the row and column indexes as a multidimensional table
]]
function SimpleCSV:get_locations(attr)
	if next(self.csv_table) ~= nil then
		local rowIndex = 1
		local pos = {}
		repeat
			local columns = self.csv_table[rowIndex]
			for columnIndex,item in pairs(columns) do
				if string.lower(attr) == string.lower(item) then
					table.insert(pos,{["row"]=rowIndex,["col"]=columnIndex})
				end
			end
			rowIndex = rowIndex + 1
		until rowIndex > #self.csv_table
		return pos
	else
		--print("(7) No CSV Table found!!")
	end
end


--[[
Adds a row to the end of the table
parameter: elements is the row to be added.
returns: true if row was sucessfully added to table
]]
-- function SimpleCSV:add_row(elements, flag_first_row)
--     for i = 1, #elements do
--         print("elements["..i.."] = "..tostring(elements[i]).."\n")
-- 		-- if elements[i] == nil or elements[i] == "" then elements[i] = emptyString end
-- 		elements[i] = ConvertToStorageFormat(elements[i])
--     end
-- 	if next(self.csv_table) ~= nil then
-- 		--print("here\n")
-- 		local firstRow = self.csv_table[1]
-- 		if not flag_first_row and #elements == #firstRow then
-- 			--table.insert(self.csv_table,elements)
--             ----print("elements[1] = "..elements[1].."\n")
--             table.insert(self.csv_table,elements)
--             for i = 1, #elements do
--                 --self.csv_table[row][i] = "aha"
--                 --table.insert(self.csv_table,elements[i])

--             end
-- 			return true
-- 		elseif flag_first_row then
-- 			--table.insert(self.csv_table,elements)
-- 			table.insert(self.csv_table,elements)
-- 			return true
-- 		else
-- 			--print("Number of columns do not match")
-- 		end
-- 	else
-- 		print("(SimpleCSV:add_row) Table is empty. Inserting first row\n")
-- 		table.insert(self.csv_table,elements)
-- 	end
-- 	return false
-- end

function SimpleCSV:add_row(elements)
	table.insert(self.csv_table,elements)
end

function SimpleCSV:add_empty_row()
	table.insert(self.csv_table,{#self.csv_table + 1 ,"",0,0,1,true,true,0,1})
end

function SimpleCSV:ReturnNumberOfElementsInRowCsvTable(row_number)
	local cnt = 0
	if next(self.csv_table) ~= nil then
		for i = 1, #self.csv_table[row_number] do
			if self.csv_table[row_number][i] ~= nil then
				cnt = cnt + 1
			end
		end
	end
	return cnt
 end

 function SimpleCSV:RemoveRowFromCsvTable(row)
	for i = #self.csv_table, 1, -1  do
		if row > #self.csv_table or row < 0 then
			print("(1) Row " .. row .. " is outside of allowed range")
		else
			if i == row then
				table.remove(self.csv_table, i)
			end
			-- table.remove(self.csv_table, row)
			-- self.csv_table[row] = nil
		end
	end
 end
	

 --- Returns the number of items in the csv table including 
 function SimpleCSV:ReturnNumberOfRowsInCsvTable()
	--print("#self.csv_table = "..tostring(#self.csv_table).."\n")
	return #self.csv_table
 end
 
 function SimpleCSV:ReturnLineFromCsvTableAsString(row_number)
	local line = ""
	if next(self.csv_table) ~= nil then
		for i = 1, #self.csv_table[row_number] do
			if self.csv_table[row_number][i] ~= nil then
				line = line .. tostring(self.csv_table[row_number][i])
				if i ~= #self.csv_table[row_number] then
					line = line .. ';'
				end
			end
		end
	end
	return line
 end

 function SimpleCSV:SetAllValuesInRowToNil(row_number)
	if next(self.csv_table) ~= nil then
		for i = 1, #self.csv_table[row_number] do
			if self.csv_table[row_number][i] ~= nil  then
				self.csv_table[row_number][i] = nil
			else
				print("self.csv_table["..row_number.."]["..i.."] = nil\n")
			end
		end
	end
	--print("#self.csv_table = "..#self.csv_table.."\n")
 end

 function SimpleCSV:erase_content_csvfile(filepath)
	local outfile = io.open(filepath,"w")
	if outfile then
		outfile:write("")
			--print("(2) No CSV Table found!!")
	else
		print("Cannot write to file: "..filepath)
	end
	io.close(outfile)
end


-- local MyItemColumnID_ID          = 4
-- local MyItemColumnID_FxIdentifier        = 5
-- local MyItemColumnID_ParameterIndex    = 6
-- local MyItemColumnID_LowLatencyValue = 7
-- local MyItemColumnID_HighQualityValue = 7

--  function CompareTableItems(ctx, a, b)
-- 	local next_id = 0
-- 	while true do
-- 		local ok, col_user_id, col_idx, sort_order, sort_direction = reaper.ImGui_TableGetColumnSortSpecs(ctx, next_id)
-- 		if not ok then break end
-- 		next_id = next_id + 1
	
-- 		-- Here we identify columns using the ColumnUserID value that we ourselves passed to TableSetupColumn()
-- 		-- We could also choose to identify columns based on their index (col_idx), which is simpler!
-- 		--  local key
-- 		--  if col_user_id == MyItemColumnID_ID then
-- 		--    key = 'id'
-- 		--  elseif col_user_id == MyItemColumnID_Name then
-- 		--    key = 'name'
-- 		--  elseif col_user_id == MyItemColumnID_Quantity then
-- 		--    key = 'quantity'
-- 		--  elseif col_user_id == MyItemColumnID_Description then
-- 		--    key = 'name'
-- 		--  else
-- 		--    error('unknown user column ID')
-- 		--  end
	
-- 		--  local is_ascending = sort_direction == reaper.ImGui_SortDirection_Ascending()
-- 		--  if a[key] < b[key] then
-- 		--    return is_ascending
-- 		--  elseif a[key] > b[key] then
-- 		--    return not is_ascending
-- 		--  end
-- 		local is_ascending = sort_direction == reaper.ImGui_SortDirection_Ascending()
-- 		if a[col_idx] < b[col_idx] then
-- 			return is_ascending
-- 		elseif a[col_idx] > b[col_idx] then
-- 			return not is_ascending
-- 		end
-- 	end
-- 	-- table.sort is instable so always return a way to differenciate items.
-- 	-- Your own compare function may want to avoid fallback on implicit sort specs e.g. a Name compare if it wasn't already part of the sort specs.
-- 	return a.id < b.id
--  end


-- function SimpleCSV:SortCsvTable(column_number) --???
-- 	if next(self.csv_table) ~= nil then
-- 		local firstRow = self.csv_table[1]
-- 		if #firstRow >= column_number then
-- 			table.sort(self.csv_table, function(a,b) return a[column_number] < b[column_number] end)
-- 		else
-- 			print("Column number is out of range")
-- 		end
-- 	else
-- 		--print("(8) No CSV Table found!!")
-- 	end
-- end

local function CompareTableItems(a, b)
    local next_id = 0
    while true do
      local ok, col_user_id, col_idx, sort_order, sort_direction = reaper.ImGui_TableGetColumnSortSpecs(ctx, next_id)
      if not ok then break end
      next_id = next_id + 1

      local is_ascending = sort_direction == reaper.ImGui_SortDirection_Ascending()
	
	--   print("a[col_idx+1] == "..a[col_idx+1].."\n")
	--   print("b[col_idx+1] == "..b[col_idx+1].."\n")
	  local element_a = ConvertFromStorageFormat(a[col_idx+1])
	  local element_b = ConvertFromStorageFormat(b[col_idx+1])
      if element_a < element_b then
        return is_ascending
      elseif element_a > element_b then
        return not is_ascending
      end
    end
    -- table.sort is instable so always return a way to differenciate items.
    -- Your own compare function may want to avoid fallback on implicit sort specs e.g. a Name compare if it wasn't already part of the sort specs.
	print("a[1] == "..a[1].."\n")
	print("b[1] == "..b[1].."\n")
    return a[1] < b[1]
  end

--  function SimpleCSV:SortCsvTable(ctx_rec) --???
-- 	ctx = ctx_rec
-- 	local next_id = 0
-- 	if next(self.csv_table) ~= nil then
-- 		local ok, col_user_id, col_idx, sort_order, sort_direction = reaper.ImGui_TableGetColumnSortSpecs(ctx, next_id)
-- 		--table.sort(self.csv_table, function(a,b) return a[col_idx+1] < b[col_idx+1] end)
-- 		-- local firstRow = self.csv_table[1]
-- 		-- if #firstRow >= column_number then
			
-- 		-- else
-- 		-- 	print("Column number is out of range")
-- 		-- end
-- 	else
-- 		--print("(8) No CSV Table found!!")
-- 	end
-- end


function SimpleCSV:SortCsvTable(ctx_rec)
	ctx = ctx_rec
	-- local table = self.csv_table
	table.sort(self.csv_table, CompareTableItems)
	-- self.csv_table = table
	ctx = nil
end

function SimpleCSV:UpdateRowsNumbersCsvTableDatabase()
	local table_to_sort = {}
	for i = 1, #self.csv_table do
		table.insert(table_to_sort,{row = i, num = tonumber(self.csv_table[i][1])})
	end
	print("#table_to_sort == "..#table_to_sort.."\n")
	-- sort table_to_sort by num
	table.sort(table_to_sort, function(a,b) return a.num < b.num end)

	for i = 1, #table_to_sort do
		if tonumber(table_to_sort[i].num) ~= i then
			print("Number of row ".. table_to_sort[i].row .." == " .. table_to_sort[i].num .. " is not equal to "..i.."\n")
			self.csv_table[tonumber(table_to_sort[i].row)][1] = i
		end
		-- print("i == "..i.."\n")
		-- print("table_to_sort[i].row == "..table_to_sort[i].row.."\n")
		-- print("table_to_sort[i].num == "..table_to_sort[i].num.."\n")
		
		-- --self.csv_table[tonumber(table_to_sort[i].row)][1] = i
		-- print("self.csv_table[" .. table_to_sort[i].row .. "][1] == " .. self.csv_table[table_to_sort[i].row][1] .. "\n")
	end

end

function SimpleCSV:MakeRowsSequencePermament_ReNumberRows() -- MAKE PERMANENT ROWS ORDER
	-- local table_to_sort = {}
	for i = 1, #self.csv_table do
		print("i == "..i.."\n")
		-- table.insert(table_to_sort,{row = i, num = self.csv_table[i][1]})
		self.csv_table[i][1] = i
	end
	-- print("#table_to_sort == "..#table_to_sort.."\n")
	-- -- sort table_to_sort by num
	-- table.sort(table_to_sort, function(a,b) return a.num < b.num end)
	-- for i = 1, #table_to_sort do
	-- 	print("i == "..i.."\n")
	-- 	print("table_to_sort[i].row == "..table_to_sort[i].row.."\n")
	-- 	print("table_to_sort[i].num == "..table_to_sort[i].num.."\n")
	-- 	self.csv_table[i][1] = i
	-- end

end

function SimpleCSV:ReturnLineFromCsvTableAsTable(row_number)
	if next(self.csv_table) ~= nil then
		if self.csv_table[row_number] ~= nil then
			return self.csv_table[row_number]
		else
			print("Row number is out of range")
		end
	end
 end


-- --[[
-- **********Test section**********

-- CSV file: test.csv

-- 1, Tom, 34, Man, Electrician
-- 2, Dan, 34, Man, Business Man
-- 3, Stan, 34, Man, Programmer
-- 4, Douglas, 34, Man, Shop Owner
-- 5, Sarah, 34, Woman, Beautician
-- 6, Joan, 34, Woman, Business Woman
-- 7, Jenny, 34, Woman, Fashion Designer
-- 8, Suzie, 34, Woman, Engineer

-- ]]

-- --Start
-- csv = SimpleCSV.new() --Create object
-- csv:load_csvfile("test.csv") --Load File (true)
-- csv:display_csvfile()
-- --[[

-- Output:

-- 1	Tom	34	Man	Electrician
-- 2	Dan	34	Man	Business Man
-- 3	Stan	34	Man	Programmer
-- 4	Douglas	34	Man	Shop Owner
-- 5	Sarah	34	Woman	Beautician
-- 6	Joan	34	Woman	Business Woman
-- 7	Jenny	34	Woman	Fashion Designer
-- 8	Suzie	34	Woman	Engineer

-- ]]

-- --print(csv:get_attribute(1,2)) --Tom

-- --print(csv:get_attribute(2,2)) --Dan
-- csv:set_attribute(2,2,"John")
-- --print(csv:get_attribute(2,2)) --John

-- --print(csv:find_attribute("Man")) --Attribute "Man" found in row 1, column 4

-- loc1 = csv:get_location("Man")
-- --print("row = "..loc1.row.." , col = "..loc1.col) --row = 1 , col = 4

-- loc2 = csv:get_locations("Man")
-- for i,v in pairs(loc2) do
-- 	--print("row => "..v.row.." , col => "..v.col)
-- end
-- --[[

-- Output:

-- row => 1 , col => 4
-- row => 1 , col => 4
-- row => 2 , col => 4
-- row => 3 , col => 4
-- row => 4 , col => 4

-- ]]

-- newrow = {9,"Carol",44,"Woman","IT Professional"}
-- csv:add_row(newrow)
-- csv:display_csvfile()

-- --[[

-- Output:

-- 1	Tom	34	Man	Electrician
-- 2	John	34	Man	Business Man
-- 3	Stan	34	Man	Programmer
-- 4	Douglas	34	Man	Shop Owner
-- 5	Sarah	34	Woman	Beautician
-- 6	Joan	34	Woman	Business Woman
-- 7	Jenny	34	Woman	Fashion Designer
-- 8	Suzie	34	Woman	Engineer
-- 9	Carol	44	Woman	IT Professional

-- ]]


return SimpleCSV