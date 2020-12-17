local component = require("component")
local gpu = component.gpu
local event = require("event")
local tape = component.tape_drive

gpu.setResolution(48,16)
local screenWidth, screenHeight = gpu.getResolution()

local function printCentered(line, toPrint)
    local centerOffset = screenWidth/2 - string.len(toPrint)/2
    gpu.set(centerOffset, line, toPrint)
end

while true do
    local nowPlaying = "No Tape" 
    if tape.isReady() then
      nowPlaying = tape.getLabel()
    end
    gpu.fill(1, 1, screenWidth, screenHeight, ' ')
    if tape.getState() == "PLAYING" then
      printCentered(6,'Now Playing')
    else
      printCentered(12,'Paused')
    end
    printCentered(9, nowPlaying)
    os.sleep(5)
end