local component = require('component')
local powerCell = component.energy_device


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

while true do
    print(measureRfUsage(5))
end