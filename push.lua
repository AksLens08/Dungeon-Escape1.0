-- push.lua
-- Knockback math
local Push = {}

function Push.execute(actor, target, power, multiplier, isCritical)
    -- Force calc
    local totalPower = (power or 10) * (multiplier or 1)
    if isCritical then totalPower = totalPower * 2 end

    if not target or not target.x or not target.y then
        return nil, nil
    end

    -- Dir vector
    local dx = target.x - actor.x
    local dy = target.y - actor.y
    local mag = math.sqrt(dx * dx + dy * dy)

    if mag == 0 then mag = 1 end

    dx, dy = dx / mag, dy / mag

    return dx * totalPower, dy * totalPower
end

return Push
