local component = require("component")
local geolyzer = component.geolyzer
 
local offsetx = -1
local offsetz = -1
local offsety = -1
 
local sizex = 3
local sizez = 3
local sizey = 3
 
local map = {}
local scanData = geolyzer.scan(offsetx, offsetz, offsety, sizex, sizez, sizey)
local i = 1
for y = 0, sizey - 1 do
    for z = 0, sizez - 1 do
        for x = 0, sizex - 1 do
            -- alternatively when thinking in terms of 3-dimensional table: map[offsety + y][offsetz + z][offsetx + x] = scanData[i]
            map[i] = {posx = offsetx + x, posy = offsety + y, posz = offsetz + z, hardness = scanData[i]}
            i = i + 1
        end
    end
end
 
for i = 1, sizex*sizez*sizey do
    if map[i].hardness ~= 0 then
        print(map[i].posx, map[i].posy, map[i].posz, map[i].hardness)
    end
end