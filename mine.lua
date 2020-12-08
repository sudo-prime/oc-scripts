local robot = require('robot')
local sides = require('sides')
local component = require('component')
local computer = require('computer')

local geolyzer = component.geolyzer

local SCAN_PERIOD = 0
local SCAN_RADIUS = 6
local MINIMUM_ENERGY_PERCENT = 0.10
local MINIMUM_DURABILITY_PERCENT = 0.10
local METAL_THRESHOLD = 2
local DIAMOND_THRESHOLD = 2.60
local OBSIDIAN_THRESHOLD = 6

local STATE = 'GO_DOWN'
local FINISHED = false
local FACING = 'NORTH'
local DONE = false
local HISTORY_LEN = nil
local HOME = {x = 0, y = 0, z = 0}
local COORDS_RELATIVE_HOME = {x = 0, y = 0, z = 0}
local HISTORY = {}
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

function coords_equal(coord1, coord2)
    return coord1.x == coord2.x and coord1.y == coord2.y and coord1.z == coord2.z
end

function coords_equal_xz(coord1, coord2)
    return coord1.x == coord2.x and coord1.z == coord2.z
end

function face_south(history)
    if FACING == 'NORTH' then
        turn_around(history)
    elseif FACING == 'WEST' then
        turn_left(history)
    elseif FACING == 'EAST' then
        turn_right(history)
    end
    FACING = 'SOUTH'
end

function face_east(history)
    if FACING == 'NORTH' then
        turn_right(history)
    elseif FACING == 'WEST' then
        turn_around(history)
    elseif FACING == 'SOUTH' then
        turn_left(history)
    end
    FACING = 'EAST'
end

function face_west(history)
    if FACING == 'NORTH' then
        turn_left(history)
    elseif FACING == 'SOUTH' then
        turn_right(history)
    elseif FACING == 'EAST' then
        turn_around(history)
    end
    FACING = 'WEST'
end

function face_north(history)
    if FACING == 'SOUTH' then
        turn_around(history)
    elseif FACING == 'WEST' then
        turn_right(history)
    elseif FACING == 'EAST' then
        turn_left(history)
    end
    FACING = 'NORTH'
end

function mine(side)
    if side == sides.left then
        turn_left(HISTORY)
        robot.swing()
        tone.progress()
        if not is_obstructed(sides.forward) then
            go_forward(HISTORY)
        end
    elseif side == sides.right then
        turn_right(HISTORY)
        robot.swing()
        tone.progress()
        if not is_obstructed(sides.forward) then
            go_forward(HISTORY)
        end
    elseif side == sides.forward then
        robot.swing()
        tone.progress()
        if not is_obstructed(sides.forward) then
            go_forward(HISTORY)
        end
    elseif side == sides.back then
        turn_around(HISTORY)
        robot.swing()
        tone.progress()
        if not is_obstructed(sides.forward) then
            go_forward(HISTORY)
        end
    elseif side == sides.up then
        robot.swingUp()
        tone.progress()
        if not is_obstructed(sides.up) then
            go_up(HISTORY)
        end
    elseif side == sides.down then
        robot.swingDown()
        tone.progress()
        if not is_obstructed(sides.down) then
            go_down(HISTORY)
        end
    end
end

function mine_down()
    robot.swingDown()
    tone.progress()
    if not is_obstructed(sides.down) then
        go_down()
    end
end

function go_up(history)
    local success = robot.up()
    if success then
        if history ~= nil then
            table.insert(history, 'up')
        end
        COORDS_RELATIVE_HOME.y = COORDS_RELATIVE_HOME.y + 1
    else
        STATE = 'ERROR'
    end
end

function go_down(history)
    local success = robot.down()
    if success then
        if history ~= nil then
            table.insert(history, 'down')
        end
        COORDS_RELATIVE_HOME.y = COORDS_RELATIVE_HOME.y - 1
    else
        STATE = 'ERROR'
    end
end

