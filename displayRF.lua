local component = require("component")
local gpu = component.gpu
local event = require("event")
local powerCell = component.energy_device

gpu.setResolution(70,35)
local screenWidth, screenHeight = gpu.getResolution()

local red = 0xFF0000
local green = 0x00FF00
local black = 0x000000
local white = 0xffffff

gpu.fill(1, 1, screenWidth, screenHeight, ' ')

local function printCentered(line, toPrint)
    local centerOffset = screenWidth/2 - string.len(toPrint)/2
    gpu.set(centerOffset, line, toPrint)
end

function measureRfUsage(interval)
    local var1, var2
    local sum=0

    for x=1,interval,1 do
        var1 = powerCell.getEnergyStored()
        var2 = powerCell.getEnergyStored()
        sum = sum + (var2-var1)
    end
    return sum/interval
end

function updateRF(line)
    local usage = measureRfUsage(10)
    if usage >= 0 then
        gpu.setForeground(green)
    else
        gpu.setForeground(red)
    end

    usage = usage .. " rf/t"
    gpu.fill(1, line, screenWidth, line, ' ')
    printCentered(line,usage)
end

function getEnergyPercentage()
    return powerCell.getEnergyStored()/powerCell.getMaxEnergyStored()
end

function updateEnergyBar(line, margins)
    local percentage = getEnergyPercentage()
    local fullSize = screenWidth - (margins*2)
    local barSize = math.floor(percentage*fullSize + 0.5)

    gpu.setForeground(white)
    local energyDisplay = math.floor(powerCell.getEnergyStored()) .. "/" .. math.floor(powerCell.getMaxEnergyStored()) .. " rf"
    gpu.set(margins, line, energyDisplay)
    
    gpu.setBackground(white)
    gpu.fill(margins, line+1, screenWidth-(margins*2), line+3, ' ')

    gpu.setBackground(green)
    gpu.fill(margins, line+1, barSize, line+3, ' ')
    
    gpu.setBackground(black)
end


while true do
    updateEnergyBar(5,5)
    os.sleep(1)
end


--║═╔ ╗╚ ╝