local robot = require('robot')
local sides = require('sides')
local component = require('component')
local computer = require('computer')
local geolyzer = component.geolyzer

-- USER CONFIGURATION
local PLOTS_X = 2
local PLOTS_Z = 2
local CROP_LIST = {
    'harvestcraft:tomatoitem',
    'harvestcraft:bellpepperitem',
    'minecraft:wheat_seeds'
}
-- Specifies the dimensions of each crop plot.
-- A PLOT_SCALE * PLOT_SCALE area will be allotted for
-- each entry in CROP_LIST.
-- The x and z size of your farm will be this number 
-- multiplied by PLOTS_X and PLOTS_Z, respectively.
local PLOT_SCALE = 2
-- END USER CONFIGURATION

local PLOT_MAP = {}

-- Initialize a table which maps the robot's current
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
                print(string.format('Registered block at x%d, z%d, as being a plot of %s', x, z, CROP_LIST[crop_index]))
            end
        end
    end
end

local function main()
    initializePlots()
end

main()