function go_forward(history)
    local success = robot.forward()
    if success then
        if history ~= nil then
            table.insert(history, 'forward')
        end
        if FACING == 'NORTH' then
            COORDS_RELATIVE_HOME.z = COORDS_RELATIVE_HOME.z - 1
        elseif FACING == 'SOUTH' then
            COORDS_RELATIVE_HOME.z = COORDS_RELATIVE_HOME.z + 1
        elseif FACING == 'WEST' then
            COORDS_RELATIVE_HOME.x = COORDS_RELATIVE_HOME.x - 1
        elseif FACING == 'EAST' then
            COORDS_RELATIVE_HOME.x = COORDS_RELATIVE_HOME.x + 1
        end
    else
        STATE = 'ERROR'
    end
end

function go_back(history)
    local success = robot.back()
    if success then
        if history ~= nil then
            table.insert(history, 'back')
        end
        if FACING == 'NORTH' then
            COORDS_RELATIVE_HOME.z = COORDS_RELATIVE_HOME.z + 1
        elseif FACING == 'SOUTH' then
            COORDS_RELATIVE_HOME.z = COORDS_RELATIVE_HOME.z - 1
        elseif FACING == 'WEST' then
            COORDS_RELATIVE_HOME.x = COORDS_RELATIVE_HOME.x + 1
        elseif FACING == 'EAST' then
            COORDS_RELATIVE_HOME.x = COORDS_RELATIVE_HOME.x - 1
        end
    else
        STATE = 'ERROR'
    end
end

function turn_right(history)
    local success = robot.turnRight()
    if success then
        if FACING == 'NORTH' then
            FACING = 'EAST'
        elseif FACING == 'EAST' then
            FACING = 'SOUTH'
        elseif FACING == 'SOUTH' then
            FACING = 'WEST'
        elseif FACING == 'WEST' then
            FACING = 'NORTH'
        end
        if history ~= nil then
            table.insert(history, 'right')
        end
    else
        STATE = 'ERROR'
    end
end

function turn_left(history)
    local success = robot.turnLeft()
    if success then
        if FACING == 'NORTH' then
            FACING = 'WEST'
        elseif FACING == 'WEST' then
            FACING = 'SOUTH'
        elseif FACING == 'SOUTH' then
            FACING = 'EAST'
        elseif FACING == 'EAST' then
            FACING = 'NORTH'
        end
        if history ~= nil then
            table.insert(history, 'left')
        end
    else
        STATE = 'ERROR'
    end
end

function turn_around(history)
    local success1 = robot.turnRight()
    local success2 = robot.turnRight()
    if success1 and success2 then
        if FACING == 'NORTH' then
            FACING = 'SOUTH'
        elseif FACING == 'WEST' then
            FACING = 'EAST'
        elseif FACING == 'EAST' then
            FACING = 'WEST'
        elseif FACING == 'SOUTH' then
            FACING = 'NORTH'
        end
        if history ~= nil then
            table.insert(history, '180')
        end
    else
        STATE = 'ERROR'
    end
end

function rewind_last_movement()
    local last = table.remove(HISTORY)
    if last == 'forward' then
        go_back()
    elseif last == 'right' then
        turn_left()
    elseif last == 'left' then
        turn_right()
    elseif last == '180' then
        turn_around()
    elseif last == 'back' then
        go_forward()
    elseif last == 'up' then
        go_down()
    elseif last == 'down' then
        go_up()
    else
        STATE = 'ERROR'
    end
end

function is_bedrock_below()
    local scan = geolyzer.analyze(sides.down)
    return scan.name == 'minecraft:bedrock'
end

function is_obstructed(side)
    if side == sides.up then
        return robot.detectUp()
    elseif side == sides.down then
        return robot.detectDown()
    else
        return robot.detect(side)
    end
end

function scan_with_radius(radius, hardness_filter)
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

