--[[
    moves.lua

    A movement module that wraps most of
    the Robot API's movement functions. Assumes
    the initial facing direction of the robot was
    north for calculating relative position.

    REQUIREMENTS:
    1. OpenOs

    Written by Nick V.
]]

local moves = {}


--[[
    ENUMS
]]
moves.north = 0
moves.east  = 1
moves.south = 2
moves.west  = 3

moves.enum = {}
moves.enum.around = 'around'
moves.enum.left = 'left'
moves.enum.right = 'right'
moves.enum.forward = 'forward'
moves.enum.back = 'back'
moves.enum.up = 'up'
moves.enum.down = 'down'


--[[
    DEPENDENCIES
]]
moves._robot = require('robot')
moves._filesystem = require('filesystem')
moves._serialization = require('serialization')
moves._os = require('os')


--[[
    INTERNAL ATTRIBUTES
]]
moves._recording = false
moves._history = {}
moves._relative = {x=0, y=0, z=0}
moves._direction = 0
moves._retries = 0
moves._retryTimer = 0
moves._dirSet = false


--[[
    TRANSFORMATIONS
]]
moves.transform = {}
moves.transform.forward = {}
moves.transform.forward[moves.north] = {x=0, y=0, z=-1}
moves.transform.forward[moves.east ] = {x=1, y=0, z=0}
moves.transform.forward[moves.south] = {x=0, y=0, z=1}
moves.transform.forward[moves.west ] = {x=-1, y=0, z=0}
moves.transform.back = {}
moves.transform.back[moves.north] = {x=0, y=0, z=1}
moves.transform.back[moves.east ] = {x=-1, y=0, z=0}
moves.transform.back[moves.south] = {x=0, y=0, z=-1}
moves.transform.back[moves.west ] = {x=1, y=0, z=0}
moves.transform.up = {x=0, y=1, z=0}
moves.transform.down = {x=0, y=-1, z=0}
moves.transform.left = -1
moves.transform.right = 1
moves.transform.around = 2


--[[
    UTILITY
]]
moves.util = {}
function moves.util.compareCoord(a, b)
    return a.x == b.x and a.y == b.y and a.z == b.z
end
function moves.util.addCoord(a, b)
    return {x = a.x + b.x, y = a.y + b.y, z = a.z + b.z}
end
function moves.util.isValidCoord(a)
    local x = a.x ~= nil and type(a.x) == 'number'
    local y = a.y ~= nil and type(a.y) == 'number'
    local z = a.z ~= nil and type(a.z) == 'number'
    return x and y and z
end
function moves.util.isValidAction(a)
    return moves.enum[a] ~= nil and moves.enum[a] == a
end
function moves.util.isCardinal(a)
    local north = a == moves.north
    local east  = a == moves.east
    local south = a == moves.south
    local west  = a == moves.west
    return north or east or south or west
end
function moves.isFacing(direction)
    return moves._direction == direction
end
function moves.turnFacing(direction)
    if not moves.util.isCardinal(direction) then
        local estr = "Invalid parameter %s, expected direction enum"
        error(string.format(estr, tostring(direction)))
    end
    local rightTurns = (direction - moves.getDirection()) % 4
    if rightTurns == 3 then
        return moves.left()
    else
        return moves.right(rightTurns)
    end
end


--[[
    MOVEMENT
]]
function moves.forward(distance)
    return moves._move(moves.enum.forward, distance)
end
function moves.back(distance)
    return moves._move(moves.enum.back, distance)
end
function moves.up(distance)
    return moves._move(moves.enum.up, distance)
end
function moves.down(distance)
    return moves._move(moves.enum.down, distance)
end
function moves.right(numTimes)
    return moves._turn(moves.enum.right, numTimes)
end
function moves.left(numTimes)
    return moves._turn(moves.enum.left, numTimes)
end
function moves.around(numTimes)
    return moves._turn(moves.enum.around, numTimes)
end

function moves.getRetries()
    return moves._retries
end
function moves.setRetries(numRetries)
    if type(numRetries) ~= 'number' or numRetries  < 0 then
        local estr = "Invalid parameter %s, expected positive number"
        error(string.format(estr, tostring(numRetries)))
    end
    moves._retries = numRetries
end
function moves.getRetryTimer()
    return moves._retryTimer
