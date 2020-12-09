--[[

farm-2d.lua

Farms a plot of rectangular land.

REQUIREMENTS:
1. Geolyzer
2. Inventory Controller
3. Speech Upgrade

The robot must be placed one block above the crops,
on top of a charger, facing the first (upper-most) row of crops.

The robot assumes that the land below them is plantable.
This allows for growing crops that don't grow on dirt,
i.e. nether wart. To use this robot, till the land it is
going to farm, if needed.

By default, the robot farms a 9x9 area consisting of 9 square
plots. The shape of each plot is always a square. However,
The farm itself can contain a different number of plots in
each direction. You can change the plot size and number of
plots in each direction by modifying PLOT_SCALE, PLOTS_X,
and PLOTS_Z, respectively.

Written by Nick V.

--]]


local robot = require('robot')
local sides = require('sides')
local component = require('component')
local computer = require('computer')
local geolyzer = component.geolyzer
local inventory_controller = component.inventory_controller
local speech_box = component.speech

-- USER CONFIGURATION
local PLOTS_X = 3   -- Number of plots in the X direction
local PLOTS_Z = 3   -- Number of plots in the Y direction
-- Specifies the dimensions of each crop plot.
-- A PLOT_SCALE * PLOT_SCALE area will be allotted for
-- each entry in CROP_LIST.
-- The x and z size of your farm will be this number
-- multiplied by PLOTS_X and PLOTS_Z, respectively.
local PLOT_SCALE = 3
-- List of plantable items for each plot.
-- Crops are listed in the form of a flattened
-- 2d list, left-to-right followed by top-to-bottom
-- (where the top-left most plot is closest to the charger).
-- If no crop is listed for a plot, adult crops will be
-- harvested but NOT re-planted.
local CROP_LIST = {
    'harvestcraft:tomatoitem',
    'harvestcraft:bellpepperitem',
    'minecraft:wheat_seeds',
    'harvestcraft:spiceleafitem',
    'harvestcraft:onionitem',
    'minecraft:potato',
    'harvestcraft:lettuceitem',
    'harvestcraft:garlicitem',
    'minecraft:carrot'
}
local PHRASES = {
    'Step aside please.',
    'Get out of the way.',
    'Let me through please.',
    'You are blocking my path.',
    'Move out of the fucking way you god damn degenerate moron.',
    'I will wait. You\'re wasting your time.'
}
local SLEEP_DURATION = 120  -- Number of seconds the robot will wait
                            -- after each harvest.

-- END USER CONFIGURATION --


local PLOT_MAP = {}     -- See initializePlots().
local DIRECTION = '+X'  -- Which direction the robot is facing,
                        -- relative to starting direction
local tone = {}         -- Used for informative beeps
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
local PHRASE = 1


-- Initialize PLOT_MAP, which maps the robot's current
-- relative X and Y location to an item id. This id corresponds
-- to the seed or crop which the plot at this X and Y location
-- is growing.
local function initializePlots()
    for z = 1, PLOTS_Z * PLOT_SCALE do
        PLOT_MAP[z] = {}
        for x = 1, PLOTS_X * PLOT_SCALE do
            --4d gigabrain shit
            local plot_index_x = math.ceil(x / PLOT_SCALE)
            local plot_index_z = math.ceil(z / PLOT_SCALE)
            local crop_index = (plot_index_z - 1) * PLOTS_X + plot_index_x
            if crop_index > #CROP_LIST then
                PLOT_MAP[z][x] = nil
            else
                PLOT_MAP[z][x] = CROP_LIST[crop_index]
            end
        end
    end
end

-- Searches for item with id item_id.
-- If found, it is selected and equipped.
local function find_and_equip(item_id)
    -- First, check the robot's inventory.
    for i = 1, robot.inventorySize() do
        item_stack = inventory_controller.getStackInInternalSlot(i)
        if item_stack ~= nil then -- There's an item here
            if item_stack.name == item_id then -- It's the one we're looking for
                robot.select(i)
                inventory_controller.equip()
                return true
            end
        end
    end
    -- At this point, no item in the robot's inventory
    -- matches the item id we're searching for.
    -- Still need to check what the robot's holding.
    inventory_controller.equip()
    local item_stack = inventory_controller.getStackInInternalSlot()
    inventory_controller.equip() -- Undo previous equip
    if item_stack ~= nil then
        if item_stack.name == item_id then
            return true
        end
    end
    return false
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

