local component = require("component")
local event = require("event")
local modem = component.modem
local PORT = 42069
modem.open(PORT)
while true do
    modem.broadcast(PORT, "on")
    os.sleep(1)
end