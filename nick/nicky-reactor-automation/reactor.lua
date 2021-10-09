--[[
    reactor.lua

    An rc script, meant to be placed within /etc/rf.d
    and enabled via the command 'rc reactor enable'.

    REQUIREMENTS:
    1. Wireless network card of appropriate tier
    2. Adapter connected to a valid energy device

    Sends modem messages to devices on port PORT,
    when the given energy device either rises above
    off_threshold or drops below on_threshold. 
    These configuration settings can be found within 
    the reactor.cfg file and set before installation.
    Alternatively, the ON_THRESHOLD and OFF_THRESHOLD
    variables found below can be hard-coded, once again
    to numbers between 0 and 1 with 1 representing
]]--

local event = require('event')
local component = require('component')

local ON_THRESHOLD  = args.on_threshold
local OFF_THRESHOLD = args.off_threshold
local DELAY = args.delay
local PORT = args.port

local cell = component.energy_device
local modem = component.modem

local timer

local function getEnergyPercentage()
    return cell.getEnergyStored() / cell.getMaxEnergyStored()
end

local function sendOffMessage()
    modem.broadcast(PORT, 'reactor', 'OFF')
end

local function sendOnMessage()
    modem.broadcast(PORT, 'reactor', 'ON')
end

-- Called once every DELAY seconds by start()
local function update ()
    -- If energy exceeds OFF_THRESHOLD, turn reactor off
    if getEnergyPercentage() > OFF_THRESHOLD then
        sendOffMessage()
    -- If energy is below ON_THRESHOLD, turn reactor on
    elseif getEnergyPercentage() < ON_THRESHOLD then
        sendOnMessage()
    end
end

-- Gloabl rc start method
function start ()
    timer = event.timer(DELAY, update, math.huge)
end

-- Gloabl rc stop method
function stop ()
    if timer ~= nil then
        event.cancel(timer)
    end
end