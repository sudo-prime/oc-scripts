local modem = component.proxy(component.list('modem')())
local PORT = 42069 -- something other than this
local THIS = '' -- an identifier for this device

modem.open(PORT)

while true do
    local event_type, _, _, _, _, recipient, event_body = computer.pullSignal()
    if event_type == "modem_message" and THIS == recipient then
        computer.beep(880, 0.03)
    end
end