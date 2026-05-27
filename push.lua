-- push.lua
-- This file helps push things around
local Push = {}
function Push.execute(actor, target, power)
    power = power or 10

    if not target or not target.x or not target.y then
        return false
    end

    -- Figure out which way to push
    local dx = target.x - actor.x
    local dy = target.y - actor.y
    local mag = math.sqrt(dx * dx + dy * dy)

    if mag == 0 then return false end

    -- Normalized displacement
    dx, dy = dx / mag, dy / mag

    target.x = target.x + dx * power
    target.y = target.y + dy * power

    return true
end

return Push
