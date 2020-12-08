local computer = require('computer')
local tone = {}

tone.mute = false

function tone.success()
    if not tone.mute then
        computer.beep(440)
        computer.beep(440)
        computer.beep(659.25)
    end
end

function tone.progress()
    if not tone.mute then
        computer.beep(440)
    end
end

function tone.error()
    if not tone.mute then
        computer.beep(196)
        computer.beep(196)
        computer.beep(196)
    end
end

return tone