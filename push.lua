-- push.lua
-- This file helps push things around
local Push = {}

-- Executes a knockback effect
-- actor: The source of the push
-- target: The entity being pushed
-- power: The base distance of the push
-- multiplier: Optional scaling (e.g., 0.5 for weak enemies)
-- isCritical: Optional boolean to double the push force
function Push.execute(actor, target, power, multiplier, isCritical)
    local totalPower = (power or 10) * (multiplier or 1)
    if isCritical then totalPower = totalPower * 2 end

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

    target.x = target.x + dx * totalPower
    target.y = target.y + dy * totalPower

    return true
end

return Push
