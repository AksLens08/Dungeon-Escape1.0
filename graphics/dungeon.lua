-- dungeon.lua
-- Map and collisions
local Class = require("system.class")
local Dungeon = Class.define()

function Dungeon:init(imagePath, tileSize)
    assert(imagePath, "You must provide a valid image path")
    self.tileSize = tileSize or 32 
    self.gridSize = self.tileSize / 4
    self.imageData = love.image.newImageData(imagePath)
    self.texture = love.graphics.newImage(self.imageData)
    self.width  = self.imageData:getWidth()
    self.height = self.imageData:getHeight()

    self.collisionMap = {}
    self.walkableTiles = {}
    local tilesX = math.floor(self.width / self.gridSize)
    local tilesY = math.floor(self.height / self.gridSize)

    -- Build collision grid
    for ty = 1, tilesY do
        self.collisionMap[ty] = {}
        for tx = 1, tilesX do
            local midX = math.floor((tx - 0.5) * self.gridSize)
            local midY = math.floor((ty - 0.5) * self.gridSize)
            
            midX = math.max(0, math.min(midX, self.width - 1))
            midY = math.max(0, math.min(midY, self.height - 1))

            local r, g, b, a = self.imageData:getPixel(midX, midY)
            local brightness = (r + g + b) / 3
            local hasWall = (brightness < 0.5) or a <= 0.05

            local isTileBlocked = hasWall
            self.collisionMap[ty][tx] = isTileBlocked
            
            if not isTileBlocked then
                table.insert(self.walkableTiles, {x = tx, y = ty})
            end
        end
    end
end

function Dungeon:isBlocked(x, y)
    -- Grid check
    local tileX = math.floor(x / self.gridSize) + 1
    local tileY = math.floor(y / self.gridSize) + 1
    
    if not self.collisionMap[tileY] or self.collisionMap[tileY][tileX] == nil then
        return true
    end
    return self.collisionMap[tileY][tileX]
end

function Dungeon:hasLineOfSight(x1, y1, x2, y2)
    -- LOS raycast
    local dx = x2 - x1
    local dy = y2 - y1
    local dist = math.sqrt(dx * dx + dy * dy)
    
    if dist < 1 then return true end

    local stepSize = self.gridSize / 2
    local steps = math.floor(dist / stepSize)
    
    for i = 1, steps do
        local tx = x1 + (dx / dist) * (i * stepSize)
        local ty = y1 + (dy / dist) * (i * stepSize)
        if self:isBlocked(tx, ty) then
            return false
        end
    end
    return true
end

function Dungeon:isColliding(x, y, w, h)
    -- AABB grid check
    if x < 0 or y < 0 or x + w > self.width or y + h > self.height then
        return true
    end

    local margin = 0.1
    local startTileX = math.floor((x + margin) / self.gridSize) + 1
    local startTileY = math.floor((y + margin) / self.gridSize) + 1
    local endTileX = math.floor((x + w - 1 - margin) / self.gridSize) + 1
    local endTileY = math.floor((y + h - 1 - margin) / self.gridSize) + 1

    for ty = startTileY, endTileY do
        for tx = startTileX, endTileX do
            if not self.collisionMap[ty] or self.collisionMap[ty][tx] == nil then
                return true
            end
            if self.collisionMap[ty][tx] then
                return true
            end
        end
    end
    return false
end

function Dungeon:canFitAtCenter(x, y, w, h, padding)
    -- Center fit check
    if not w or not h then return true end
    padding = padding or 0

    local left = x - w / 2
    local top = y - h / 2
    if left < padding or top < padding or left + w > self.width - padding or top + h > self.height - padding then
        return false
    end

    return not self:isColliding(x - w / 2, y - h / 2, w, h)
end

function Dungeon:getRandomSpawnPoint(w, h, padding)
    -- Get random spot
    if #self.walkableTiles == 0 then return nil end
    padding = padding or 0
    
    local indices = {}
    for i = 1, #self.walkableTiles do table.insert(indices, i) end
    for i = #indices, 2, -1 do
        local j = math.random(i)
        indices[i], indices[j] = indices[j], indices[i]
    end

    for _, idx in ipairs(indices) do
        local spot = self.walkableTiles[idx]
        local x = (spot.x - 0.5) * self.gridSize
        local y = (spot.y - 0.5) * self.gridSize
        if self:canFitAtCenter(x, y, w, h, padding) then
            return x, y
        end
    end

    return nil
