-- dungeon.lua
local Class = require("class")
local Dungeon = Class.define()

function Dungeon:init(imagePath, tileSize)
    assert(imagePath, "You must provide a valid image path")
    self.tileSize = tileSize or 32
    self.gridSize = self.tileSize / 4 -- Increase resolution significantly for finer collision
    self.imageData = love.image.newImageData(imagePath)
    self.texture = love.graphics.newImage(self.imageData)
    self.width  = self.imageData:getWidth()
    self.height = self.imageData:getHeight()

    -- build collision map automatically
    self.collisionMap = {}
    self.walkableTiles = {}
    local tilesX = math.floor(self.width / self.gridSize)
    local tilesY = math.floor(self.height / self.gridSize)

    for ty = 1, tilesY do
        self.collisionMap[ty] = {}
        for tx = 1, tilesX do
            -- Scan the center and mid-points of the tile instead of every pixel
            -- This avoids getting stuck on 1px grid lines or aliased wall edges.
            local midX = math.floor((tx - 0.5) * self.gridSize)
            local midY = math.floor((ty - 0.5) * self.gridSize)
            
            midX = math.max(0, math.min(midX, self.width - 1))
            midY = math.max(0, math.min(midY, self.height - 1))

            local r, g, b, a = self.imageData:getPixel(midX, midY)
            -- A tile is blocked if the center pixel is dark or transparent
            local hasWall = (r < 0.1 and g < 0.1 and b < 0.1) or a < 0.1

            local isTileBlocked = hasWall
            self.collisionMap[ty][tx] = isTileBlocked
            
            -- Only add to walkableTiles if it is purely walkable floor
            if not isTileBlocked then
                table.insert(self.walkableTiles, {x = tx, y = ty})
            end
        end
    end
end

function Dungeon:isBlocked(x, y)
    local tileX = math.floor(x / self.gridSize) + 1
    local tileY = math.floor(y / self.gridSize) + 1
    
    -- Ensure out-of-bounds coordinates are treated as blocked
    if not self.collisionMap[tileY] or self.collisionMap[tileY][tileX] == nil then
        return true
    end
    return self.collisionMap[tileY][tileX]
end

