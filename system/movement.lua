-- movement.lua
-- Shared player collision and wall sliding
local Movement = {}

local UNSTUCK_DIRS = {
    {1, 0}, {-1, 0}, {0, 1}, {0, -1},
    {1, 1}, {-1, 1}, {1, -1}, {-1, -1}
}

local function aabbOverlap(a, b, padding)
    if not a or not b then return false end
    if not a.x or not a.y or not b.x or not b.y then return false end
    if not a.w or not a.h or not b.w or not b.h then return false end

    padding = padding or 0
    local ax1, ay1 = a.x + padding, a.y + padding
    local ax2, ay2 = a.x + a.w - padding, a.y + a.h - padding
    local bx1, by1 = b.x + padding, b.y + padding
    local bx2, by2 = b.x + b.w - padding, b.y + b.h - padding

    return ax1 < bx2 and bx1 < ax2 and ay1 < by2 and by1 < ay2
end

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

function Movement.resolveAabbCollisions(entities, padding)
    if not entities or #entities < 2 then return end

    for i = 1, #entities do
        local a = entities[i]
        if a and a.x ~= nil and a.y ~= nil and a.w and a.h then
            for j = i + 1, #entities do
                local b = entities[j]
                if b and b.x ~= nil and b.y ~= nil and b.w and b.h and aabbOverlap(a, b, padding) then
                    local ax1, ay1 = a.x, a.y
                    local ax2, ay2 = a.x + a.w, a.y + a.h
                    local bx1, by1 = b.x, b.y
                    local bx2, by2 = b.x + b.w, b.y + b.h

                    local overlapX = math.min(ax2, bx2) - math.max(ax1, bx1)
                    local overlapY = math.min(ay2, by2) - math.max(ay1, by1)

                    if overlapX < overlapY then
                        if ax1 < bx1 then
                            a.x = a.x - overlapX / 2
                            b.x = b.x + overlapX / 2
                        else
                            a.x = a.x + overlapX / 2
                            b.x = b.x - overlapX / 2
                        end
                    else
                        if ay1 < by1 then
                            a.y = a.y - overlapY / 2
                            b.y = b.y + overlapY / 2
                        else
                            a.y = a.y + overlapY / 2
                            b.y = b.y - overlapY / 2
                        end
                    end
                end
            end
        end
    end
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