end

function Dungeon:getRightmostSpawnPoint(w, h, padding)
    -- Get boss room spot
    if #self.walkableTiles == 0 then return nil end
    padding = padding or 0

    local maxX = 0
    for _, spot in ipairs(self.walkableTiles) do
        if spot.x > maxX then maxX = spot.x end
    end

    local roomThreshold = (self.tileSize * 4) / self.gridSize
    local roomTiles = {}
    for _, spot in ipairs(self.walkableTiles) do
        local x = (spot.x - 0.5) * self.gridSize
        local y = (spot.y - 0.5) * self.gridSize
        if spot.x > (maxX - roomThreshold) and self:canFitAtCenter(x, y, w, h, padding) then
            table.insert(roomTiles, {x = x, y = y})
        end
    end

    if #roomTiles == 0 then
        return self:getRandomSpawnPoint(w, h, padding)
    end

    local spot = roomTiles[math.random(#roomTiles)]
    return spot.x, spot.y
end

function Dungeon:getLeftmostSpawnPoint(w, h, padding)
    -- Get safe room spot
    if #self.walkableTiles == 0 then return nil end
    padding = padding or 0

    local minX = math.huge
    for _, spot in ipairs(self.walkableTiles) do
        if spot.x < minX then minX = spot.x end
    end

    local roomThreshold = (self.tileSize * 4) / self.gridSize
    local validRoomSpawnPoints = {}
    for _, spot in ipairs(self.walkableTiles) do
        local tileCenterX = (spot.x - 0.5) * self.gridSize
        local tileCenterY = (spot.y - 0.5) * self.gridSize
        
        if spot.x < (minX + roomThreshold) and self:canFitAtCenter(tileCenterX, tileCenterY, w, h, padding) then
            table.insert(validRoomSpawnPoints, {x = tileCenterX, y = tileCenterY})
        end
    end

    if #validRoomSpawnPoints == 0 then return self:getRandomSpawnPoint(w, h, padding) end
    local chosenSpot = validRoomSpawnPoints[math.random(#validRoomSpawnPoints)]
    return chosenSpot.x, chosenSpot.y
end

function Dungeon:getSpawnPointsOutsideSafeRoom(count, w, h, padding, knightX, knightY)
    -- Get world spawns, avoiding the Knight's starting room
    if #self.walkableTiles == 0 then return {} end
    padding = padding or 0
    knightX = knightX or 0
    knightY = knightY or 0

    -- JUICE: Set the safe radius around the Knight (adjust this number if needed)
    local safeRadius = 120 

    local outsideSafeRoomTiles = {}
    for _, spot in ipairs(self.walkableTiles) do
        local x = (spot.x - 0.5) * self.gridSize
        local y = (spot.y - 0.5) * self.gridSize
        
        -- Only add tiles that are far enough away from the Knight
        local distSq = (x - knightX)^2 + (y - knightY)^2
        if distSq > safeRadius * safeRadius then
            table.insert(outsideSafeRoomTiles, spot)
        end
    end

    if #outsideSafeRoomTiles == 0 then return {} end

    local results = {}
    local attempts = 0
    while #results < count and attempts < count * 5 do
        attempts = attempts + 1
        local spot = outsideSafeRoomTiles[math.random(#outsideSafeRoomTiles)]
        local x = (spot.x - 0.5) * self.gridSize
        local y = (spot.y - 0.5) * self.gridSize

        if self:canFitAtCenter(x, y, w, h, padding) then
            local alreadyAdded = false
            for _, existingSpot in ipairs(results) do
                if math.abs(existingSpot.x - x) < 1 and math.abs(existingSpot.y - y) < 1 then alreadyAdded = true; break end
            end
            if not alreadyAdded then
                table.insert(results, {x = x, y = y})
            end
        end
    end
    return results
end

function Dungeon:render()
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(self.texture, 0, 0)
end

return Dungeon