function Dungeon:hasLineOfSight(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    local dist = math.sqrt(dx * dx + dy * dy)
    
    if dist < 1 then return true end

    -- We check points along the line every few pixels (half a grid size)
    -- to see if we hit a wall.
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
    -- Convert world coordinates to grid coordinates for the bounding box
    local startTileX = math.floor(x / self.gridSize) + 1
    local startTileY = math.floor(y / self.gridSize) + 1
    local endTileX = math.floor((x + w) / self.gridSize) + 1
    local endTileY = math.floor((y + h) / self.gridSize) + 1

    -- Iterate over all grid cells that the bounding box potentially overlaps
    for ty = startTileY, endTileY do
        for tx = startTileX, endTileX do
            -- Ensure out-of-bounds coordinates are treated as blocked
            if not self.collisionMap[ty] or self.collisionMap[ty][tx] == nil then
                return true
            end
            -- If any overlapping grid cell is blocked, then there's a collision
            if self.collisionMap[ty][tx] then
                return true
            end
        end
    end
    return false
end

function Dungeon:canFitAtCenter(x, y, w, h)
    if not w or not h then return true end
    return not self:isColliding(x - w / 2, y - h / 2, w, h)
end

function Dungeon:getRandomSpawnPoint(w, h)
    -- If no walkable tiles are found at all, return nil so we don't spawn in a wall
    if #self.walkableTiles == 0 then return nil end
    
    -- Shuffle walkable tiles to find a random valid spot quickly
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
        if self:canFitAtCenter(x, y, w, h) then
            return x, y
        end
    end

    -- Extreme Fallback: Return the first walkable tile center
    local fallback = self.walkableTiles[1]
    return (fallback.x - 0.5) * self.gridSize, (fallback.y - 0.5) * self.gridSize
end

function Dungeon:getCentralSpawnPoint(w, h)
    if #self.walkableTiles == 0 then return nil end

    local totalX, totalY = 0, 0
    for _, spot in ipairs(self.walkableTiles) do
        totalX = totalX + (spot.x - 0.5) * self.gridSize
        totalY = totalY + (spot.y - 0.5) * self.gridSize
    end

    local avgX = totalX / #self.walkableTiles
    local avgY = totalY / #self.walkableTiles

    local closestX, closestY = nil, nil
    local minDistSq = math.huge

    -- Iterate through walkable tiles to find the one closest to the average center
    -- that can fit the player's hitbox.
    for _, spot in ipairs(self.walkableTiles) do
        local tileCenterX = (spot.x - 0.5) * self.gridSize
        local tileCenterY = (spot.y - 0.5) * self.gridSize

        if self:canFitAtCenter(tileCenterX, tileCenterY, w, h) then
            local distSq = (tileCenterX - avgX)^2 + (tileCenterY - avgY)^2
            if distSq < minDistSq then
                minDistSq = distSq
                closestX = tileCenterX
                closestY = tileCenterY
            end
        end
    end

    -- Fallback to a random spawn point if no central spot can fit the hitbox
    return closestX or self:getRandomSpawnPoint(w, h), closestY or self:getRandomSpawnPoint(w, h)
end

function Dungeon:getRightmostSpawnPoint(w, h)
    -- 1. Find the absolute maximum X coordinate to identify the right edge
    local maxX = 0
    for _, spot in ipairs(self.walkableTiles) do
        if spot.x > maxX then maxX = spot.x end
    end

    -- 2. Filter walkable tiles to find those belonging to the rightmost room
    -- We define the "room" as any walkable tile within 4 full tiles of the max X
    local roomThreshold = (self.tileSize * 4) / self.gridSize
    local roomTiles = {}
    for _, spot in ipairs(self.walkableTiles) do
        local x = (spot.x - 0.5) * self.gridSize
        local y = (spot.y - 0.5) * self.gridSize
        if spot.x > (maxX - roomThreshold) and self:canFitAtCenter(x, y, w, h) then
            return x, y -- Return the first valid spot in the rightmost room
        end
    end

    if #roomTiles == 0 then
        return self:getRandomSpawnPoint(w, h)
    end

    -- 3. Pick a random spot from the gathered room tiles
    local spot = roomTiles[math.random(#roomTiles)]
    return (spot.x - 0.5) * self.gridSize, (spot.y - 0.5) * self.gridSize
end

function Dungeon:getLeftmostSpawnPoint(w, h)
    -- 1. Find the absolute minimum X coordinate to identify the left edge
    local minX = math.huge
    for _, spot in ipairs(self.walkableTiles) do
        if spot.x < minX then minX = spot.x end
    end

    -- 2. Filter walkable tiles to find those belonging to the leftmost room
    local roomThreshold = (self.tileSize * 4) / self.gridSize
    local validRoomSpawnPoints = {}
    for _, spot in ipairs(self.walkableTiles) do
        local tileCenterX = (spot.x - 0.5) * self.gridSize
        local tileCenterY = (spot.y - 0.5) * self.gridSize
        
        -- Check if the tile is within the leftmost room and the Knight can fit there
        if spot.x < (minX + roomThreshold) and self:canFitAtCenter(tileCenterX, tileCenterY, w, h) then
            table.insert(validRoomSpawnPoints, {x = tileCenterX, y = tileCenterY})
        end
    end

    if #validRoomSpawnPoints == 0 then return self:getRandomSpawnPoint(w, h) end
    local chosenSpot = validRoomSpawnPoints[math.random(#validRoomSpawnPoints)]
    return chosenSpot.x, chosenSpot.y
end

function Dungeon:render()
    -- Draw the base texture
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(self.texture, 0, 0)
end

return Dungeon
