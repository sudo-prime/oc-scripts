--[[
    moves.lua

    A movement module that wraps most of
    the Robot API's movement functions. Adds
    features such as the ability to retain both
    robot facing direction and relative position
    with regard to where it was placed.

    COMING SOON:
    Functionality to record, save, and re-play robot
    movements.
    Full documentation.

    REQUIREMENTS:
    1. OpenOs
    2. moves.facing should be changed according to
    the starting facing direction of the robot. This
    can be done with moves.init().
]]--


--[[
    Sends modem messages to devices on port PORT,
    when the given energy device either rises above
    OFF_THRESHOLD or drops below ON_THRESHOLD, in
    percentage of max capacity.
]]--

local robot = require('robot')
local copy = require('copy')

local moves = {}

moves.north = 'NORTH'
moves.south = 'SOUTH'
moves.east  = 'EAST'
moves.west  = 'WEST'

-- You can change the following line to match
-- the initial facing direction of the robot,
-- or use .init().
moves.facing = moves.north

moves.history180 = '180'
moves.historyLeft = 'LEFT'
moves.historyRight = 'RIGHT'
moves.historyForward = 'FORWARD'
moves.historyBack = 'BACK'
moves.historyUp = 'UP'
moves.historyDown = 'DOWN'

moves.memory = true
moves.recording = false
moves.history = {}
moves.recorded = {}
moves.waypoints = {}
moves.relativePosition = {x = 0, y = 0, z = 0}
moves.initialFacing = nil

local function coords_equal(coord1, coord2)
    return coord1.x == coord2.x and coord1.y == coord2.y and coord1.z == coord2.z
end

function moves.init(direction, position)
    moves.facing = direction
    if position ~= nil then
        moves.relativePosition = position
    end
end

function moves.remember(move)
    if moves.memory then
        table.insert(moves.history, move)
    end
    if moves.recording then
        table.insert(moves.recorded, move)
    end
end

function moves.record()
    if not moves.recording then
        moves.recording = true
        moves.recorded.initialFacing = moves.facing
        moves.recorded.initialPosition = copy.deepcopy(moves.relativePosition)
    end
end

function moves.clearHistory()
    moves.history = {}
end

function moves.clearRecording()
    moves.recorded = {}
end

function moves.getRecording()
    return moves.recorded
end

function moves.getHistory()
    return moves.history
end

function moves.saveRecording(filepath)
    if filesystem.exists(filepath) then
        error('File already exists', 2)
    end
    local file = io.open(filepath, 'w')
    file:write(serialization.serialize(moves.recorded))
    file:close()
end

function moves.loadRecording(filepath)
    if not filesystem.exists(filepath) then
        error(string.format('No such file at path %s', filepath), 2)
    end
    local file = io.open(filepath, 'r')
    local recording = serialization.unserialize(file:read('*a'))
    file:close()
    return recording
end

function moves.playRecording(recording)
    local temp = moves.recording
    moves.recording = false
    if not coords_equal(recording.initialPosition, moves.relativePosition) then
        error('The robot is not in the correct location to replay this recording.')
    end
    if recording.initialFacing ~= moves.facing then
        error('The robot is not in the correct orientation to replay this recording.')
    end

    for i = 1, #recording do
        local step = recording[i]
        local success = false
        if step == moves.historyForward then
            success = moves.forward()
        elseif step == moves.historyRight then
            success = moves.turnRight()
        elseif step == moves.historyLeft then
            success = moves.turnLeft()
        elseif step == moves.history180 then
            success = moves.turnAround()
        elseif step == moves.historyBack then
            success = moves.back()
        elseif step == moves.historyUp then
            success = moves.up()
        elseif step == moves.historyDown then
            success = moves.down()
        end
        if not success then
            error(string.format("Attempted to replay movement %s, but the attempt was unsuccessful.", step))
        end
    end
    moves.recording = temp
end

function moves.rewind(steps)
    moves.memory = false
    if steps == nil then
        steps = #moves.history
    end
    for i = 1, steps do
        local last = table.remove(moves.history)
        local success = false
        if last == moves.historyForward then
            success = moves.back()
        elseif last == moves.historyRight then
            success = moves.turnLeft()
        elseif last == moves.historyLeft then
            success = moves.turnRight()
        elseif last == moves.history180 then
            success = moves.turnAround()
        elseif last == moves.historyBack then
            success = moves.forward()
        elseif last == moves.historyUp then
            success = moves.down()
        elseif last == moves.historyDown then
            success = moves.up()
        end
        if not success then
            error(string.format("Attempted to rewind movement %s, but the attempt was unsuccessful.", last))
        end
    end
    moves.memory = true
    return true
