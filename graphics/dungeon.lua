-- dungeon.lua
-- Enhanced procedural dungeon using Tileset Rendering (SpriteBatch)
local Class = require("system.class")
local Dungeon = Class.define()

function Dungeon:init(imagePath, tileSize)
    self.tileSize = tileSize or 32 
    self.gridSize = self.tileSize / 4 -- Keep this for collision logic (e.g., 8)
    
    -- === TILESET SETUP ===
    self:setupTileset()
    
    self.rooms = {}
    self.walkableMap = {}
    self.pillars = {}
    
    -- Decoration tables (Since we aren't painting pixels anymore, we store coordinates)
    self.waterPuddles = {}
    self.torches = {}
    self.bones = {}
    self.cobwebs = {}
    self.enderPortal = nil -- NEW: The exit portal
    
    self:generateProceduralDungeon() 
    
    self.collisionMap = {}
    self.walkableTiles = {}
    self:buildCollisionMap()
    
    -- === BUILD VISUAL RENDERING BATCH ===
    self:buildSpriteBatch()
end

-- === LOADS THE PNG AND CREATES QUADS ===
function Dungeon:setupTileset()
    -- Load your downloaded tileset!
    local success, img = pcall(love.graphics.newImage, "graphics/dungeon_tiles.png")
    if success then
        self.tilesetImage = img
    else
        -- Fallback: create a dummy magenta image if the file is missing so the game doesn't crash
        local dummyData = love.image.newImageData(32, 32)
        dummyData:mapPixel(function() return 1, 0, 1, 1 end)
        self.tilesetImage = love.graphics.newImage(dummyData)
    end
    
    -- Crucial for pixel art: prevents blurring when scaling!
    self.tilesetImage:setFilter("nearest", "nearest") 
    
    local imgW = self.tilesetImage:getWidth()
    local imgH = self.tilesetImage:getHeight()
    
    -- 0x72 Dungeon Tileset uses 16x16 pixel tiles
    self.visualTileSize = 16 
    
    -- Coordinates based on the top-left room in your tileset image:
    self.quads = {
        floor = love.graphics.newQuad(16, 16, 16, 16, imgW, imgH),
        wall  = love.graphics.newQuad(16, 0, 16, 16, imgW, imgH),
    }
end

-- === RENDERS THE LOGICAL MAP INTO A HIGHLY OPTIMIZED SPRITEBATCH ===
function Dungeon:buildSpriteBatch()
    local ts = self.visualTileSize
    local tilesX = math.ceil(self.width / ts)
    local tilesY = math.ceil(self.height / ts)
    
    -- Allocate memory for the batch
    self.spriteBatch = love.graphics.newSpriteBatch(self.tilesetImage, tilesX * tilesY)
    self.spriteBatch:clear()
    
    for ty = 0, tilesY - 1 do
        for tx = 0, tilesX - 1 do
            local px = tx * ts
            local py = ty * ts
            
            -- Check the logical walkableMap to decide which tile to draw
            local midX = math.floor(px + ts / 2)
            local midY = math.floor(py + ts / 2)
            
            local isWalkable = self.walkableMap[midY] and self.walkableMap[midY][midX]
            local quad = isWalkable and self.quads.floor or self.quads.wall
            
            self.spriteBatch:add(quad, px, py)
        end
    end
    self.spriteBatch:flush() -- Finalize the batch for rendering
end

function Dungeon:generateProceduralDungeon()
    self.width = 600
    self.height = 600
    
    -- Initialize logical walkable map (No more ImageData pixel manipulation!)
    self.walkableMap = {}
    for y = 0, self.height - 1 do
        self.walkableMap[y] = {}
        for x = 0, self.width - 1 do
            self.walkableMap[y][x] = false
        end
    end
    
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
                x = roomX, y = roomY, w = roomW, h = roomH,
                cx = roomX + roomW / 2, cy = roomY + roomH / 2
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
            self.rooms[i].cx, self.rooms[i].cy,
            self.rooms[i + 1].cx, self.rooms[i + 1].cy
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
        
        -- NEW: Place the Ender Portal in the last room
        self:createEnderPortal(lastRoom)
    end
    
    self:addDecorations()
    self:addWaterPuddles()
end

-- NEW: Create the Ender Portal (exit)
function Dungeon:createEnderPortal(room)
    -- Place portal in the center of the last room
    self.enderPortal = {
        x = room.cx,
        y = room.cy,
        width = 32,
        height = 32,
        animOffset = 0
    }
end

function Dungeon:rectsOverlap(x1, y1, w1, h1, x2, y2, w2, h2)
    return x1 < x2 + w2 and x1 + w1 > x2 and y1 < y2 + h2 and y1 + h1 > y2
end

function Dungeon:carveRoom(x, y, w, h)
    local margin = 2
    for py = y + margin, y + h - margin do
        for px = x + margin, x + w - margin do
            if px >= 0 and px < self.width and py >= 0 and py < self.height then
                self.walkableMap[py][px] = true
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
                if self.walkableMap[y] then self.walkableMap[y][x] = true end
            end
        end
    end
    
    for y = minY, maxY do
        for xOffset = -corridorWidth/2, corridorWidth/2 do
            local x = math.floor(x2 + xOffset)
            if x >= 0 and x < self.width and y >= 0 and y < self.height then
                if self.walkableMap[math.floor(y)] then self.walkableMap[math.floor(y)][x] = true end
            end
        end
    end
end

-- === STORES DECORATION DATA (Instead of drawing pixels) ===
function Dungeon:addWaterPuddles()
    for _, room in ipairs(self.rooms) do
        if math.random() > 0.5 then
            local puddleX = room.x + math.random(20, room.w - 20)
            local puddleY = room.y + math.random(20, room.h - 20)
            local puddleRadius = math.random(8, 12)
            table.insert(self.waterPuddles, {x = puddleX, y = puddleY, r = puddleRadius})
        end
    end
end

function Dungeon:addDecorations()
    for _, room in ipairs(self.rooms) do
        -- Torches
        local torchPositions = {
            {room.x + 10, room.y + 10}, {room.x + room.w - 10, room.y + 10},
            {room.x + 10, room.y + room.h - 10}, {room.x + room.w - 10, room.y + room.h - 10}
        }
        for _, pos in ipairs(torchPositions) do
            table.insert(self.torches, {x = pos[1], y = pos[2]})
        end
        
        -- Bones
        if math.random() > 0.3 then
            local numBones = math.random(2, 5)
            for i = 1, numBones do
                table.insert(self.bones, {
                    x = room.x + math.random(15, room.w - 15),
                    y = room.y + math.random(15, room.h - 15)
                })
            end
        end
        
        -- Cobwebs (store corner coordinates)
        table.insert(self.cobwebs, {x = room.x + 5, y = room.y + 5, corner = "TL"})
        table.insert(self.cobwebs, {x = room.x + room.w - 5, y = room.y + 5, corner = "TR"})
        table.insert(self.cobwebs, {x = room.x + 5, y = room.y + room.h - 5, corner = "BL"})
        table.insert(self.cobwebs, {x = room.x + room.w - 5, y = room.y + room.h - 5, corner = "BR"})
    end
end

function Dungeon:buildCollisionMap()
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

-- === RENDERING ===
function Dungeon:render()
    love.graphics.setColor(1, 1, 1)
    
    -- 1. Draw the highly optimized tileset
    love.graphics.draw(self.spriteBatch, 0, 0)
    
    -- 2. Draw Water Puddles
    love.graphics.setColor(0.2, 0.4, 0.8, 0.5)
    for _, puddle in ipairs(self.waterPuddles) do
        love.graphics.circle("fill", puddle.x, puddle.y, puddle.r)
    end
    
    -- 3. Draw Cobwebs
    love.graphics.setColor(1, 1, 1, 0.3)
    love.graphics.setLineWidth(1)
    for _, web in ipairs(self.cobwebs) do
        -- Simple web lines in corners
        local dirX = web.corner:find("L") and 1 or -1
        local dirY = web.corner:find("T") and 1 or -1
        love.graphics.line(web.x, web.y, web.x + 15 * dirX, web.y)
        love.graphics.line(web.x, web.y, web.x, web.y + 15 * dirY)
        love.graphics.line(web.x, web.y, web.x + 10 * dirX, web.y + 10 * dirY)
    end
    
    -- 4. Draw Bones
    love.graphics.setColor(0.9, 0.9, 0.8)
    for _, bone in ipairs(self.bones) do
        love.graphics.line(bone.x - 4, bone.y, bone.x + 4, bone.y)
        love.graphics.circle("fill", bone.x - 4, bone.y, 1.5)
        love.graphics.circle("fill", bone.x + 4, bone.y, 1.5)
    end
    
    -- 5. Draw Torches (Glowing effect)
    for _, torch in ipairs(self.torches) do
        love.graphics.setColor(1.0, 0.6, 0.2, 0.2)
        love.graphics.circle("fill", torch.x, torch.y, 25)
        love.graphics.setColor(1.0, 0.8, 0.3, 0.6)
        love.graphics.circle("fill", torch.x, torch.y, 10)
        love.graphics.setColor(1.0, 1.0, 0.8)
        love.graphics.circle("fill", torch.x, torch.y, 3)
    end
    
    -- 6. NEW: Draw the Ender Portal (Exit)
    if self.enderPortal then
        -- Animate the portal
        self.enderPortal.animOffset = (self.enderPortal.animOffset + 0.1) % (math.pi * 2)
        
        -- Outer glow (pulsing)
        local pulse = math.sin(self.enderPortal.animOffset) * 5
        love.graphics.setColor(0.5, 0.0, 0.8, 0.4)
        love.graphics.circle("fill", self.enderPortal.x, self.enderPortal.y, 25 + pulse)
        
        -- Middle ring
        love.graphics.setColor(0.7, 0.0, 1.0, 0.6)
        love.graphics.circle("line", self.enderPortal.x, self.enderPortal.y, 18)
        
        -- Inner swirl
        love.graphics.setColor(0.9, 0.2, 1.0, 0.8)
        love.graphics.circle("fill", self.enderPortal.x, self.enderPortal.y, 12)
        
        -- Core
        love.graphics.setColor(1.0, 0.8, 1.0, 1.0)
        love.graphics.circle("fill", self.enderPortal.x, self.enderPortal.y, 6)
        
        -- Label
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("EXIT", self.enderPortal.x - 20, self.enderPortal.y - 40, 40, "center")
    end
    
    love.graphics.setColor(1, 1, 1) -- Reset color
end

-- NEW: Check if player reached the exit
function Dungeon:playerReachedExit(playerX, playerY, playerRadius)
    if not self.enderPortal then return false end
    
    local dx = playerX - self.enderPortal.x
    local dy = playerY - self.enderPortal.y
    local dist = math.sqrt(dx * dx + dy * dy)
    
    return dist < (self.enderPortal.width / 2 + playerRadius)
end

-- ==========================================
-- COLLISION, SPAWNING, AND LOGIC (UNCHANGED)
-- ==========================================

function Dungeon:getLeftmostSpawnPoint(w, h, padding)
    if #self.rooms == 0 then return nil end
    padding = padding or 0
    local room = self.rooms[1]
    local x, y = room.cx, room.cy
    if self:canFitAtCenter(x, y, w, h, padding) then return x, y end
    return self:getRandomSpawnPoint(w, h, padding)
end

function Dungeon:getRightmostSpawnPoint(w, h, padding)
    if #self.rooms == 0 then return nil end
    padding = padding or 0
    local room = self.rooms[#self.rooms]
    local x, y = room.cx, room.cy
    if self:canFitAtCenter(x, y, w, h, padding) then return x, y end
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
        if self:canFitAtCenter(x, y, w, h, padding) then return x, y end
    end
    return nil
end

function Dungeon:isBlocked(x, y)
    if x < 0 or y < 0 or x >= self.width or y >= self.height then return true end
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
        if self:isBlocked(tx, ty) then return false end
    end
    return true
end

-- FIXED: Collision detection without blind spots
function Dungeon:isColliding(x, y, w, h)
    if x < 0 or y < 0 or x + w > self.width or y + h > self.height then return true end
    local epsilon = 0.0001
    local startTileX = math.floor(x / self.gridSize) + 1
    local startTileY = math.floor(y / self.gridSize) + 1
    local endTileX = math.floor((x + w - epsilon) / self.gridSize) + 1
    local endTileY = math.floor((y + h - epsilon) / self.gridSize) + 1
    for ty = startTileY, endTileY do
        for tx = startTileX, endTileX do
            if not self.collisionMap[ty] or self.collisionMap[ty][tx] == nil then return true end
            if self.collisionMap[ty][tx] then return true end
        end
    end
    return false
end

function Dungeon:canFitAtCenter(x, y, w, h, padding)
    if not w or not h then return true end
    padding = padding or 0
    local left = x - w / 2
    local top = y - h / 2
    if left < padding or top < padding or left + w > self.width - padding or top + h > self.height - padding then return false end
    return not self:isColliding(x - w / 2, y - h / 2, w, h)
end

return Dungeon