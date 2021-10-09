local component = require("component")
local event = require("event")
local modem = component.modem
local PORT = 2412
modem.open(PORT)
modem.broadcast(PORT, "drone=component.proxy(component.list('drone')())")
while true do
    local cmd=io.read()
    if not cmd then return end
    modem.broadcast(PORT, cmd)
    print(select(6, event.pull(5, "modem_message")))
end