-- movement.lua
-- Shared player collision and wall sliding
local Movement = {}

local UNSTUCK_DIRS = {
    {1, 0}, {-1, 0}, {0, 1}, {0, -1},
    {1, 1}, {-1, 1}, {1, -1}, {-1, -1}
}

local function resolveOverlap(entity, map)
    if not map:isColliding(entity.x, entity.y, entity.w, entity.h) then
        return
    end

    for dist = 1, 8 do
        for _, dir in ipairs(UNSTUCK_DIRS) do
            local nx = entity.x + dir[1] * dist
            local ny = entity.y + dir[2] * dist
            if not map:isColliding(nx, ny, entity.w, entity.h) then
                entity.x, entity.y = nx, ny
                entity.slideSide = nil
                return
            end
        end
    end
end

local function trySlideStep(entity, map, stepX, stepY)
    if stepX == 0 and stepY == 0 then
        return false
    end

    if not map:isColliding(entity.x + stepX, entity.y + stepY, entity.w, entity.h) then
        entity.x = entity.x + stepX
        entity.y = entity.y + stepY
        entity.slideSide = nil
        return true
    end

    local len = math.sqrt(stepX * stepX + stepY * stepY)
    if len == 0 then
        return false
    end

    local perpX = -stepY / len
    local perpY = stepX / len
    local dirX = stepX / len
    local dirY = stepY / len
    local candidates = {}

    local sideOrder = entity.slideSide == -1 and {-1, 1} or {1, -1}
    for offset = 0.5, 6, 0.5 do
        for _, side in ipairs(sideOrder) do
            local sidePenalty = entity.slideSide == side and 0 or 0.15
            table.insert(candidates, {
                x = stepX + perpX * offset * side,
                y = stepY + perpY * offset * side,
                penalty = offset * 0.03 + sidePenalty,
                side = side
            })
        end
    end

    local bestMove, bestScore = nil, -math.huge
    for _, move in ipairs(candidates) do
        local nextX = entity.x + move.x
        local nextY = entity.y + move.y
        if not map:isColliding(nextX, nextY, entity.w, entity.h) then
            local forward = move.x * dirX + move.y * dirY
            local score = forward - move.penalty
            if score > bestScore then
                bestMove = move
                bestScore = score
            end
        end
    end

    if bestMove then
        entity.x = entity.x + bestMove.x
        entity.y = entity.y + bestMove.y
        entity.slideSide = bestMove.side or entity.slideSide
        return true
    end

    return false
end

function Movement.moveWithCollision(entity, map, amountX, amountY)
    if amountX == 0 and amountY == 0 then
        return false
    end

    local startX, startY = entity.x, entity.y

    -- Axis-separated movement avoids corner snagging.
    if amountX ~= 0 then
        trySlideStep(entity, map, amountX, 0)
    end
    if amountY ~= 0 then
        trySlideStep(entity, map, 0, amountY)
    end

    if entity.x == startX and entity.y == startY then
        local steps = math.max(1, math.ceil(math.max(math.abs(amountX), math.abs(amountY))))
        local stepX = amountX / steps
        local stepY = amountY / steps
        for _ = 1, steps do
            trySlideStep(entity, map, stepX, stepY)
        end
    end

    local moved = entity.x ~= startX or entity.y ~= startY
    if not moved then
        entity.slideSide = nil
    end

    resolveOverlap(entity, map)
    return moved
end

return Movement
