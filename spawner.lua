-- spawner.lua
-- Handles validating and generating safe enemy spawn positions
local Spawner = {}

local function isValidFloorTile(dungeon, x, y)
    if not dungeon or not dungeon.collisionMap then
        return false
    end

    local tileX = math.floor(x / dungeon.gridSize) + 1
    local tileY = math.floor(y / dungeon.gridSize) + 1

    if not dungeon.collisionMap[tileY] or dungeon.collisionMap[tileY][tileX] == nil then
        return false
    end

    return dungeon.collisionMap[tileY][tileX] == false
end

function Spawner.getValidSpawnPoint(dungeon, w, h, padding, maxAttempts)
    if not dungeon or not dungeon.walkableTiles or #dungeon.walkableTiles == 0 then
        return nil, nil
    end

    padding = padding or 0
    maxAttempts = maxAttempts or 50
    local attempts = 0

    while attempts < maxAttempts do
        attempts = attempts + 1
        local spot = dungeon.walkableTiles[math.random(#dungeon.walkableTiles)]
        if not spot then
            break
        end

        local x = (spot.x - 0.5) * dungeon.gridSize
        local y = (spot.y - 0.5) * dungeon.gridSize

        if isValidFloorTile(dungeon, x, y) and dungeon:canFitAtCenter(x, y, w, h, padding) then
            return x, y
        end
    end

    return nil, nil
end

return Spawner