local robot = require('robot')
local sides = require('sides')
local component = require('component')
local computer = require('computer')
local moves = require('moves')
local os = require('os')

local geolyzer = component.geolyzer
local inventory_controller = component.inventory_controller

local SCAN_PERIOD = 0
local SCAN_RADIUS = 6
local MINIMUM_ENERGY_PERCENT = 0.10
local MINIMUM_DURABILITY_PERCENT = 0.10
local METAL_THRESHOLD = 2.5
local OBSIDIAN_THRESHOLD = 20

local STATE = 'GO_DOWN'
local FINISHED = false
local DONE = false
local HOME = {x = 0, y = 0, z = 0}
local TIME_SINCE_SCAN = 0
local HIT_BEDROCK = false
local ALL_SIDES = {sides.forward, sides.back, sides.left, sides.right, sides.up, sides.down}
local QUADRANT_OFFSET = {
    {x = 0, z = 0},
    {x = -1, z = 0},
    {x = -1, z = -1},
    {x = 0, z = -1}
}

local tone = {}

function tone.success()
    computer.beep(440, 0.07)
    computer.beep(440, 0.07)
    computer.beep(659.25, 0.07)
end

function tone.progress()
    computer.beep(440, 0.07)
end

function tone.error()
    computer.beep(196, 0.07)
    computer.beep(196, 0.07)
    computer.beep(196, 0.07)
end

local function is_obstructed(side)
    if side == sides.up then
        return robot.detectUp()
    elseif side == sides.down then
        return robot.detectDown()
    else
        return robot.detect(side)
    end
end

local function mine(side)
    if side == sides.left then
        moves.left()
        robot.swing()
        tone.progress()
        if not is_obstructed(sides.forward) then
            moves.forward()
        end
    elseif side == sides.right then
        moves.right()
        robot.swing()
        tone.progress()
        if not is_obstructed(sides.forward) then
            moves.forward()
        end
    elseif side == sides.forward then
        robot.swing()
        tone.progress()
        if not is_obstructed(sides.forward) then
            moves.forward()
        end
    elseif side == sides.back then
        moves.around()
        robot.swing()
        tone.progress()
        if not is_obstructed(sides.forward) then
            moves.forward()
        end
    elseif side == sides.up then
        robot.swingUp()
        tone.progress()
        if not is_obstructed(sides.up) then
            moves.up()
        end
    elseif side == sides.down then
        robot.swingDown()
        tone.progress()
        if not is_obstructed(sides.down) then
            moves.down()
        end
    end
end

local function mine_down()
    robot.swingDown()
    tone.progress()
    if not is_obstructed(sides.down) then
        moves.down()
    end
end

-- Transfers the contents of the robot's inventory
-- to the inventory or chest on given side.
local function transferInventory(side)
    local size = inventory_controller.getInventorySize(side)
    print("Transferring inventory...")
    -- For each slot in the robot's inventory...
    for robotSlot = 1, robot.inventorySize() do
        robot.select(robotSlot)
        local item_stack = inventory_controller.getStackInInternalSlot()
        if item_stack ~= nil then -- There's an item here
            -- Attempt to transfer to each slot in the inventory
            local done = false
            local reason
            local i = 1
            while not done and not(i > size) do
                done, reason = inventory_controller.dropIntoSlot(side, i)
                i = i + 1
            end
        end
    end
    print("Done.")
    return true
end

local function is_bedrock_below()
    local scan = geolyzer.analyze(sides.down)
    return scan.name == 'minecraft:bedrock'
end



local function scan_with_radius(radius, hardness_filter)
    local out = {}
    for i = 1, 4 do
        local offsetx = radius * QUADRANT_OFFSET[i].x
        local offsetz = radius * QUADRANT_OFFSET[i].z
        local offsety = 0
        
        local sizex = radius
        local sizez = radius
        local sizey = 1
        
        local map = {}
        local scan_data = geolyzer.scan(offsetx, offsetz, offsety, sizex, sizez, sizey)
        
        local i = 1
        for y = 0, sizey - 1 do
            for z = 0, sizez - 1 do
                for x = 0, sizex - 1 do
                    -- alternatively when thinking in terms of 3-dimensional table: map[offsety + y][offsetz + z][offsetx + x] = scanData[i]
                    map[i] = {x = offsetx + x, y = offsety + y, z = offsetz + z, hardness = scan_data[i]}
                    i = i + 1
                end
            end
        end
        
        for i = 1, sizex*sizez*sizey do
            if not (map[i].x == 0 and map[i].y == 0 and map[i].z == 0) then
                if map[i].hardness > METAL_THRESHOLD and map[i].hardness < OBSIDIAN_THRESHOLD then
                    table.insert(out, map[i])
                end
            end
        end
    end
    return out
end

