local modem = component.proxy(component.list('modem')())
local PORT = 42069
local THIS = 'reactor'

modem.open(PORT)

while true do
    local event_type, recipient, event_body = computer.pullSignal()
    if event_type == "modem_message" and THIS == recipient then
        computer.beep(880, 0.03)
    end
end