local component = require("component")
local gpu = component.gpu
local event = require("event")
local tape = component.tape_drive

local screenWidth, screenHeight = gpu.getResolution()

local uniPosition = "⬤"
local uniLine = "─"

local function rewindToStart()
    tape.seek(tape.getSize()*-1)
end

local function percentDone()
    return tape.getPosition()/tape.getSize()
end

local function printCentered(line, toPrint)
    local centerOffset = screenWidth/2 - string.len(toPrint)/2
    gpu.set(centerOffset, line, toPrint)
end

local function updateVisualizer()
    local line = 10
    gpu.set(1, line, "I'm addicting to buying expensive helicopters")
    gpu.set(1, line-1, "I'm addicting to buying expensive helicopters")
    gpu.set(1, line+1, "I'm addicting to buying expensive helicopters")
    os.sleep(2)
    gpu.fill(1, line, screenWidth, line, ' ')  
end

gpu.fill(1, 1, screenWidth, screenHeight, ' ')  

local nowPlaying = tape.getLabel()

printCentered(3,'Now Playing')
printCentered(5, nowPlaying)

updateVisualizer()