-- Attempts to move forward until a successful call is made.
-- Prevents location desync due to player or environmental
-- obstructions.
-- Also politely asks the player to move, if obstructed.
local function forwardUntilSuccess()
    local success = robot.forward()
    local was_obstructed = false
    while not success do
        tone.error()
        os.sleep(1)
        was_obstructed = true
        if PHRASE <= #PHRASES then
            speech_box.say(PHRASES[PHRASE])
            os.sleep(5)
            PHRASE = PHRASE + 1
        end
        success = robot.forward()
    end
    PHRASE = 1
    if was_obstructed then
        speech_box.say('Thank you.')
        os.sleep(3)
    end
end

-- Entry point
local function main()
    initializePlots()
    tone.success()
    while true do
        -- Step off of the charger.
        forwardUntilSuccess()
        -- For each block in the x and y direction,
        for z = 1, PLOTS_Z * PLOT_SCALE do
            for x = 1, PLOTS_X * PLOT_SCALE do
                -- Determine what's below the robot.
                local below = geolyzer.analyze(sides.bottom)
                local crop
                -- Depending on the direction we are moving,
                -- we may or may not flip the X axis to find the crop
                if DIRECTION == '+X' then
                    crop = PLOT_MAP[z][x]
                else
                    -- We're going right to left, not left to right
                    -- Read crops going in that direction
                    crop = PLOT_MAP[z][PLOTS_X * PLOT_SCALE - (x - 1)]
                end
                if below.name == 'minecraft:air' then
                    -- There's nothing below the robot
                    if crop ~= nil then
                        if find_and_equip(crop) then
                            -- Plant the appropriate crop
                            robot.useDown()
                        end
                    end
                else
                    -- There's something, probably a crop, below the robot
                    -- Check growth level
                    if below.growth == 1.0 then
                        -- Crop is fully grown, harvest it and re-plant
                        tone.progress()
                        robot.swingDown()
                        if crop ~= nil then
                            if find_and_equip(crop) then
                                -- Plant the appropriate crop
                                robot.useDown()
                            end
                        end
                    end
                end
                if x < PLOTS_X * PLOT_SCALE then
                    forwardUntilSuccess()
                end
            end
            -- Position the robot to harvest the next row,
            -- so long as we aren't on the last row
            if z < PLOTS_Z * PLOT_SCALE then
                if DIRECTION == '+X' then
                    robot.turnRight()
                    forwardUntilSuccess()
                    robot.turnRight()
                    DIRECTION = '-X'
                else
                    robot.turnLeft()
                    forwardUntilSuccess()
                    robot.turnLeft()
                    DIRECTION = '+X'
                end
            end
        end
        -- The robot has now traversed each plot,
        -- so head home (taking into account which way
        -- the robot was going)
        if DIRECTION == '+X' then
            -- Robot was moving away from home in the X direction
            robot.turnAround()
            for x = 1, PLOTS_X * PLOT_SCALE - 1 do
                forwardUntilSuccess()
            end
        end
        robot.turnRight()
        for z = 1, PLOTS_Z * PLOT_SCALE - 2 do
            forwardUntilSuccess()
        end
        robot.turnLeft()
        forwardUntilSuccess()
        robot.turnRight()
        -- Transfer items to the chest
        assert(transferInventory(sides.bottom), 'No more inventory sapce!')
        forwardUntilSuccess()
        robot.turnRight()
        -- At the end of this loop, the robot must be
        -- above its charger and facing the first row
        -- of crops in the X direction
        print("Sleeping...")
        os.sleep(SLEEP_DURATION)
    end
end

main()