end
function moves.setRetryTimer(seconds)
    if type(seconds) ~= 'number' or seconds  < 0 then
        local estr = "Invalid parameter %s, expected positive number"
        error(string.format(estr, tostring(seconds)))
    end
    moves._retryTimer = seconds
end
function moves.getDirection()
    return moves._direction
end
function moves.setDirection(direction)
    if not moves.util.isCardinal(direction) then
        local estr = "Invalid parameter %s, expected direction enum"
        error(string.format(estr, tostring(direction)))
    end
    moves._direction = direction
end


--[[
    POSITION
]]
function moves.getRelative()
    return moves._relative
end
function moves.setRelative(position)
    if not moves.util.isValidCoord(position) then
        local estr = "Invalid parameter %s, expected table with 'x', 'y', 'z'"
        error(string.format(estr, tostring(position)))
    end
    moves._relative = position
end


--[[
    HISTORY
]]
function moves.setRecording(bool)
    if type(bool) ~= 'boolean' then
        local estr = "Invalid parameter %s, expected boolean"
        error(string.format(estr, tostring(bool)))
    end
    moves._recording = bool
end
function moves.isRecording()
    return moves._recording
end
function moves.clearHistory()
    moves._history = {}
end
function moves.getHistory()
    return moves._history
end
function moves.rewind(numMoves)
    local previous = moves._recording
    moves._recording = false
    numMoves = math.min(numMoves or #moves._history, #moves._history)
    if numMoves  < 0 then
        local estr = "Invalid parameter %s, expected positive number"
        error(string.format(estr, tostring(numMoves)))
    end
    for i = 1, numMoves do
        if #moves._history == 0 then
            print('Nick did a bad and history length was 0...')
        end
        local lastAction = table.remove(moves._history)
        if not moves.util.isValidAction(lastAction) then
            local estr = 'Encountered invalid action %s while rewinding.'
            error(string.format(estr, tostring(lastAction)))
        end
        local undoAction = moves.undo[lastAction]
        local success = moves[undoAction]()
        if not success then return false end
    end
    moves._recording = previous
    return true
end


--[[
    INTERNAL METHODS
]]
function moves._move(direction, distance)
    if distance ~= 0 then distance = distance or 1 end
    for i = 1, distance do
        local success = moves._doActionWithRetries(direction)
        if not success then
            return false
        end
        local transform = moves.transform[direction][moves._direction]
                       or moves.transform[direction]
        moves._relative = moves.util.addCoord(moves._relative, transform)
        moves._remember(direction)
    end
    return true
end
function moves._turn(direction, numTimes)
    if numTimes ~= 0 then numTimes = numTimes or 1 end
    for i = 1, numTimes do
        local success = moves._doActionWithRetries(direction)
        if not success then
            return false
        end
        local transform = moves.transform[direction]
        moves._direction = (moves._direction + transform) % 4
        moves._remember(direction)
    end
    return true
end
function moves._doActionWithRetries(action)
    action = moves.adapter[action]
    local success = moves._robot[action]()
    if not success then
        for retry = 1, moves._retries do
            moves._os.sleep(moves._retryTimer)
            success = moves._robot[action]()
            if success then break end
        end
        if not success then return false end
    end
    return true
end
function moves._remember(move)
    if not moves._recording then return end
    table.insert(moves._history, move)
end

--[[
    INTERNAL CONSTANTS
]]
moves.undo = {}
moves.undo[moves.enum.around] = moves.enum.around
moves.undo[moves.enum.left] = moves.enum.right
moves.undo[moves.enum.right] = moves.enum.left
moves.undo[moves.enum.forward] = moves.enum.back
moves.undo[moves.enum.back] = moves.enum.forward
moves.undo[moves.enum.up] = moves.enum.down
moves.undo[moves.enum.down] = moves.enum.up

moves.adapter = {}
moves.adapter[moves.enum.around] = 'turnAround'
moves.adapter[moves.enum.left] = 'turnLeft'
moves.adapter[moves.enum.right] = 'turnRight'
moves.adapter[moves.enum.forward] = 'forward'
moves.adapter[moves.enum.back] = 'back'
moves.adapter[moves.enum.up] = 'up'
moves.adapter[moves.enum.down] = 'down'

return moves