local function update()
    if STATE == 'HALT' then
        tone.success()
        print('Done!')
		os.exit(0)
    elseif STATE == 'RETURN_HOME' and moves.util.compareCoord(moves.getRelative(), HOME) then
        if HIT_BEDROCK then
            STATE = 'HALT'
        elseif (robot.durability() or 0) < MINIMUM_DURABILITY_PERCENT then
            STATE = 'HALT'
        else
            transferInventory(sides.front)
            os.sleep(90)
            STATE = 'GO_DOWN'
            FINISHED = false
        end
    elseif STATE == 'RETURN_SHAFT_THEN_HOME' and #moves.getHistory() == 0 then
        STATE = 'RETURN_HOME'
        moves.setRecording(false)
    elseif computer.energy() / computer.maxEnergy() < MINIMUM_ENERGY_PERCENT and not FINISHED then
        print('Low battery! Heading home.')
        if STATE == 'MINING_VEIN' 
            or STATE == 'SEEKING_ORE_Z'
            or STATE == 'SEEKING_ORE_X'
            or STATE == 'SEEKING_ORE_Y' then
            STATE = 'RETURN_SHAFT_THEN_HOME'
        else
            STATE = 'RETURN_HOME'
        end
        FINISHED = true
    elseif (robot.durability() or 0) < MINIMUM_DURABILITY_PERCENT and not FINISHED then
        print('Low durability! Heading home.')
        if STATE == 'MINING_VEIN' 
            or STATE == 'SEEKING_ORE_Z'
            or STATE == 'SEEKING_ORE_X'
            or STATE == 'SEEKING_ORE_Y' then
            STATE = 'RETURN_SHAFT_THEN_HOME'
        else
            STATE = 'RETURN_HOME'
        end
        FINISHED = true
    elseif STATE == 'RETURN_SHAFT' and #moves.getHistory() == 0 then
        STATE = 'SCANNING'
        moves.setRecording(false)
    elseif STATE == 'GO_DOWN' and is_bedrock_below() then
        print('Bedrock below, heading home.')
        FINISHED = true
        HIT_BEDROCK = true
        STATE = 'RETURN_HOME'
    elseif STATE == 'GO_DOWN' and TIME_SINCE_SCAN > SCAN_PERIOD then
        STATE = 'SCANNING'
        print('Scanning...')
    elseif STATE == 'SCANNING' then
        if TARGET ~= nil then
            print('Seeking target at relative coordinates', TARGET.x, TARGET.z)
            STATE = 'SEEKING_ORE_Z'
            moves.setRecording(true)
        else
            STATE = 'GO_DOWN'
        end
    elseif STATE == 'SEEKING_ORE_Z' and moves.getRelative().z == TARGET.z then
        print('COORD', moves.getRelative().z, TARGET.z)
        STATE = 'SEEKING_ORE_X'
    elseif STATE == 'SEEKING_ORE_X' and moves.getRelative().x == TARGET.x then
        print('COORD', moves.getRelative().x, TARGET.x)
        STATE = 'MINING_VEIN'
    elseif STATE == 'MINING_VEIN' and DONE then
        print('Done with this vein. Heading back...')
        DONE = false
        STATE = 'RETURN_SHAFT'
    elseif STATE == 'ERROR' then
        -- Play an error message and wait.
        tone.error()
        os.sleep(15)
    end
end

local function do_step()
    if STATE == 'RETURN_HOME' then
        if not moves.util.compareCoord(moves.getRelative(), HOME) then
            moves.up()
        end
    elseif STATE == 'RETURN_SHAFT' or STATE == 'RETURN_SHAFT_THEN_HOME' then
        --Playback history until we return to the shaft
        print("rewinding...")
        print(moves.getHistory()[1])
        moves.rewind(1)
    elseif STATE == 'SCANNING' then
        TIME_SINCE_SCAN = 0
        local ores = scan_with_radius(SCAN_RADIUS)
        if #ores ~= 0 then
            TARGET = {x = ores[1].x, z = ores[1].z}
        else
            TARGET = nil
        end
    elseif STATE == 'SEEKING_ORE_Z' then
        print(moves.getRelative().z, TARGET.z)
        if TARGET.z < moves.getRelative().z then
            moves.turnFacing(moves.north)
            mine(sides.forward)
        elseif TARGET.z > moves.getRelative().z then
            moves.turnFacing(moves.south)
            mine(sides.forward)
        end
    elseif STATE == 'SEEKING_ORE_X' then
        print(moves.getRelative().x, TARGET.x)
        if TARGET.x < moves.getRelative().x then
            moves.turnFacing(moves.west)
            mine(sides.forward)
        elseif TARGET.x > moves.getRelative().x then
            moves.turnFacing(moves.east)
            mine(sides.forward)
        end
    elseif STATE == 'GO_DOWN' then
        if is_obstructed(sides.down) then
            mine_down()
        else
            moves.down()
        end
        TIME_SINCE_SCAN = TIME_SINCE_SCAN + 1
    elseif STATE == 'MINING_VEIN' then
        DONE = false
        if HISTORY_LEN == nil then
            HISTORY_LEN = #moves.getHistory()
        end
        local mined_block = false
        for _, side in ipairs(ALL_SIDES) do
            local scan = geolyzer.analyze(side)
            if scan.hardness > METAL_THRESHOLD and scan.hardness < OBSIDIAN_THRESHOLD then
                mine(side)
                mined_block = true
                break
            end
        end
        if not mined_block then
            if HISTORY_LEN == #moves.getHistory() then
                TARGET = nil
                HISTORY_LEN = nil
                DONE = true
            else
                moves.rewind(1)
            end
        end
    end
end
            
local function main()
    moves.setRetries(5)
    moves.setRetryTimer(2)
    tone.success()
    while true do
        update()
        do_step()
    end
end

main()