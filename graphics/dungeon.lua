-- graphics/dungeon.lua
-- Simplified PNG-only dungeon loader and renderer
local Class = require("system.class")
local Dungeon = Class.define()

local function isExactColor(r, g, b, target)
    local eps = 1 / 255 / 2
    return math.abs(r - target[1]) < eps and math.abs(g - target[2]) < eps and math.abs(b - target[3]) < eps
end

function Dungeon:init(imagePath, tileSize, corridorWidth, layout, dungeonIndex)
    self.width = 3600
    self.height = 2200
    self.tileSize = 16
    self.gridSize = 4
    
    -- Load PNG image
    local imgPath = "graphics/dungeon.png"
    if dungeonIndex then
        imgPath = string.format("graphics/Dungeon(%d).png", dungeonIndex)
    end
    
    if love.filesystem.getInfo(imgPath) then
        self.tilesetImage = love.graphics.newImage(imgPath)
        self.imageData = love.image.newImageData(imgPath)
        print("[Dungeon] Loaded PNG: " .. imgPath)
    else
        print("[Dungeon] PNG not found: " .. imgPath)
        self.tilesetImage = nil
        self.imageData = nil
    end
    
    -- Basic collision grid (all walkable until we generate actual values)
    self.walkableGrid = {}
    local tilesX = math.floor(self.width / self.gridSize)
    local tilesY = math.floor(self.height / self.gridSize)
    self.tilesX = tilesX
    self.tilesY = tilesY
    
    for ty = 1, tilesY do
        self.walkableGrid[ty] = {}
        for tx = 1, tilesX do
            self.walkableGrid[ty][tx] = true
        end
    end
    
    -- Rooms and spawning
    self.rooms = {{x = 0, y = 0, w = self.width, h = self.height, cx = self.width/2, cy = self.height/2}}
    
    -- Build collision map (all false = no collisions = walkable)
    self.collisionMap = {}
    self.walkableTiles = {}
    for ty = 1, tilesY do
        self.collisionMap[ty] = {}
        for tx = 1, tilesX do
            self.collisionMap[ty][tx] = false
            table.insert(self.walkableTiles, {x = tx, y = ty})
        end
    end
    
    -- Decorations (minimal)
    self.torches = {}
    self.doors = {}
    self.staticCanvas = nil
    
    self:buildCollisionMap()
    self:buildStaticCanvas()
end

function Dungeon:cellIsWalkable(px, py)
    local gx = math.floor(px / self.gridSize) + 1
    local gy = math.floor(py / self.gridSize) + 1
    return self.walkableGrid[gy] and self.walkableGrid[gy][gx]
end

function Dungeon:isColliding(x, y, w, h)
    if x < 0 or y < 0 or x + w > self.width or y + h > self.height then
        return true
    end

    local epsilon = 0.0001
    local sx = math.floor(x / self.gridSize) + 1
    local sy = math.floor(y / self.gridSize) + 1
    local ex = math.floor((x + w - epsilon) / self.gridSize) + 1
    local ey = math.floor((y + h - epsilon) / self.gridSize) + 1

    for ty = sy, ey do
        for tx = sx, ex do
            if not self.collisionMap[ty] or self.collisionMap[ty][tx] then
                return true
            end
        end
    end

    return false
end

