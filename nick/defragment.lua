--[[

defragment.lua

More efficiently makes use of AE2 storage disks
with the help of 2 AE2 storage subsystems.

One network has greater capacity for item types
and is comprised of large inventories and storage buses
(the bus network) while the other specializes in holding
larger stacks of items (the disk network)

Written by Nick V.

--]]

local component = require('component')
local sides = require('sides')

-- USER CONSTANTS
local DISK_SUBSYSTEM_ID = '354c1d9d-b851-46ae-9baf-3c99010e1ba4'
local DISK_EXPORTER_ID  = '788db016-d98b-42e0-a9fb-56a2fe94afba'
local BUS_SUBSYSTEM_ID  = '83f6b1a5-12cc-47a9-84db-279319208f6f'
local BUS_EXPORTER_ID   = 'c1e77971-04e1-4015-89ee-5c3eafda1271'

local DISK_EXPORTER_SIDE = sides.right
local BUS_EXPORTER_SIDE  = sides.left
-- END USER CONSTANTS

local db = component.database
local disk_subsystem = component.proxy(DISK_SUBSYSTEM_ID)
local bus_subsystem  = component.proxy(BUS_SUBSYSTEM_ID)
disk_subsystem["exporter"] = component.proxy(DISK_EXPORTER_ID)
bus_subsystem["exporter"]  = component.proxy(BUS_EXPORTER_ID)
disk_subsystem['exporter_side'] = DISK_EXPORTER_SIDE
bus_subsystem['exporter_side']  = BUS_EXPORTER_SIDE

local function filter(pred, intable)
  local result = {};
  for _, item in ipairs(intable) do
    if pred(item) then
      table.insert(result, item)
    end
  end
  return result;
end

local function dump(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. dump(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end

local function transfer(fromProxy, toProxy, itemStack)
  local itemFilter = {name=itemStack.name, label=itemStack.label}
  db.clear(1)
  local priorQuantity = fromProxy.getItemsInNetwork(itemFilter).n
  fromProxy.exporter.setExportConfiguration(fromProxy.exporter_side, 1, db.address, 1)  
  local success = fromProxy.store(itemFilter, db.address, 1, 1)
  if not success then return success end
  success = fromProxy.exporter.setExportConfiguration(fromProxy.exporter_side, 1, db.address, 1)
  if not success then return success end
  success = fromProxy.getItemsInNetwork(itemFilter).n == 0
  local retries = 10
  local retry = 1
  while (not success and retry < retries) do
    os.sleep(1)
    retry = retry + 1
    success = fromProxy.getItemsInNetwork(itemFilter).n == 0
  end
  if (not success and retry == retries) then
    local currentQuantity = fromProxy.getItemsInNetwork(itemFilter).n
    if (priorQuantity - currentQuantity == 1) then
      print("Circumventing filter logic...")
      success = transfer(fromProxy, toProxy, itemStack)
    end
  end
  db.clear(1)
  fromProxy.exporter.setExportConfiguration(fromProxy.exporter_side, 1, db.address, 1)
  return success
end


while true do
  local m_items = disk_subsystem.getItemsInNetwork()
  if (m_items ~= nil) then
    local smallStacks = filter(function(stack) return stack.size <= stack.maxSize end, m_items)
    for _, itemStack in ipairs(smallStacks) do
      print("Moving " .. itemStack.size .. " " .. itemStack.label .. " to bus network.")
      local success = transfer(disk_subsystem, bus_subsystem, itemStack)
      if not success then print("Failed item transfer.") end
    end
  end
  local s_items = bus_subsystem.getItemsInNetwork()
  if (s_items ~= nil) then
    local largeStacks = filter(function(stack) return stack.size > stack.maxSize end, s_items)
    for _, itemStack in ipairs(largeStacks) do
      print("Moving " .. itemStack.size .. " " .. itemStack.label .. " to disk network.")
      local success = transfer(bus_subsystem, disk_subsystem, itemStack)
      if not success then print("Failed item transfer.") end
    end
  end
  s_items = bus_subsystem.getItemsInNetwork()
  if (s_items ~= nil) then
    for _, itemStack in ipairs(s_items) do
      local itemFilter = {name=itemStack.name, label=itemStack.label}
      local search = disk_subsystem.getItemsInNetwork(itemFilter)
      if (search.n == 1) then
        local stackInMaster = search[1]
        if (stackInMaster.size + itemStack.size > itemStack.maxSize) then
          print("Joining stack of "..itemStack.size.." "..itemStack.label.." with stack of "..stackInMaster.size.." "..stackInMaster.label.." in disk network.")
          local success = transfer(bus_subsystem, disk_subsystem, itemStack)
          if not success then print("Failed item transfer.") end
        end
      end
    end
  end
  os.sleep(1)
end
