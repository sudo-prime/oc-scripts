local robot = require('robot')
local sides = require('sides')
local component = require('component')
local tone = require('tone')
local shell = require('shell')

local inventory_controller = component.inventory_controller
local geolyzer = component.geolyzer

local POWDER_NAME = 'buildinggadgets:constructionblockpowder'
local BLOCK_NAME = 'buildinggadgets:constructionblock_dense'
local WATER_NAME = 'minecraft:water'
local HARDEN_TIME = 6
local ONCE_ONLY = false

local args, ops = shell.parse()

if ops['s'] ~= nil then 
    tone.mute = true 
end
if ops['o'] ~= nil then 
    ONCE_ONLY = true 
end
if ops['h'] ~= nil then 
    print("make-paste from sudocorp\n-h print help\n-s silent mode\n-o once only mode, will return to terminal once all powder is consumed")
    os.exit(0)
end

--[[
Loops through the robot's inventory looking for a slot
with itemname POWDER_NAME. If one is found, an attempt
is made to transfer that itemstack to inventory slot 1. 
]]--
function retrieve_powder()
    for i = 1, robot.inventorySize(), 1 do
        robot.select(i)
        if is_powder() then
            local success = robot.transferTo(1)
            if not success then 
                tone.error()
                error('Failed to transfer powder to slot 1.') 
            end
            break
        end
    end
end

--[[
Attempts to place the block in inventory slot 1 directly
below the robot. Returns true or false depending on if
the attempt succeeded. Regardless of success, this function
should attempt to bring the robot back to it's home block.
]]--
function place_powder()
    local blockname = geolyzer.analyze(sides.down).name
    if blockname ~= WATER_NAME then return false end
    local success = robot.placeDown()
    if not robot.back() then
        tone.error()
        error('Robot is unable to return to it\'s home location.')
    end
    if not robot.turnLeft() then
        tone.error()
        error('Robot is unable to turn left.')
    end
    return success
end

--[[
Robot moves forward and attempts to harvest the block 
directly below the robot. Will not break any other block 
than 'buildinggadgets:constructionblock_dense'.If there's 
no tool with which the block can be broken, the robot will 
wait until a new one is inserted.
]]--
function break_powder()
    --while not robot.durability() do
    --    os.sleep(1)
    --end
    if not robot.forward() then
        tone.error()
        error('The robot cannot move to one of the four adjacent blocks.')
    end
    local blockname = geolyzer.analyze(sides.down).name
    if blockname == BLOCK_NAME then 
        return robot.swingDown()
    elseif blockname == POWDER_NAME then 
        os.sleep(HARDEN_TIME)
        blockname = geolyzer.analyze(sides.down).name
        if blockname == POWDER_NAME then 
            tone.error()
            error('The powder took too long to harden. Is there water adjacent to it?')
        end
    elseif blockname == WATER_NAME then
        return true
    end
    return false
end

function is_powder(slot) 
    return is_item_generic(slot, POWDER_NAME)
end

function is_constblock(slot) 
    return is_item_generic(slot, BLOCK_NAME) 
end
    
function is_item_generic(slot, itemname)
    local itemdata = inventory_controller.getStackInInternalSlot(slot)
    if not itemdata then return false end
    return inventory_controller.getStackInInternalSlot(slot).name == itemname
end
    
while true do
    -- Search for concrete powder in the robot's inventory.
    while not is_powder(1) do
        retrieve_powder()
        robot.select(1)
        if not is_powder(1) then 
            if ONCE_ONLY then
                os.exit()
            else
                os.sleep(15) 
            end
        end
    end
    -- Slot 1 contains some powder,
    -- proceed with making concrete
    while is_powder(1) do
        success = break_powder()
        if not success then 
            robot.back()
            tone.error()
            error('Attempt to break the block below the robot failed!')
        end
        os.sleep(1)
        local success = place_powder()
        if not success then 
            robot.back()
            tone.error()
            error('Failed to place powder, there must be running water directly beneath the robot.') 
        end
    end
end
