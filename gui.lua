local component = require("component")
local gpu = component.gpu
local event = require("event")

local colorScreenBackground = 0xC0C0C0
local red = 0xFF0000
local green = 0x00FF00
local blue = 0x0000FF

local screenWidth, screenHeight = gpu.getResolution()

component.screen.setTouchModeInverted(true)

local gui = {}

local function makeButton(type, x, y, w, h, bg, fg, status, callback)
    local button ={
        type = type,
        x = x,
        y = y,
        width = w,
        height = h,
        bgColor = bg,
        fgColor = fg,
        status = status,
        callback = callback
    }
    return button
end

local function drawCheckBox(checkbox)
    local display
    if checkbox["state"] then
        display = '[√]'
    else
        display = '[ ]'
    end
    gpu.setBackground(checkbox["bgColor"])
    gpu.setForeground(checkbox["fgColor"])
    gpu.fill(checkbox["x"], checkbox["y"], checkbox["width"], checkbox["height"], ' ')
    gpu.set(checkbox["x"]+checkbox["width"]/2-1, checkbox["y"]+checkbox["height"]/2, '[√]')
end

local function makeCheckBox(x,y,bg,fg,toggle)
    local charNumWithSpacing = 5
    local lineNumWithSpacing = 3
    local defaultState = true
    checkbox = makeButton("check", 
                            x, y,
                            charNumWithSpacing, lineNumWithSpacing,
                            bg,fg,
                            defaultState, toggle)
    drawCheckBox(checkbox)
    table.insert(gui,checkbox)
end

makeCheckBox(20,20,red,green,1)

while true do
    local _,_, x, y = event.pull("touch", nil, nil)
    for _,button in pairs(gui) do
        if button['x'] <= x and (button['x'] + button['width']) >= x then
            if button['y'] <= y and (button['y'] + button['height']) >= y then
                button['callback']()
            end
        end
    end
end



--[[
    
for x,y in pairs(makeButton("check",1,1,1,1,"red","blue",1)) do print(x,y) end
gpu.setBackground(red)
gpu.fill(1, 1, screenWidth/2, screenHeight/2, ' ')

gpu.setBackground(blue)
gpu.fill(screenWidth/2, 1, screenWidth, screenHeight/2,' ')

gpu.setBackground(green)
gpu.fill(1, screenHeight/2, screenWidth, screenHeight,' ')]]--

--[[
    √ ║═╔╗╚╝
]]--
