--[[
    reactor-listener.lua

    A modem listener script compatible with
    microcontrollers (OpenOS not required).
    Emits a redstone signal on sides.top if
    it recieves a modem message on port PORT
    that has recipient THIS with event body
    'ON'. Turns said redstone signal off
    it it recieves the same message with any
    other message body.

    WARNING: In order to run this file, PORT
    must be modified. This is done by the install
    script by default, but the installer gives you
    the ability to skip installation of this file.
]]--

local modem = component.proxy(component.list('modem')())
local redstone = component.proxy(component.list('redstone')())

local PORT = nil -- MUST BE CHANGED

local THIS = 'reactor'

modem.open(PORT)

while true do
    local event_type, _, _, _, _, recipient, event_body = computer.pullSignal()
    if event_type == "modem_message" and THIS == recipient then
        if event_body == 'ON' then
            redstone.setOutput(1, 15) -- sides.top
        else
            redstone.setOutput(1, 0) -- sides.top
        end
    end
end