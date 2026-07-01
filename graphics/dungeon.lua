-- dungeon.lua
-- Enhanced procedural dungeon with improved pathfinding and visuals
local Class = require("system.class")
local Dungeon = Class.define()

function Dungeon:init(imagePath, tileSize)
    self.tileSize = tileSize or 32 
    self.gridSize = self.tileSize / 4
    
    self.rooms = {}
    self.walkableMap = {}
    self.pillars = {}
    self.waterPuddles = {}
    self:generateProceduralDungeon()
    
    self.collisionMap = {}
    self.walkableTiles = {}
    local tilesX = math.floor(self.width / self.gridSize)
    local tilesY = math.floor(self.height / self.gridSize)

    for ty = 1, tilesY do
        self.collisionMap[ty] = {}
        for tx = 1, tilesX do
            local midX = math.floor((tx - 0.5) * self.gridSize)
            local midY = math.floor((ty - 0.5) * self.gridSize)
            
            midX = math.max(0, math.min(midX, self.width - 1))
            midY = math.max(0, math.min(midY, self.height - 1))

            local isWalkable = self.walkableMap[midY] and self.walkableMap[midY][midX]
            self.collisionMap[ty][tx] = not isWalkable
            
            if isWalkable then
                table.insert(self.walkableTiles, {x = tx, y = ty})
            end
        end
    end
end