end

function moves.up(dist)
    if dist == nil then
        dist = 1
    end
    for i = 1, dist do
        local success = robot.up()
        if success then
            moves.relativePosition.y = moves.relativePosition.y + 1
            moves.remember(moves.historyUp)
        else
            return false
        end
    end
    return true
end

function moves.down(dist)
    if dist == nil then
        dist = 1
    end
    for i = 1, dist do
        local success = robot.down()
        if success then
            moves.relativePosition.y = moves.relativePosition.y - 1
            moves.remember(moves.historyDown)
        else
            return false
        end
    end
    return true
end

function moves.forward(dist)
    if dist == nil then
        dist = 1
    end
    for i = 1, dist do
        local success = robot.forward()
        if success then
            if moves.facing == moves.north then
                moves.relativePosition.z = moves.relativePosition.z - 1
            elseif moves.facing == moves.south then
                moves.relativePosition.z = moves.relativePosition.z + 1
            elseif moves.facing == moves.west then
                moves.relativePosition.x = moves.relativePosition.x - 1
            elseif moves.facing == moves.east then
                moves.relativePosition.x = moves.relativePosition.x + 1
            end
            moves.remember(moves.historyForward)
        else
            return false
        end
    end
    return true
end

function moves.back()
    if dist == nil then
        dist = 1
    end
    for i = 1, dist do
        local success = robot.back()
        if success then
            if moves.facing == moves.north then
                moves.relativePosition.z = moves.relativePosition.z + 1
            elseif moves.facing == moves.south then
                moves.relativePosition.z = moves.relativePosition.z - 1
            elseif moves.facing == moves.west then
                moves.relativePosition.x = moves.relativePosition.x + 1
            elseif moves.facing == moves.east then
                moves.relativePosition.x = moves.relativePosition.x - 1
            end
            moves.remember(moves.historyBack)
        else
            return false
        end
    end
    return true
end

function moves.turnRight(numTimes)
    if numTimes == nil then
        numTimes = 1
    end
    for i = 1, numTimes do
        local success = robot.turnRight()
        if success then
            if moves.facing == moves.north then
                moves.facing = moves.east
            elseif moves.facing == moves.east then
                moves.facing = moves.south
            elseif moves.facing == moves.south then
                moves.facing = moves.west
            elseif moves.facing == moves.west then
                moves.facing = moves.north
            end
            moves.remember(moves.historyRight)
        else
            return false
        end
    end
    return true
end

function moves.turnLeft(numTimes)
    if numTimes == nil then
        numTimes = 1
    end
    for i = 1, numTimes do
        local success = robot.turnLeft()
        if success then
            if moves.facing == moves.north then
                moves.facing = moves.west
            elseif moves.facing == moves.west then
                moves.facing = moves.south
            elseif moves.facing == moves.south then
                moves.facing = moves.east
            elseif moves.facing == moves.east then
                moves.facing = moves.north
            end
            moves.remember(moves.historyLeft)
        else
            return false
        end
    end
    return true
end

function moves.turnAround()
    local success1 = robot.turnRight()
    local success2 = robot.turnRight()
    if success1 and success2 then
        if moves.facing == moves.north then
            moves.facing = moves.south
        elseif moves.facing == moves.west then
            moves.facing = moves.east
        elseif moves.facing == moves.east then
            moves.facing = moves.west
        elseif moves.facing == moves.south then
            moves.facing = moves.north
        end
        moves.remember(moves.history180)
        return true
    else
        return false
    end
end

function moves.turnSouth()
    if moves.facing == moves.north then
        moves.turnAround()
    elseif moves.facing == moves.west then
        moves.turnLeft()
    elseif moves.facing == moves.east then
        moves.turnRight()
    end
    moves.facing = moves.south
end

function moves.turnEast()
    if moves.facing == moves.north then
        moves.turnRight()
    elseif moves.facing == moves.west then
        moves.turnAround()
    elseif moves.facing == moves.south then
        moves.turnLeft()
    end
    moves.facing = moves.east
end

function moves.turnWest()
    if moves.facing == moves.north then
        moves.turnLeft()
    elseif moves.facing == moves.south then
        moves.turnRight()
    elseif moves.facing == moves.east then
        moves.turnAround()
    end
    moves.facing = moves.west
end

function moves.turnNorth()
    if moves.facing == moves.south then
        moves.turnAround()
    elseif moves.facing == moves.west then
        moves.turnRight()
    elseif moves.facing == moves.east then
        moves.turnLeft()
    end
    moves.facing = moves.north
end

return moves