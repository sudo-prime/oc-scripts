local modem = component.proxy(component.list('modem')())
local gpu = component.proxy(component.list('gpu')())

modem.open(69)

while true do
    local event, _, sender, _, _, name, cmd, a, b, c = computer.pullSignal()
    gpu.set(0, 0, tostring({event, sender, name, cmd, a, b, c}))
    if event == "modem_message" then
        gpu.set(0, 1,'yum yum in my tum tum')
    end
end