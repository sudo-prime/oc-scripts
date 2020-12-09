local component = require('component')
local grid = component.block_refinedstorage_grid_0
local reactor = component.br_reactor
local powerCell = component.energy_device
local sides = require("sides")

local chestSide = sides.top

local function getUraniumTable()
    for _,item in ipairs(grid.getItems()) do
        if item["label"] == "Uranium Ingot" then
            return item
        end
    end
    return nil
end

local function getnumUranium()
    urTable = getUraniumTable()
    if urTable == nil then
        return nil
    else
        return urTable["size"]
    end
end

local function insertUranium(numInsert)
    grid.extractItem(getUraniumTable(), numInsert, chestSide)
end

local function fillReactor()
    local currentBars = (reactor.getFuelAmount() + reactor.getWasteAmount())/1000
    local maxBars = reactor.getFuelAmountMax()/1000
    insertUranium(maxBars-currentBars)
end

function measureRfUsage(interval)
    local var1 = powerCell.getEnergyStored()
    local var2
    local sum=0

    for x=1,interval,1 do
        os.sleep(0.05)
        var2 = powerCell.getEnergyStored()
        sum = sum + (var2-var1)
        var1 = var2
    end

    return sum/interval
end

function getEnergyPercentage()
    powerCell.getEnergyStored()
    powerCell.getMaxEnergyStored()

reactor.getEnergyProducedLastTick()