function update()
    if STATE == 'HALT' then
        tone.success()
        print('Done!')
		os.exit(0)
    elseif STATE == 'RETURN_HOME' and coords_equal(COORDS_RELATIVE_HOME, HOME) then
        if HIT_BEDROCK then
            STATE = 'HALT'
        elseif (robot.durability() or 0) < MINIMUM_DURABILITY_PERCENT then
            STATE = 'HALT'
        else
            os.sleep(30)
            STATE = 'GO_DOWN'
            FINISHED = false
        end
    elseif STATE == 'RETURN_SHAFT_THEN_HOME' and #HISTORY == 0 then
        STATE = 'RETURN_HOME'
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
    elseif STATE == 'RETURN_SHAFT' and #HISTORY == 0 then
        STATE = 'SCANNING'
    elseif STATE == 'GO_DOWN' and is_bedrock_below() or COORDS_RELATIVE_HOME.y then
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
        else
            STATE = 'GO_DOWN'
        end
    elseif STATE == 'SEEKING_ORE_Z' and COORDS_RELATIVE_HOME.z == TARGET.z then
        print('COORD', COORDS_RELATIVE_HOME.z, TARGET.z)
        STATE = 'SEEKING_ORE_X'
    elseif STATE == 'SEEKING_ORE_X' and COORDS_RELATIVE_HOME.x == TARGET.x then
        print('COORD', COORDS_RELATIVE_HOME.x, TARGET.x)
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

function do_step()
    if STATE == 'RETURN_HOME' then
        if not coords_equal(COORDS_RELATIVE_HOME, HOME) then
            go_up()
        end
    elseif STATE == 'RETURN_SHAFT' or STATE == 'RETURN_SHAFT_THEN_HOME' then
        --Playback history until we return to the shaft
        if #HISTORY == 0 then
            print('ERROR: an attempt to rewind my movements was made, when there are no moves left to rewind. I should already be back at the mining shaft!')
            --for key, val in pairs(COORDS_RELATIVE_HOME) do print(key, val) end
            print(coords_equal_xz(COORDS_RELATIVE_HOME, HOME))
            STATE = 'ERROR'
        else
            rewind_last_movement()
        end
    elseif STATE == 'SCANNING' then
        TIME_SINCE_SCAN = 0
        local ores = scan_with_radius(SCAN_RADIUS)
        if #ores ~= 0 then
            TARGET = {x = ores[1].x, z = ores[1].z}
        else
            TARGET = nil
        end
    elseif STATE == 'SEEKING_ORE_Z' then
        print(COORDS_RELATIVE_HOME.z, TARGET.z)
        if TARGET.z < COORDS_RELATIVE_HOME.z then
            face_north(HISTORY)
            mine(sides.forward)
        elseif TARGET.z > COORDS_RELATIVE_HOME.z then
            face_south(HISTORY)
            mine(sides.forward)
        end
    elseif STATE == 'SEEKING_ORE_X' then
        print(COORDS_RELATIVE_HOME.x, TARGET.x)
        if TARGET.x < COORDS_RELATIVE_HOME.x then
            face_west(HISTORY)
            mine(sides.forward)
        elseif TARGET.x > COORDS_RELATIVE_HOME.x then
            face_east(HISTORY)
            mine(sides.forward)
        end
    elseif STATE == 'GO_DOWN' then
        if is_obstructed(sides.down) then
            mine_down()
        else
            go_down()
        end
        TIME_SINCE_SCAN = TIME_SINCE_SCAN + 1
    elseif STATE == 'MINING_VEIN' then
        DONE = false
        if HISTORY_LEN == nil then
            HISTORY_LEN = #HISTORY
        end
        local mined_block = false
        for _, side in ipairs(ALL_SIDES) do
            local scan = geolyzer.analyze(side)
            if scan.hardness > METAL_THRESHOLD then
                mine(side)
                mined_block = true
                break
            end
        end
        if not mined_block then
            if HISTORY_LEN == #HISTORY then
                TARGET = nil
                HISTORY_LEN = nil
                DONE = true
            else
                rewind_last_movement()
            end
        end
    end
end
            
function main()
    tone.success()
    while true do
        update()
        do_step()
        os.sleep(0.1)
    end
end

main()