function Dungeon:generateProceduralDungeon()
    self.width = 600
    self.height = 600
    
    self.imageData = love.image.newImageData(self.width, self.height)
    
    self.walkableMap = {}
    for y = 0, self.height - 1 do
        self.walkableMap[y] = {}
        for x = 0, self.width - 1 do
            self.walkableMap[y][x] = false
        end
    end
    
    self.imageData:mapPixel(function(x, y)
        return 0, 0, 0, 1
    end)
    
    self:generateWallTexture()
    
    local minRoomSize = 100
    local maxRoomSize = 160
    local maxAttempts = 100
    local targetRooms = 10
    local padding = 40
    
    for attempt = 1, maxAttempts do
        if #self.rooms >= targetRooms then break end
        
        local roomW = math.random(minRoomSize, maxRoomSize)
        local roomH = math.random(minRoomSize, maxRoomSize)
        local roomX = math.random(padding, self.width - roomW - padding)
        local roomY = math.random(padding, self.height - roomH - padding)
        
        local overlaps = false
        for _, existingRoom in ipairs(self.rooms) do
            if self:rectsOverlap(
                roomX - padding, roomY - padding, roomW + padding*2, roomH + padding*2,
                existingRoom.x, existingRoom.y, existingRoom.w, existingRoom.h
            ) then
                overlaps = true
                break
            end
        end
        
        if not overlaps then
            self:carveRoom(roomX, roomY, roomW, roomH)
            table.insert(self.rooms, {
                x = roomX,
                y = roomY,
                w = roomW,
                h = roomH,
                cx = roomX + roomW / 2,
                cy = roomY + roomH / 2
            })
        end
    end
    
    table.sort(self.rooms, function(a, b)
        if math.abs(a.cx - b.cx) < 100 then
            return a.cy < b.cy
        else
            return a.cx < b.cx
        end
    end)
    
    for i = 1, #self.rooms - 1 do
        self:carveCorridor(
            self.rooms[i].cx,
            self.rooms[i].cy,
            self.rooms[i + 1].cx,
            self.rooms[i + 1].cy
        )
    end
    
    if #self.rooms > 0 then
        local firstRoom = self.rooms[1]
        firstRoom.w = 140
        firstRoom.h = 140
        firstRoom.cx = firstRoom.x + firstRoom.w / 2
        firstRoom.cy = firstRoom.y + firstRoom.h / 2
        self:carveRoom(firstRoom.x, firstRoom.y, firstRoom.w, firstRoom.h)
    end
    
    if #self.rooms > 0 then
        local lastRoom = self.rooms[#self.rooms]
        lastRoom.w = 180
        lastRoom.h = 180
        lastRoom.cx = lastRoom.x + lastRoom.w / 2
        lastRoom.cy = lastRoom.y + lastRoom.h / 2
        self:carveRoom(lastRoom.x, lastRoom.y, lastRoom.w, lastRoom.h)
    end
    
    self:addDecorations()
    self:addWaterPuddles()
    
    -- NEW: Add smooth edge transitions between walls and floors
    self:addEdgeTransitions()
    
    self.texture = love.graphics.newImage(self.imageData)
end

function Dungeon:generateWallTexture()
    for y = 0, self.height - 1 do
        for x = 0, self.width - 1 do
            local noise1 = love.math.noise(x * 0.02, y * 0.02) * 0.3
            local noise2 = love.math.noise(x * 0.08, y * 0.08) * 0.15
            local noise3 = love.math.noise(x * 0.15, y * 0.15) * 0.08
            
            -- ENHANCED: Darker base walls for better contrast with floors
            local baseColor = 0.12 + noise1 + noise2 + noise3
            
            local brickWidth = 32
            local brickHeight = 16
            local brickRow = math.floor(y / brickHeight)
            local brickOffset = (brickRow % 2) * (brickWidth / 2)
            local brickX = (x + brickOffset) % brickWidth
            local brickY = y % brickHeight
            
            local isMortar = (brickX < 2) or (brickY < 2)
            
            local crackNoise = love.math.noise(x * 0.3, y * 0.3)
            local hasCrack = crackNoise > 0.85
            
            local mossNoise = love.math.noise(x * 0.05, y * 0.05)
            local hasMoss = mossNoise > 0.75
            
            local stainNoise = love.math.noise(x * 0.1, y * 0.1)
            local hasStain = stainNoise > 0.8
            
            local finalR = baseColor
            local finalG = baseColor
            local finalB = baseColor * 1.05
            
            if isMortar then
                finalR = finalR * 0.3
                finalG = finalG * 0.3
                finalB = finalB * 0.3
            end
            
            if hasCrack and not isMortar then
                finalR = finalR * 0.5
                finalG = finalG * 0.5
                finalB = finalB * 0.5
            end
            
            if hasMoss and not isMortar then
                finalR = finalR * 0.6
                finalG = finalG * 1.3
                finalB = finalB * 0.6
            end
            
            if hasStain and not isMortar then
                finalR = finalR * 0.7
                finalG = finalG * 0.75
                finalB = finalB * 0.8
            end
            
            self.imageData:setPixel(x, y, finalR, finalG, finalB, 1)
        end
    end
end

function Dungeon:rectsOverlap(x1, y1, w1, h1, x2, y2, w2, h2)
    return x1 < x2 + w2 and x1 + w1 > x2 and y1 < y2 + h2 and y1 + h1 > y2
end

function Dungeon:carveRoom(x, y, w, h)
    local floorType = math.random(1, 4)
    
    local margin = 2
    for py = y + margin, y + h - margin do
        for px = x + margin, x + w - margin do
            if px >= 0 and px < self.width and py >= 0 and py < self.height then
                self.walkableMap[py][px] = true
            end
        end
    end
    
    for py = y, y + h do
        for px = x, x + w do
            if px >= 0 and px < self.width and py >= 0 and py < self.height then
                local noise1 = love.math.noise(px * 0.03, py * 0.03) * 0.2
                local noise2 = love.math.noise(px * 0.1, py * 0.1) * 0.1
                local noise3 = love.math.noise(px * 0.2, py * 0.2) * 0.05
                
                local tileSize = 20
                local tileX = px % tileSize
                local tileY = py % tileSize
                local isTileEdge = (tileX < 2) or (tileY < 2)
                
                local colorVariation = love.math.noise(px * 0.01, py * 0.01) * 0.1
                
                local baseR, baseG, baseB
                if floorType == 1 then
                    -- ENHANCED: Brighter, warmer floors
                    baseR = 0.72 + noise1 + noise2 + colorVariation
                    baseG = 0.64 + noise1 + noise2 + colorVariation
                    baseB = 0.55 + noise1 + noise2 + colorVariation
                elseif floorType == 2 then
                    baseR = 0.58 + noise1 + noise2 + colorVariation
                    baseG = 0.52 + noise1 + noise2 + colorVariation
                    baseB = 0.46 + noise1 + noise2 + colorVariation
                elseif floorType == 3 then
                    baseR = 0.76 + noise1 + noise2 + colorVariation
                    baseG = 0.56 + noise1 + noise2 + colorVariation
                    baseB = 0.50 + noise1 + noise2 + colorVariation
                else
                    baseR = 0.62 + noise1 + noise2 + colorVariation
                    baseG = 0.72 + noise1 + noise2 + colorVariation
                    baseB = 0.56 + noise1 + noise2 + colorVariation
                end
                
                if isTileEdge then
                    baseR = baseR * 0.80
                    baseG = baseG * 0.80
                    baseB = baseB * 0.80
                end
                
                local stainNoise = love.math.noise(px * 0.15, py * 0.15)
                if stainNoise > 0.88 then
                    baseR = baseR * 0.75
                    baseG = baseG * 0.70
                    baseB = baseB * 0.65
                elseif stainNoise > 0.85 then
                    baseR = baseR * 1.1
                    baseG = baseG * 0.65
                    baseB = baseB * 0.65
                end
                
                self.imageData:setPixel(px, py, baseR, baseG, baseB, 1)
            end
        end
    end
    
    self:addWallShadow(x, y, w, h)
end

function Dungeon:addWaterPuddles()
    for _, room in ipairs(self.rooms) do
        if math.random() > 0.5 then
            local puddleX = room.x + math.random(20, room.w - 20)
            local puddleY = room.y + math.random(20, room.h - 20)
            local puddleRadius = math.random(8, 12)
            
            self:drawWaterPuddle(puddleX, puddleY, puddleRadius)
            table.insert(self.waterPuddles, {x = puddleX, y = puddleY, r = puddleRadius})
        end
    end
end

function Dungeon:drawWaterPuddle(x, y, radius)
    for py = y - radius, y + radius do
        for px = x - radius, x + radius do
            if px >= 0 and px < self.width and py >= 0 and py < self.height then
                local dist = math.sqrt((px - x)^2 + (py - y)^2)
                if dist <= radius then
                    local noise = love.math.noise(px * 0.15, py * 0.15) * 0.1
                    local baseR = 0.30 + noise
                    local baseG = 0.40 + noise
                    local baseB = 0.60 + noise
                    
                    local shimmer = math.sin(px * 0.1) * math.cos(py * 0.1) * 0.1
                    baseR = baseR + shimmer
                    baseG = baseG + shimmer
                    baseB = baseB + shimmer * 1.5
                    
                    self.imageData:setPixel(px, py, baseR, baseG, baseB, 1)
                end
            end
        end
    end
end

function Dungeon:addWallShadow(x, y, w, h)
    local shadowSize = 10  -- ENHANCED: Larger shadow for smoother transition
    for i = 1, shadowSize do
        -- ENHANCED: Smoother falloff curve
        local alpha = ((shadowSize - i) / shadowSize)^1.5 * 0.5
        
        for px = x, x + w do
            if px >= 0 and px < self.width then
                local topY = y + i
                if topY >= 0 and topY < self.height then
                    local r, g, b, a = self.imageData:getPixel(px, topY)
                    self.imageData:setPixel(px, topY, r * (1 - alpha), g * (1 - alpha), b * (1 - alpha), a or 1)
                end
                
                local bottomY = y + h - i
                if bottomY >= 0 and bottomY < self.height then
                    local r, g, b, a = self.imageData:getPixel(px, bottomY)
                    self.imageData:setPixel(px, bottomY, r * (1 - alpha), g * (1 - alpha), b * (1 - alpha), a or 1)
                end
            end
        end
        
        for py = y, y + h do
            if py >= 0 and py < self.height then
                local leftX = x + i
                if leftX >= 0 and leftX < self.width then
                    local r, g, b, a = self.imageData:getPixel(leftX, py)
                    self.imageData:setPixel(leftX, py, r * (1 - alpha), g * (1 - alpha), b * (1 - alpha), a or 1)
                end
                
                local rightX = x + w - i
                if rightX >= 0 and rightX < self.width then
                    local r, g, b, a = self.imageData:getPixel(rightX, py)
                    self.imageData:setPixel(rightX, py, r * (1 - alpha), g * (1 - alpha), b * (1 - alpha), a or 1)
                end
            end
        end
    end
end

function Dungeon:carveCorridor(x1, y1, x2, y2)
    local corridorWidth = 40
    
    local minX, maxX = math.min(x1, x2), math.max(x1, x2)
    local minY, maxY = math.min(y1, y2), math.max(y1, y2)
    
    for x = minX, maxX do
        for yOffset = -corridorWidth/2, corridorWidth/2 do
            local y = math.floor(y1 + yOffset)
            if x >= 0 and x < self.width and y >= 0 and y < self.height then
                if self.walkableMap[y] then
                    self.walkableMap[y][x] = true
                end
            end
        end
    end
    
    for y = minY, maxY do
        for xOffset = -corridorWidth/2, corridorWidth/2 do
            local x = math.floor(x2 + xOffset)
            if x >= 0 and x < self.width and y >= 0 and y < self.height then
                if self.walkableMap[math.floor(y)] then
                    self.walkableMap[math.floor(y)][x] = true
                end
            end
        end
    end
    
    for x = minX, maxX do
        for yOffset = -corridorWidth/2, corridorWidth/2 do
            local y = math.floor(y1 + yOffset)
            if x >= 0 and x < self.width and y >= 0 and y < self.height then
                local noise = love.math.noise(x * 0.08, y * 0.08) * 0.15
                -- ENHANCED: Brighter corridor floors
                local baseR = 0.60 + noise
                local baseG = 0.53 + noise
                local baseB = 0.46 + noise
                
                local distFromCenter = math.abs(y - y1) / (corridorWidth / 2)
                if distFromCenter > 0.75 then
                    local darkening = 0.85 - (distFromCenter - 0.75) * 0.6
                    baseR = baseR * darkening
                    baseG = baseG * darkening
                    baseB = baseB * darkening
                end
                
                self.imageData:setPixel(x, y, baseR, baseG, baseB, 1)
            end
        end
    end
    
    for y = minY, maxY do
        for xOffset = -corridorWidth/2, corridorWidth/2 do
            local x = math.floor(x2 + xOffset)
            if x >= 0 and x < self.width and y >= 0 and y < self.height then
                local noise = love.math.noise(x * 0.08, y * 0.08) * 0.15
                local baseR = 0.60 + noise
                local baseG = 0.53 + noise
                local baseB = 0.46 + noise
                
                local distFromCenter = math.abs(x - x2) / (corridorWidth / 2)
                if distFromCenter > 0.75 then
                    local darkening = 0.85 - (distFromCenter - 0.75) * 0.6
                    baseR = baseR * darkening
                    baseG = baseG * darkening
                    baseB = baseB * darkening
                end
                
                self.imageData:setPixel(x, math.floor(y), baseR, baseG, baseB, 1)
            end
        end
    end
end

function Dungeon:addDecorations()
    for _, room in ipairs(self.rooms) do
        local torchPositions = {
            {room.x + 10, room.y + 10},
            {room.x + room.w - 10, room.y + 10},
            {room.x + 10, room.y + room.h - 10},
            {room.x + room.w - 10, room.y + room.h - 10}
        }
        
        for _, pos in ipairs(torchPositions) do
            self:drawTorch(pos[1], pos[2])
        end
        
        if math.random() > 0.3 then
            local numBones = math.random(2, 5)
            for i = 1, numBones do
                local boneX = room.x + math.random(15, room.w - 15)
                local boneY = room.y + math.random(15, room.h - 15)
                self:drawBone(boneX, boneY)
            end
        end
        
        self:drawCobweb(room.x + 5, room.y + 5)
        self:drawCobweb(room.x + room.w - 5, room.y + 5)
        self:drawCobweb(room.x + 5, room.y + room.h - 5)
        self:drawCobweb(room.x + room.w - 5, room.y + room.h - 5)
    end
end

function Dungeon:drawTorch(x, y)
    local radius = 15
    for py = y - radius, y + radius do
        for px = x - radius, x + radius do
            if px >= 0 and px < self.width and py >= 0 and py < self.height then
                local dist = math.sqrt((px - x)^2 + (py - y)^2)
                if dist <= radius then
                    local intensity = (1 - dist / radius) * 0.3
                    local r, g, b, a = self.imageData:getPixel(px, py)
                    r = math.min(1, r + intensity * 1.2)
                    g = math.min(1, g + intensity * 0.8)
                    b = math.min(1, b + intensity * 0.3)
                    self.imageData:setPixel(px, py, r, g, b, a or 1)
                end
            end
        end
    end
end

function Dungeon:drawBone(x, y)
    local boneColor = {0.85, 0.82, 0.75}
    for i = -6, 6 do
        for j = -2, 2 do
            local px = x + i
            local py = y + j
            if px >= 0 and px < self.width and py >= 0 and py < self.height then
                local dist = math.abs(i) / 6 + math.abs(j) / 2
                if dist <= 1 then
                    local r, g, b, a = self.imageData:getPixel(px, py)
                    local blend = 0.6
                    self.imageData:setPixel(px, py, 
                        r * (1 - blend) + boneColor[1] * blend,
                        g * (1 - blend) + boneColor[2] * blend,
                        b * (1 - blend) + boneColor[3] * blend,
                        a or 1)
                end
            end
        end
    end
end

function Dungeon:drawCobweb(x, y)
    local size = 12
    for i = -size, size do
        for j = -size, size do
            local px = x + i
            local py = y + j
            if px >= 0 and px < self.width and py >= 0 and py < self.height then
                local dist = math.sqrt(i*i + j*j)
                if dist <= size and math.random() > 0.7 then
                    local r, g, b, a = self.imageData:getPixel(px, py)
                    local cobwebColor = 0.85
                    local blend = 0.3 * (1 - dist/size)
                    self.imageData:setPixel(px, py,
                        r * (1 - blend) + cobwebColor * blend,
                        g * (1 - blend) + cobwebColor * blend,
                        b * (1 - blend) + cobwebColor * blend,
                        a or 1)
                end
            end
        end
    end
end

-- NEW: Smooth edge transitions between walls and floors
function Dungeon:addEdgeTransitions()
    local edgeSize = 3
    for y = 1, self.height - 2 do
        for x = 1, self.width - 2 do
            local isWalkable = self.walkableMap[y] and self.walkableMap[y][x]
            if isWalkable then
                -- Check if this floor pixel is adjacent to a wall
                local hasWallNeighbor = false
                for dy = -edgeSize, edgeSize do
                    for dx = -edgeSize, edgeSize do
                        local nx, ny = x + dx, y + dy
                        if nx >= 0 and nx < self.width and ny >= 0 and ny < self.height then
                            if not (self.walkableMap[ny] and self.walkableMap[ny][nx]) then
                                hasWallNeighbor = true
                                break
                            end
                        end
                    end
                    if hasWallNeighbor then break end
                end
                
                if hasWallNeighbor then
                    -- Darken floor pixels near walls for better definition
                    local r, g, b, a = self.imageData:getPixel(x, y)
                    local darkening = 0.88
                    self.imageData:setPixel(x, y, r * darkening, g * darkening, b * darkening, a or 1)
                end
            end
        end
    end
end

function Dungeon:getLeftmostSpawnPoint(w, h, padding)
    if #self.rooms == 0 then return nil end
    padding = padding or 0
    
    local room = self.rooms[1]
    local x = room.cx
    local y = room.cy
    
    if self:canFitAtCenter(x, y, w, h, padding) then
        return x, y
    end
    
    return self:getRandomSpawnPoint(w, h, padding)
end

function Dungeon:getRightmostSpawnPoint(w, h, padding)
    if #self.rooms == 0 then return nil end
    padding = padding or 0
    
    local room = self.rooms[#self.rooms]
    local x = room.cx
    local y = room.cy
    
    if self:canFitAtCenter(x, y, w, h, padding) then
        return x, y
    end
    
    return self:getRandomSpawnPoint(w, h, padding)
end

function Dungeon:getSpawnPointsOutsideSafeRoom(count, w, h, padding, knightX, knightY)
    if #self.rooms == 0 then return {} end
    padding = padding or 0
    knightX = knightX or 0
    knightY = knightY or 0
    
    local safeRadius = 150
    local results = {}
    
    for roomIdx = 2, #self.rooms do
        if #results >= count then break end
        
        local room = self.rooms[roomIdx]
        local x = room.cx + math.random(-room.w/3, room.w/3)
        local y = room.cy + math.random(-room.h/3, room.h/3)
        
        local distSq = (x - knightX)^2 + (y - knightY)^2
        if distSq > safeRadius * safeRadius then
            if self:canFitAtCenter(x, y, w, h, padding) then
                local duplicate = false
                for _, existingSpot in ipairs(results) do
                    if math.abs(existingSpot.x - x) < 30 and math.abs(existingSpot.y - y) < 30 then
                        duplicate = true
                        break
                    end
                end
                if not duplicate then
                    table.insert(results, {x = x, y = y})
                end
            end
        end
    end
    
    return results
end

function Dungeon:getRandomSpawnPoint(w, h, padding)
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

function Dungeon:isBlocked(x, y)
    if x < 0 or y < 0 or x >= self.width or y >= self.height then
        return true
    end
    
    local px = math.floor(x)
    local py = math.floor(y)
    
    return not (self.walkableMap[py] and self.walkableMap[py][px])
end

function Dungeon:hasLineOfSight(x1, y1, x2, y2)
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

-- FIXED: Collision detection without blind spots
function Dungeon:isColliding(x, y, w, h)
    if x < 0 or y < 0 or x + w > self.width or y + h > self.height then
        return true
    end

    -- FIX: Use epsilon-based math to avoid blind spots at grid boundaries
    local epsilon = 0.0001
    local startTileX = math.floor(x / self.gridSize) + 1
    local startTileY = math.floor(y / self.gridSize) + 1
    local endTileX = math.floor((x + w - epsilon) / self.gridSize) + 1
    local endTileY = math.floor((y + h - epsilon) / self.gridSize) + 1

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
    if not w or not h then return true end
    padding = padding or 0

    local left = x - w / 2
    local top = y - h / 2
    if left < padding or top < padding or left + w > self.width - padding or top + h > self.height - padding then
        return false
    end

    return not self:isColliding(x - w / 2, y - h / 2, w, h)
end

function Dungeon:render()
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(self.texture, 0, 0)
end

return Dungeon