function Dungeon:hasLineOfSight(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist < 1 then return true end

    local step = self.gridSize / 2
    local steps = math.max(1, math.floor(dist / step))
    for i = 1, steps do
        local t = i / steps
        local tx = x1 + dx * t
        local ty = y1 + dy * t
        if self:isBlocked(tx, ty) then
            return false
        end
    end
    return true
end

function Dungeon:isBlocked(x, y)
    if x < 0 or y < 0 or x >= self.width or y >= self.height then
        return true
    end

    local tx = math.floor(x / self.gridSize) + 1
    local ty = math.floor(y / self.gridSize) + 1
    return not self.collisionMap[ty] or self.collisionMap[ty][tx]
end

function Dungeon:buildCollisionMap()
    self.collisionMap = {}
    self.walkableTiles = {}

    local tilesX = self.tilesX
    local tilesY = self.tilesY
    local img = self.imageData
    local imgW = img and img:getWidth() or self.width
    local imgH = img and img:getHeight() or self.height
    local scaleX = self.width / imgW
    local scaleY = self.height / imgH

    local function isWallColor(r, g, b, a)
        if a ~= 1 then return false end
        if r == 0 and g == 0 and b == 0 then return true end
        if r == 42/255 and g == 42/255 and b == 42/255 then return true end
        if r == 57/255 and g == 57/255 and b == 57/255 then return true end
        return false
    end

    for ty = 1, tilesY do
        self.collisionMap[ty] = {}
        for tx = 1, tilesX do
            local worldX = (tx - 0.5) * self.gridSize
            local worldY = (ty - 0.5) * self.gridSize
            local sampleX = math.min(imgW - 1, math.max(0, math.floor(worldX / scaleX)))
            local sampleY = math.min(imgH - 1, math.max(0, math.floor(worldY / scaleY)))
            local blocked = false

            if img then
                local r, g, b, a = img:getPixel(sampleX, sampleY)
                blocked = isWallColor(r, g, b, a)
            end

            self.collisionMap[ty][tx] = blocked
            if not blocked then
                table.insert(self.walkableTiles, { x = tx, y = ty })
            end
        end
    end
end

function Dungeon:getSpawnPointByImageColor(w, h, padding, targetColor)
    if not self.imageData or not targetColor then return nil, nil end
    local imgW = self.imageData:getWidth()
    local imgH = self.imageData:getHeight()
    local scaleX = self.width / imgW
    local scaleY = self.height / imgH
    local candidates = {}

    for ty = 1, self.tilesY do
        for tx = 1, self.tilesX do
            if not self.collisionMap[ty] or not self.collisionMap[ty][tx] then
                local worldX = (tx - 0.5) * self.gridSize
                local worldY = (ty - 0.5) * self.gridSize
                if self:canFitAtCenter(worldX, worldY, w, h, padding) then
                    local sampleX = math.min(imgW - 1, math.max(0, math.floor(worldX / scaleX)))
                    local sampleY = math.min(imgH - 1, math.max(0, math.floor(worldY / scaleY)))
                    local r, g, b, a = self.imageData:getPixel(sampleX, sampleY)
                    if isExactColor(r, g, b, targetColor) then
                        table.insert(candidates, {x = worldX, y = worldY})
                    end
                end
            end
        end
    end

    if #candidates == 0 then
        return nil, nil
    end

    local choice = candidates[math.random(#candidates)]
    return choice.x, choice.y
end

function Dungeon:getSpawnPointsByImageColor(count, w, h, padding, targetColor, safeX, safeY)
    if not self.imageData or not targetColor or count <= 0 then
        return {}
    end

    local imgW = self.imageData:getWidth()
    local imgH = self.imageData:getHeight()
    local scaleX = self.width / imgW
    local scaleY = self.height / imgH
    local safeRadiusSq = 0

    if safeX and safeY then
        local safeBuffer = math.max(w or 0, h or 0) + (padding or 0) + 100
        safeRadiusSq = safeBuffer * safeBuffer
    end

    local candidates = {}
    for ty = 1, self.tilesY do
        for tx = 1, self.tilesX do
            if not self.collisionMap[ty] or not self.collisionMap[ty][tx] then
                local worldX = (tx - 0.5) * self.gridSize
                local worldY = (ty - 0.5) * self.gridSize
                if self:canFitAtCenter(worldX, worldY, w, h, padding) then
                    local sampleX = math.min(imgW - 1, math.max(0, math.floor(worldX / scaleX)))
                    local sampleY = math.min(imgH - 1, math.max(0, math.floor(worldY / scaleY)))
                    local r, g, b, a = self.imageData:getPixel(sampleX, sampleY)
                    if isExactColor(r, g, b, targetColor) then
                        if not safeX or not safeY or ((worldX - safeX)^2 + (worldY - safeY)^2 > safeRadiusSq) then
                            table.insert(candidates, {x = worldX, y = worldY})
                        end
                    end
                end
            end
        end
    end

    if #candidates == 0 then
        return {}
    end

    local chosen = {}
    for i = 1, math.min(count, #candidates) do
        local index = math.random(#candidates)
        table.insert(chosen, table.remove(candidates, index))
    end

    return chosen
end

function Dungeon:buildSpriteBatch()
end

function Dungeon:buildStaticCanvas()
    if not love or not love.graphics then return end
    if self.staticCanvas then self.staticCanvas:release() end
    self.staticCanvas = love.graphics.newCanvas(self.width, self.height)
    local prevCanvas = love.graphics.getCanvas()
    love.graphics.setCanvas(self.staticCanvas)
    love.graphics.clear(0, 0, 0, 0)
    
    if self.tilesetImage then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(self.tilesetImage, 0, 0, 0, 
            self.width / self.tilesetImage:getWidth(), 
            self.height / self.tilesetImage:getHeight())
    end
    
    love.graphics.setCanvas(prevCanvas)
end

function Dungeon:render()
    if not self.staticCanvas then self:buildStaticCanvas() end
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(self.staticCanvas, 0, 0)
    
    -- Draw torches
    local time = love.timer.getTime()
    local function ix(v) return math.floor(v + 0.5) end
    for _, torch in ipairs(self.torches) do
        local x, y = torch.x, torch.y
        local s = (torch.seed or 0) + time * 6
        local flick = 1 + math.sin(s) * 0.12 + (math.sin(s * 1.7) * 0.06)
        local warm = {1.0, 0.65, 0.25}
        love.graphics.setBlendMode("add")
        love.graphics.setColor(warm[1], warm[2], warm[3], 0.18 * flick)
        love.graphics.circle("fill", ix(x), ix(y), 30 * flick)
        love.graphics.setColor(warm[1], warm[2], warm[3], 0.85 * flick)
        love.graphics.circle("fill", ix(x), ix(y), 10 * flick)
        love.graphics.setColor(1.0, 1.0, 0.9)
        love.graphics.circle("fill", ix(x), ix(y), 3)
        love.graphics.setBlendMode("alpha")
    end
    
    -- Draw doors
    for _, door in ipairs(self.doors) do
        love.graphics.setColor(0.24, 0.16, 0.1)
        love.graphics.rectangle("fill", door.x - 8, door.y - 16, 16, 24)
        love.graphics.setColor(0.84, 0.66, 0.4)
        love.graphics.rectangle("fill", door.x - 6, door.y - 14, 12, 20)
        love.graphics.setColor(1, 1, 1, 0.2)
        love.graphics.rectangle("fill", door.x - 4, door.y - 10, 8, 8)
    end
end

function Dungeon:clampSpawnPoint(x, y, w, h, padding)
    padding = padding or 0
    local halfW = (w or 0) / 2
    local halfH = (h or 0) / 2
    local minX = padding + halfW
    local maxX = math.max(minX, self.width - padding - halfW)
    local minY = padding + halfH
    local maxY = math.max(minY, self.height - padding - halfH)
    x = math.max(minX, math.min(maxX, x or (self.width / 2)))
    y = math.max(minY, math.min(maxY, y or (self.height / 2)))
    return x, y
end

function Dungeon:getLeftmostSpawnPoint(w, h, padding)
    local checkX = self.width / 2
    local checkY = self.height / 2
    if self:canFitAtCenter(checkX, checkY, w, h, padding) then
        return self:clampSpawnPoint(checkX, checkY, w, h, padding)
    end
    return self:clampSpawnPoint(self.width / 2, self.height / 2, w, h, padding)
end

function Dungeon:getRandomSpawnPoint(w, h, padding)
    local x = self.width / 2 + math.random(-300, 300)
    local y = self.height / 2 + math.random(-250, 250)
    return self:clampSpawnPoint(x, y, w, h, padding)
end

function Dungeon:canFitAtCenter(cx, cy, w, h, padding)
    local halfW = (w or 0) / 2
    local halfH = (h or 0) / 2
    return cx and cy and (cx - halfW) >= (padding or 0) and (cx + halfW) <= (self.width - (padding or 0)) and (cy - halfH) >= (padding or 0) and (cy + halfH) <= (self.height - (padding or 0))
end

function Dungeon:getSpawnPointsOutsideSafeRoom(count, w, h, padding, safeX, safeY)
    local points = {}
    local attempts = 0
    local maxAttempts = math.max(50, count * 10)
    local minBorder = 200
    local halfW = (w or 0) / 2
    local halfH = (h or 0) / 2
    local safeRadiusSq = 0

    if safeX and safeY then
        local safeBuffer = math.max(w or 0, h or 0) + (padding or 0) + 100
        safeRadiusSq = safeBuffer * safeBuffer
    end

    while #points < count and attempts < maxAttempts do
        attempts = attempts + 1
        local x = math.random(minBorder + halfW, self.width - minBorder - halfW)
        local y = math.random(minBorder + halfH, self.height - minBorder - halfH)
        x, y = self:clampSpawnPoint(x, y, w, h, padding)

        if self:canFitAtCenter(x, y, w, h, padding) then
            if safeX and safeY then
                local dx = x - safeX
                local dy = y - safeY
                if dx * dx + dy * dy <= safeRadiusSq then
                    goto continue
                end
            end
            table.insert(points, {x = x, y = y})
        end
        ::continue::
    end

    while #points < count do
        local x, y = self:clampSpawnPoint(self.width / 2, self.height / 2, w, h, padding)
        table.insert(points, {x = x, y = y})
    end

    return points
end

function Dungeon:playerReachedExit(px, py, radius)
    return false  -- No exit portal
end

return Dungeon
