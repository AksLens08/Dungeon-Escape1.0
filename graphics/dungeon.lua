-- graphics/dungeon.lua
-- Procedural dungeon generator + renderer
local Class = require("system.class")
local Dungeon = Class.define()

-- Create a new dungeon instance.
-- imagePath: optional path to a tileset image (16x16 tiles)
-- tileSize: logical tile size in pixels (default 16)
function Dungeon:init(imagePath, tileSize, corridorWidth, tutorialStageData)
    self.tileSize = tileSize or 16
    -- configurable corridor/path width in pixels (multiple of gridSize is best)
    self.corridorWidth = corridorWidth or 40
    self.gridSize = math.max(1, math.floor(self.tileSize / 4)) -- collision grid granularity
    self.tilesetPath = imagePath or "graphics/dungeon_tiles.png"

    -- logical map size (in pixels). Medium-size dungeon.
    self.width = 2200
    self.height = 1300

    -- storage
    -- grid-based walkable map aligned with `gridSize`
    self.walkableGrid = {}
    self.tilesX = 0
    self.tilesY = 0
    self.rooms = {}
    self.collisionMap = {}
    self.walkableTiles = {}
    self.decals = {}
    self.barrels = {}
    self.brokenTiles = {}
    self.dustParticles = {}
    self.mossPatches = {}
    self.staticCanvas = nil

    -- visual data (simple renderer only; legacy tileset removed)
    self.useSimpleRenderer = true

    -- decorations
    self.torches = {}
    self.waterPuddles = {}
    self.bones = {}
    self.cobwebs = {}
    self.pillars = {}
    self.enderPortal = nil

    -- build everything
    self:setupTileset()
    if tutorialStageData then
        self:generateTutorialDungeon(tutorialStageData)
    else
        self:generateProceduralDungeon()
    end
    self:buildCollisionMap()
    self:buildSpriteBatch()
    self:buildStaticCanvas()
end

-- Try to load tileset image and prepare quads. If missing or unsuitable,
-- we'll fall back to a simple colored-tiles renderer.
function Dungeon:setupTileset()
    -- Force simple renderer: do not use the dungeon_tiles.png atlas.
    -- This draws the dungeon procedurally using colored rectangles so
    -- the map is guaranteed to contain no character art from the atlas.
    self.tilesetImage = nil
    self.floorQuads = {}
    self.wallQuads = {}
    self.useSimpleRenderer = true
    self.simpleFloorColor = {0.33, 0.38, 0.44}
    self.simpleWallColor  = {0.06, 0.06, 0.08}
end

-- Procedural dungeon generator: place rooms and corridors into walkableGrid
function Dungeon:generateProceduralDungeon()
    -- initialize grid-based walkable map to non-walkable
    local tilesX = math.floor(self.width / self.gridSize)
    local tilesY = math.floor(self.height / self.gridSize)
    self.tilesX = tilesX; self.tilesY = tilesY
    self.walkableGrid = {}
    for ty = 1, tilesY do
        self.walkableGrid[ty] = {}
        for tx = 1, tilesX do self.walkableGrid[ty][tx] = false end
    end

    local minRoom = 70
    local maxRoom = 220
    local padding = 56
    local maxAttempts = 1400
    local targetRooms = 28

    -- place rooms in a more natural cluster layout with varied sizes
    for attempt = 1, maxAttempts do
        if #self.rooms >= targetRooms then break end
        local w = math.random(minRoom, maxRoom)
        local h = math.random(minRoom, maxRoom)

        local x, y
        if #self.rooms == 0 then
            x = math.random(padding, self.width - w - padding)
            y = math.random(padding, self.height - h - padding)
        else
            local anchor = self.rooms[math.random(1, #self.rooms)]
            local offsetX = math.random(-280, 280)
            local offsetY = math.random(-220, 220)
            x = math.max(padding, math.min(self.width - w - padding, anchor.cx + offsetX - w / 2))
            y = math.max(padding, math.min(self.height - h - padding, anchor.cy + offsetY - h / 2))
        end

        local overlaps = false
        local tooClose = false
        for _, r in ipairs(self.rooms) do
            if self:rectsOverlap(x - padding, y - padding, w + padding*2, h + padding*2, r.x, r.y, r.w, r.h) then
                overlaps = true; break
            end
            local dx = (x + w / 2) - (r.x + r.w / 2)
            local dy = (y + h / 2) - (r.y + r.h / 2)
            local dist = math.sqrt(dx * dx + dy * dy)
            local minSeparation = math.max(150, math.min(w, h) * 0.75)
            if dist < minSeparation then
                tooClose = true
                break
            end
        end
        if not overlaps and not tooClose then
            -- pick a room shape template
            local shape = "rect"
            local rrand = math.random()
            if rrand < 0.12 then shape = "cross"
            elseif rrand < 0.28 then shape = "L"
            elseif rrand < 0.42 then shape = "plus" end

            -- carve according to shape
            if shape == "rect" then
                self:carveRoom(x, y, w, h)
            elseif shape == "L" then
                local w2 = math.floor(w * 0.6)
                local h2 = math.floor(h * 0.6)
                self:carveRoom(x, y, w2, h)
                self:carveRoom(x + w2 - 8, y + h - h2, w - w2 + 8, h2)
            elseif shape == "cross" then
                local cxw = math.floor(w * 0.4)
                local cyh = math.floor(h * 0.4)
                self:carveRoom(x + (w - cxw) / 2, y, cxw, h)
                self:carveRoom(x, y + (h - cyh) / 2, w, cyh)
            elseif shape == "plus" then
                local barW = math.floor(w * 0.28)
                local barH = math.floor(h * 0.28)
                self:carveRoom(x + (w - barW) / 2, y, barW, h)
                self:carveRoom(x, y + (h - barH) / 2, w, barH)
            end

            table.insert(self.rooms, {x = x, y = y, w = w, h = h, cx = x + w/2, cy = y + h/2, shape = shape})
        end
    end

    self:smoothWalkableGrid(1)

    -- sort rooms by center x for stable connections
    table.sort(self.rooms, function(a,b) return a.cx < b.cx end)

    -- connect rooms with simple orthogonal corridors that enter each room from its edge
    for i = 1, #self.rooms - 1 do
        local a = self.rooms[i]
        local b = self.rooms[i+1]
        local sx, sy = self:getRoomConnectionPoint(a, b.cx, b.cy)
        local ex, ey = self:getRoomConnectionPoint(b, a.cx, a.cy)
        self:carveCorridor(sx, sy, ex, ey)
    end

    -- add a few extra branch corridors for a more organic, dungeon-like layout
    for i = 1, math.max(2, math.floor(#self.rooms / 5)) do
        local a = self.rooms[math.random(1, #self.rooms)]
        local b = self.rooms[math.random(1, #self.rooms)]
        if a and b and a ~= b then
            local sx, sy = self:getRoomConnectionPoint(a, b.cx, b.cy)
            local ex, ey = self:getRoomConnectionPoint(b, a.cx, a.cy)
            self:carveCorridor(sx, sy, ex, ey)
        end
    end

    -- enlarge first and last rooms as start/end areas when there is safe space
    if #self.rooms > 0 then
        local r = self.rooms[1]
        local targetW = math.max(r.w, 120)
        local targetH = math.max(r.h, 120)
        local newX = math.max(0, math.min(r.x - math.floor((targetW - r.w) / 2), self.width - targetW))
        local newY = math.max(0, math.min(r.y - math.floor((targetH - r.h) / 2), self.height - targetH))
        if self:canPlaceRoom(newX, newY, targetW, targetH) then
            r.x, r.y, r.w, r.h = newX, newY, targetW, targetH
            r.cx, r.cy = r.x + r.w / 2, r.y + r.h / 2
            self:carveRoom(r.x, r.y, r.w, r.h)
        else
            self:carveRoom(r.x, r.y, r.w, r.h)
        end
    end
    if #self.rooms > 0 then
        local r = self.rooms[#self.rooms]
        local targetW = math.max(r.w, 140)
        local targetH = math.max(r.h, 140)
        local newX = math.max(0, math.min(r.x - math.floor((targetW - r.w) / 2), self.width - targetW))
        local newY = math.max(0, math.min(r.y - math.floor((targetH - r.h) / 2), self.height - targetH))
        if self:canPlaceRoom(newX, newY, targetW, targetH) then
            r.x, r.y, r.w, r.h = newX, newY, targetW, targetH
            r.cx, r.cy = r.x + r.w / 2, r.y + r.h / 2
            self:carveRoom(r.x, r.y, r.w, r.h)
        else
            self:carveRoom(r.x, r.y, r.w, r.h)
        end
        self:createEnderPortal(r)
    end

    -- add richer decorations and room variation to make the map feel lived-in
    for i, room in ipairs(self.rooms) do
        room.tint = {0.28 + math.random() * 0.06, 0.32 + math.random() * 0.06, 0.36 + math.random() * 0.06}
        room.accent = {math.max(0, room.tint[1] + (math.random()-0.5)*0.18), math.max(0, room.tint[2] + (math.random()-0.5)*0.18), math.max(0, room.tint[3] + (math.random()-0.5)*0.18)}
        room.patternSeed = math.random(1, 100000)
        if math.random() > 0.45 then
            local num = math.random(1, 3)
            for p=1,num do
                table.insert(self.pillars, {x = room.x + math.random(20, room.w-20), y = room.y + math.random(20, room.h-20)})
            end
        end
    end
    self:addDecorations()
    self:addWaterPuddles()
    self:addProps()
    self:addCobwebs()
    self:addDust()
end

function Dungeon:generateTutorialDungeon(stageData)
    local tilesX = math.floor(self.width / self.gridSize)
    local tilesY = math.floor(self.height / self.gridSize)
    self.tilesX = tilesX
    self.tilesY = tilesY
    self.walkableGrid = {}
    for ty = 1, tilesY do
        self.walkableGrid[ty] = {}
        for tx = 1, tilesX do self.walkableGrid[ty][tx] = false end
    end

    self.rooms = {}
    self.enderPortal = nil

    for _, roomData in ipairs(stageData.rooms or {}) do
        self:carveRoom(roomData.x, roomData.y, roomData.w, roomData.h)
        table.insert(self.rooms, {
            x = roomData.x,
            y = roomData.y,
            w = roomData.w,
            h = roomData.h,
            cx = roomData.x + roomData.w / 2,
            cy = roomData.y + roomData.h / 2,
            shape = "rect"
        })
    end

    for _, connection in ipairs(stageData.connections or {}) do
        local a = self.rooms[connection[1]]
        local b = self.rooms[connection[2]]
        if a and b then
            local sx, sy = self:getRoomConnectionPoint(a, b.cx, b.cy)
            local ex, ey = self:getRoomConnectionPoint(b, a.cx, a.cy)
            self:carveCorridor(sx, sy, ex, ey)
        end
    end

    self:smoothWalkableGrid(1)

    if #self.rooms > 0 then
        self:ensureConnectivity()
    end

    if stageData.exitRoom then
        local exitRoom = self.rooms[stageData.exitRoom]
        if exitRoom then
            self:createEnderPortal(exitRoom)
        end
    end

    for i, room in ipairs(self.rooms) do
        room.tint = {0.28 + math.random() * 0.06, 0.32 + math.random() * 0.06, 0.36 + math.random() * 0.06}
        room.accent = {math.max(0, room.tint[1] + (math.random()-0.5)*0.18), math.max(0, room.tint[2] + (math.random()-0.5)*0.18), math.max(0, room.tint[3] + (math.random()-0.5)*0.18)}
        room.patternSeed = math.random(1, 100000)
    end

    self:addDecorations()
    self:addWaterPuddles()
    self:addProps()
    self:addCobwebs()
    self:addDust()
end

function Dungeon:addProps()
    -- add barrels and broken tile clusters in rooms
    for _, room in ipairs(self.rooms) do
        if math.random() < 0.4 then
            local bx = room.x + math.random(12, room.w - 24)
            local by = room.y + math.random(12, room.h - 24)
            table.insert(self.barrels, {x = bx, y = by, r = math.random(6,10)})
        end
        if math.random() < 0.35 then
            local count = math.random(1,3)
            for i=1,count do
                local bx = room.x + math.random(8, room.w - 16)
                local by = room.y + math.random(8, room.h - 16)
                table.insert(self.brokenTiles, {x = bx, y = by, w = math.random(6,16), h = math.random(6,16)})
            end
        end
        -- small moss patches near walls
        if math.random() < 0.5 then
            for i=1, math.random(1,3) do
                local mx = room.x + math.random(8, room.w - 8)
                local my = room.y + math.random(8, room.h - 8)
                table.insert(self.mossPatches, {x = mx, y = my, r = math.random(4,10)})
            end
        end
    end
end

function Dungeon:addCobwebs()
    for i=1, 18 do
        table.insert(self.cobwebs, {x = math.random(0, self.width), y = math.random(0, self.height)})
    end
end

function Dungeon:addDust()
    for i=1, 120 do
        table.insert(self.dustParticles, {x = math.random(0, self.width), y = math.random(0, self.height), r = math.random(1,3), seed = math.random() * 10})
    end
end

function Dungeon:rectsOverlap(x1,y1,w1,h1,x2,y2,w2,h2)
    return x1 < x2 + w2 and x1 + w1 > x2 and y1 < y2 + h2 and y1 + h1 > y2
end

function Dungeon:canPlaceRoom(x, y, w, h, padding)
    padding = padding or 0
    local left = x - padding
    local top = y - padding
    local right = x + w + padding
    local bottom = y + h + padding
    if left < 0 or top < 0 or right > self.width or bottom > self.height then
        return false
    end
    local gx1 = math.max(1, math.floor(left / self.gridSize) + 1)
    local gy1 = math.max(1, math.floor(top / self.gridSize) + 1)
    local gx2 = math.min(self.tilesX, math.floor((right - 1) / self.gridSize) + 1)
    local gy2 = math.min(self.tilesY, math.floor((bottom - 1) / self.gridSize) + 1)
    for ty = gy1, gy2 do
        for tx = gx1, gx2 do
            if self.walkableGrid[ty] and self.walkableGrid[ty][tx] then
                return false
            end
        end
    end
    return true
end

function Dungeon:smoothWalkableGrid(iterations)
    iterations = iterations or 1
    for _ = 1, iterations do
        local nextGrid = {}
        for ty = 1, self.tilesY do
            nextGrid[ty] = {}
            for tx = 1, self.tilesX do
                local current = self.walkableGrid[ty] and self.walkableGrid[ty][tx]
                local walkableNeighbors = 0
                for ny = -1, 1 do
                    for nx = -1, 1 do
                        if nx ~= 0 or ny ~= 0 then
                            local gx = tx + nx
                            local gy = ty + ny
                            if self.walkableGrid[gy] and self.walkableGrid[gy][gx] then
                                walkableNeighbors = walkableNeighbors + 1
                            end
                        end
                    end
                end
                if current then
                    nextGrid[ty][tx] = walkableNeighbors >= 2
                else
                    nextGrid[ty][tx] = walkableNeighbors >= 5
                end
            end
        end
        self.walkableGrid = nextGrid
    end
end

function Dungeon:carveCircle(x, y, radiusPixels)
    local radiusCells = math.max(1, math.ceil(radiusPixels / math.max(1, self.gridSize)))
    local gx = math.floor(x / self.gridSize) + 1
    local gy = math.floor(y / self.gridSize) + 1
    local minTx = math.max(1, gx - radiusCells)
    local maxTx = math.min(self.tilesX, gx + radiusCells)
    local minTy = math.max(1, gy - radiusCells)
    local maxTy = math.min(self.tilesY, gy + radiusCells)
    local radiusSq = radiusPixels * radiusPixels

    for ty = minTy, maxTy do
        for tx = minTx, maxTx do
            local px = (tx - 1) * self.gridSize + self.gridSize / 2
            local py = (ty - 1) * self.gridSize + self.gridSize / 2
            local dx = px - x
            local dy = py - y
            if dx * dx + dy * dy <= radiusSq then
                self.walkableGrid[ty][tx] = true
            end
        end
    end
end

function Dungeon:carveRoom(x, y, w, h)
    -- simple rectangular room with small rounded corners
    local margin = 2
    local roomX = x + margin
    local roomY = y + margin
    local roomW = math.max(1, w - margin * 2)
    local roomH = math.max(1, h - margin * 2)
    local cornerRadius = math.min(10, math.max(2, math.floor(math.min(roomW, roomH) * 0.08)))

    local gx1 = math.max(1, math.floor(roomX / self.gridSize) + 1)
    local gy1 = math.max(1, math.floor(roomY / self.gridSize) + 1)
    local gx2 = math.min(self.tilesX, math.floor((roomX + roomW - 1) / self.gridSize) + 1)
    local gy2 = math.min(self.tilesY, math.floor((roomY + roomH - 1) / self.gridSize) + 1)

    for ty = gy1, gy2 do
        for tx = gx1, gx2 do
            self.walkableGrid[ty][tx] = true
        end
    end

    -- round corners a bit for a softer look
    if cornerRadius > 1 then
        self:carveCircle(roomX + cornerRadius, roomY + cornerRadius, cornerRadius)
        self:carveCircle(roomX + roomW - cornerRadius, roomY + cornerRadius, cornerRadius)
        self:carveCircle(roomX + cornerRadius, roomY + roomH - cornerRadius, cornerRadius)
        self:carveCircle(roomX + roomW - cornerRadius, roomY + roomH - cornerRadius, cornerRadius)
    end
end

function Dungeon:getRoomConnectionPoint(room, targetX, targetY)
    local cx = room.x + room.w / 2
    local cy = room.y + room.h / 2
    local dx = targetX - cx
    local dy = targetY - cy
    local inset = math.max(10, math.min(room.w, room.h) * 0.18)

    if math.abs(dx) > math.abs(dy) then
        local x = dx >= 0 and (room.x + room.w - inset) or (room.x + inset)
        return x, cy
    end

    local y = dy >= 0 and (room.y + room.h - inset) or (room.y + inset)
    return cx, y
end

function Dungeon:carveCorridor(x1, y1, x2, y2)
    -- carve a simple orthogonal corridor between two points to avoid diagonal paths
    local corridor = self.corridorWidth or 36
    local radiusPixels = math.max(self.gridSize, corridor * 0.5)
    local sx, sy = x1, y1
    local ex, ey = x2, y2

    local function carveSegment(ax, ay, bx, by)
        local dx, dy = bx - ax, by - ay
        local dist = math.sqrt(dx * dx + dy * dy)
        local step = math.max(1, self.gridSize * 0.6)
        local steps = math.max(1, math.floor(dist / step))
        for i = 0, steps do
            local t = steps == 0 and 0 or (i / steps)
            local px = ax + dx * t
            local py = ay + dy * t
            self:carveCircle(px, py, radiusPixels)
        end
    end

    self:carveCircle(sx, sy, radiusPixels + self.gridSize * 2)
    self:carveCircle(ex, ey, radiusPixels + self.gridSize * 2)

    if math.abs(ex - sx) >= math.abs(ey - sy) then
        carveSegment(sx, sy, ex, sy)
        carveSegment(ex, sy, ex, ey)
    else
        carveSegment(sx, sy, sx, ey)
        carveSegment(sx, ey, ex, ey)
    end
end

function Dungeon:ensureConnectivity()
    -- flood-fill from first room to find reachable grid cells
    if #self.rooms == 0 then return end
    local visited = {}
    for ty = 1, self.tilesY do visited[ty] = {} end
    local q = {}
    local first = self.rooms[1]
    local sx = math.floor((first.cx) / self.gridSize) + 1
    local sy = math.floor((first.cy) / self.gridSize) + 1
    if sx < 1 or sy < 1 or sx > self.tilesX or sy > self.tilesY then return end
    if not self.walkableGrid[sy] or not self.walkableGrid[sy][sx] then
        -- try to find any walkable cell near the first room
        for ty = math.max(1, sy-3), math.min(self.tilesY, sy+3) do
            for tx = math.max(1, sx-3), math.min(self.tilesX, sx+3) do
                if self.walkableGrid[ty] and self.walkableGrid[ty][tx] then sx, sy = tx, ty; break end
            end
        end
    end
    table.insert(q, {x = sx, y = sy})
    visited[sy][sx] = true
    local head = 1
    while head <= #q do
        local node = q[head]; head = head + 1
        local nx, ny = node.x, node.y
        local dirs = {{1,0},{-1,0},{0,1},{0,-1}}
        for _, d in ipairs(dirs) do
            local tx = nx + d[1]; local ty = ny + d[2]
            if tx >= 1 and ty >= 1 and tx <= self.tilesX and ty <= self.tilesY and not visited[ty][tx] then
                if self.walkableGrid[ty] and self.walkableGrid[ty][tx] then
                    visited[ty][tx] = true
                    table.insert(q, {x = tx, y = ty})
                end
            end
        end
    end

    -- check rooms and connect those not reachable
    local connected = {}
    for i, room in ipairs(self.rooms) do
        local gx = math.floor(room.cx / self.gridSize) + 1
        local gy = math.floor(room.cy / self.gridSize) + 1
        if gx >= 1 and gy >= 1 and gx <= self.tilesX and gy <= self.tilesY and visited[gy] and visited[gy][gx] then
            connected[i] = true
        else
            connected[i] = false
        end
    end
    -- connect unconnected rooms to nearest connected room
    for i, room in ipairs(self.rooms) do
        if not connected[i] then
            local bestDist = nil; local bestIdx = nil
            for j, ok in ipairs(connected) do
                if ok then
                    local dx = room.cx - self.rooms[j].cx
                    local dy = room.cy - self.rooms[j].cy
                    local d = dx*dx + dy*dy
                    if not bestDist or d < bestDist then bestDist = d; bestIdx = j end
                end
            end
            if bestIdx then
                self:carveCorridor(room.cx, room.cy, self.rooms[bestIdx].cx, self.rooms[bestIdx].cy)
                connected[i] = true
            else
                -- no connected rooms found; connect to first room
                self:carveCorridor(room.cx, room.cy, self.rooms[1].cx, self.rooms[1].cy)
                connected[i] = true
            end
        end
    end
    -- final slight smoothing to clean lone tiles
    self:smoothWalkableGrid(1)
end

function Dungeon:addWaterPuddles()
    for _, room in ipairs(self.rooms) do
        if math.random() > 0.6 then
            local px = room.x + math.random(10, room.w - 10)
            local py = room.y + math.random(10, room.h - 10)
            -- choose a slightly varied hue per puddle using room accent
            local hue = (math.random() < 0.6) and {0.2, 0.45, 0.8} or {0.22, 0.55, 0.28}
            -- blend with room accent for cohesion
            hue = { (hue[1] + room.accent[1]) * 0.5, (hue[2] + room.accent[2]) * 0.5, (hue[3] + room.accent[3]) * 0.5 }
            table.insert(self.waterPuddles, {x = px, y = py, r = math.random(6, 12), color = hue})
        end
    end
end

function Dungeon:addDecorations()
    for _, room in ipairs(self.rooms) do
        -- torches at corners
        table.insert(self.torches, {x = room.x + 8, y = room.y + 8, seed = math.random()*10})
        table.insert(self.torches, {x = room.x + room.w - 8, y = room.y + 8, seed = math.random()*10})
    end
    -- bones & cobwebs
    for i=1, 10 do
        table.insert(self.bones, {x = math.random(0, self.width), y = math.random(0, self.height)})
    end
    -- place some decals (crates, rugs) inside rooms
    for _, room in ipairs(self.rooms) do
        if math.random() < 0.35 then
            local dx = room.x + math.random(12, room.w - 24)
            local dy = room.y + math.random(12, room.h - 24)
            local r = math.random()
            local kind = "crate"
            if r < 0.18 then kind = "rug"
            elseif r < 0.45 then kind = "broken"
            elseif r < 0.6 then kind = "barrel" end
            table.insert(self.decals, {x = dx, y = dy, kind = kind})
        end
    end
end

function Dungeon:createEnderPortal(room)
    self.enderPortal = { x = room.cx, y = room.cy, w = 32, h = 32, anim = 0 }
end

function Dungeon:buildCollisionMap()
    self.collisionMap = {}
    self.walkableTiles = {}
    for ty = 1, self.tilesY do
        self.collisionMap[ty] = {}
        for tx = 1, self.tilesX do
            local isWalkable = self.walkableGrid[ty] and self.walkableGrid[ty][tx]

            -- check props that should block movement: pillars, barrels, broken tiles, some decals
            local cellX = (tx - 1) * self.gridSize
            local cellY = (ty - 1) * self.gridSize
            local cellW, cellH = self.gridSize, self.gridSize

            local blockedByProp = false
            -- pillars (12x12 centered at ph.x,ph.y)
            for _, ph in ipairs(self.pillars) do
                if ph.x + 6 > cellX and ph.x - 6 < cellX + cellW and ph.y + 6 > cellY and ph.y - 6 < cellY + cellH then
                    blockedByProp = true; break
                end
            end

            -- barrels (circle)
            if not blockedByProp then
                for _, br in ipairs(self.barrels) do
                    local closestX = math.max(cellX, math.min(br.x, cellX + cellW))
                    local closestY = math.max(cellY, math.min(br.y, cellY + cellH))
                    local dx = closestX - br.x
                    local dy = closestY - br.y
                    if dx * dx + dy * dy <= (br.r or 6) * (br.r or 6) then blockedByProp = true; break end
                end
            end

            -- broken tile clusters (rect)
            if not blockedByProp then
                for _, b in ipairs(self.brokenTiles) do
                    if b.x < cellX + cellW and b.x + b.w > cellX and b.y < cellY + cellH and b.y + b.h > cellY then
                        blockedByProp = true; break
                    end
                end
            end

            -- decals that represent barrels/broken also block
            if not blockedByProp then
                for _, d in ipairs(self.decals) do
                    if d.kind == "barrel" then
                        local bx, by, br = d.x + 6, d.y + 4, 6
                        local closestX = math.max(cellX, math.min(bx, cellX + cellW))
                        local closestY = math.max(cellY, math.min(by, cellY + cellH))
                        local dx = closestX - bx; local dy = closestY - by
                        if dx * dx + dy * dy <= br * br then blockedByProp = true; break end
                    elseif d.kind == "broken" then
                        local dw, dh = 12, 8
                        if d.x < cellX + cellW and d.x + dw > cellX and d.y < cellY + cellH and d.y + dh > cellY then
                            blockedByProp = true; break
                        end
                    end
                end
            end

            if blockedByProp then isWalkable = false end

            self.collisionMap[ty][tx] = not isWalkable
            if isWalkable then table.insert(self.walkableTiles, {x = tx, y = ty}) end
        end
    end
end

function Dungeon:buildSpriteBatch()
    -- Legacy spriteBatch/tileset removed. We only need simple grid dimensions.
    local ts = self.tileSize
    self.simpleTilesX = math.ceil(self.width / ts)
    self.simpleTilesY = math.ceil(self.height / ts)
    self.spriteBatch = nil
end

function Dungeon:cellIsWalkable(px, py)
    local gx = math.floor(px / self.gridSize) + 1
    local gy = math.floor(py / self.gridSize) + 1
    return self.walkableGrid[gy] and self.walkableGrid[gy][gx]
end

function Dungeon:shouldDrawWallTile(px, py)
    if self:cellIsWalkable(px, py) then return false end

    local checks = {
        {0, -self.gridSize},
        {0, self.gridSize},
        {-self.gridSize, 0},
        {self.gridSize, 0},
        {-self.gridSize, -self.gridSize},
        {self.gridSize, -self.gridSize},
        {-self.gridSize, self.gridSize},
        {self.gridSize, self.gridSize},
    }

    local walkableNeighbors = 0
    for _, delta in ipairs(checks) do
        if self:cellIsWalkable(px + delta[1], py + delta[2]) then
            walkableNeighbors = walkableNeighbors + 1
        end
    end

    return walkableNeighbors >= 1
end

function Dungeon:buildStaticCanvas()
    if not love or not love.graphics then return end
    if self.staticCanvas then self.staticCanvas:release() end
    self.staticCanvas = love.graphics.newCanvas(self.width, self.height)
    local prevCanvas = love.graphics.getCanvas()
    love.graphics.setCanvas(self.staticCanvas)
    love.graphics.clear(0,0,0,0)
    love.graphics.push()
    love.graphics.origin()

    local function ix(v) return math.floor(v + 0.5) end
    local function quant(c) return math.floor(c * 5 + 0.5) / 5 end
    local function noise(x,y)
        return math.abs(math.sin(x * 12.9898 + y * 78.233) * 43758.5453) % 1
    end
    local ts = self.tileSize

    -- draw room floors
    for _, room in ipairs(self.rooms) do
        local tint = room.tint or self.simpleFloorColor
        love.graphics.setColor(tint)
        love.graphics.rectangle("fill", ix(room.x), ix(room.y), ix(room.w), ix(room.h))
        for py = room.y, room.y + room.h - 1, ts do
            for px = room.x, room.x + room.w - 1, ts do
                local n = noise(px + room.patternSeed, py + room.patternSeed)
                if n > 0.7 then
                    love.graphics.setColor(math.max(0, tint[1] - 0.05), math.max(0, tint[2] - 0.05), math.max(0, tint[3] - 0.05))
                    love.graphics.rectangle("fill", ix(px + (n * (ts-4) + 2)), ix(py + ((1-n) * (ts-4) + 2)), 2, 1)
                    love.graphics.setColor(tint)
                end
            end
        end
    end

    -- draw corridor / other floors
    love.graphics.setColor(self.simpleFloorColor)
    for ty = 0, self.simpleTilesY - 1 do
        for tx = 0, self.simpleTilesX - 1 do
            local px = tx * ts
            local py = ty * ts
            local midX = math.floor(px + ts/2)
            local midY = math.floor(py + ts/2)
            if self:cellIsWalkable(midX, midY) then
                local inRoom = false
                for _, r in ipairs(self.rooms) do
                    if midX >= r.x and midX < r.x + r.w and midY >= r.y and midY < r.y + r.h then
                        inRoom = true
                        break
                    end
                end
                if not inRoom then
                    local n = noise(px, py)
                    love.graphics.setColor(self.simpleFloorColor[1] + (n - 0.5) * 0.06, self.simpleFloorColor[2] + (n - 0.5) * 0.06, self.simpleFloorColor[3] + (n - 0.5) * 0.06)
                    love.graphics.rectangle("fill", ix(px), ix(py), ts, ts)
                    if n > 0.86 then
                        love.graphics.setColor(0.12, 0.14, 0.16)
                        love.graphics.rectangle("fill", ix(px + (n - 0.5) * ts), ix(py + (1 - n) * ts), 2, 1)
                        love.graphics.setColor(self.simpleFloorColor)
                    end
                end
            end
        end
    end

    -- draw a continuous wall shell around every walkable room and corridor tile
    love.graphics.setColor({quant(self.simpleWallColor[1]), quant(self.simpleWallColor[2]), quant(self.simpleWallColor[3])})
    for ty = 0, self.simpleTilesY - 1 do
        for tx = 0, self.simpleTilesX - 1 do
            local px = tx * ts
            local py = ty * ts
            local midX = math.floor(px + ts/2)
            local midY = math.floor(py + ts/2)
            if self:cellIsWalkable(midX, midY) then
                local north = not self:cellIsWalkable(midX, midY - self.gridSize)
                local south = not self:cellIsWalkable(midX, midY + self.gridSize)
                local west = not self:cellIsWalkable(midX - self.gridSize, midY)
                local east = not self:cellIsWalkable(midX + self.gridSize, midY)

                if north then love.graphics.rectangle("fill", ix(px), ix(py), ts, 2) end
                if west then love.graphics.rectangle("fill", ix(px), ix(py), 2, ts) end
                if south then love.graphics.rectangle("fill", ix(px), ix(py + ts - 2), ts, 2) end
                if east then love.graphics.rectangle("fill", ix(px + ts - 2), ix(py), 2, ts) end

                if north and west then love.graphics.rectangle("fill", ix(px), ix(py), 2, 2) end
                if north and east then love.graphics.rectangle("fill", ix(px + ts - 2), ix(py), 2, 2) end
                if south and west then love.graphics.rectangle("fill", ix(px), ix(py + ts - 2), 2, 2) end
                if south and east then love.graphics.rectangle("fill", ix(px + ts - 2), ix(py + ts - 2), 2, 2) end
            end
        end
    end

    -- draw walls after floors so they never cover the room/corridor openings
    love.graphics.setColor({quant(self.simpleWallColor[1]), quant(self.simpleWallColor[2]), quant(self.simpleWallColor[3])})
    for ty = 0, self.simpleTilesY - 1 do
        for tx = 0, self.simpleTilesX - 1 do
            local px = tx * ts
            local py = ty * ts
            local midX = math.floor(px + ts/2)
            local midY = math.floor(py + ts/2)
            if self:shouldDrawWallTile(midX, midY) then
                love.graphics.rectangle("fill", ix(px), ix(py), ts, ts)
            end
        end
    end

    -- draw wall detail
    for ty = 0, self.simpleTilesY - 1 do
        for tx = 0, self.simpleTilesX - 1 do
            local px = tx * ts
            local py = ty * ts
            local midX = math.floor(px + ts/2)
            local midY = math.floor(py + ts/2)
            if self:shouldDrawWallTile(midX, midY) then
                local north = self:cellIsWalkable(midX, midY - self.gridSize)
                local south = self:cellIsWalkable(midX, midY + self.gridSize)
                local west = self:cellIsWalkable(midX - self.gridSize, midY)
                local east = self:cellIsWalkable(midX + self.gridSize, midY)
                love.graphics.setColor(0,0,0)
                if north then love.graphics.rectangle("fill", ix(px), ix(py), ts, 2) end
                if west then love.graphics.rectangle("fill", ix(px), ix(py), 2, ts) end
                love.graphics.setColor(1,1,1,0.09)
                if south then love.graphics.rectangle("fill", ix(px), ix(py + ts - 2), ts, 2) end
                if east then love.graphics.rectangle("fill", ix(px + ts - 2), ix(py), 2, ts) end
                if north then love.graphics.rectangle("fill", ix(px) + 1, ix(py) + 1, ts - 2, 1) end

                -- extra wall detailing: moss and subtle brick lines where wall meets floor
                local adjacent = north or south or west or east
                if adjacent then
                    local n = noise(tx, ty)
                    if n > 0.88 then
                        love.graphics.setColor(0.14, 0.28, 0.12, 0.85)
                        love.graphics.circle("fill", ix(px + ts * (0.2 + (n - 0.88) * 0.6)), ix(py + ts * (0.2 + (n - 0.88) * 0.6)), 2)
                    end
                    love.graphics.setColor(0,0,0,0.06)
                    for by = 4, ts - 4, 6 do
                        love.graphics.rectangle("fill", ix(px + 2), ix(py + by), ts - 4, 1)
                    end
                end

                love.graphics.setColor(1,1,1)
            end
        end
    end

    if self.enderPortal then
        love.graphics.setColor(0.6, 0.0, 0.8, 0.5)
        love.graphics.circle("fill", self.enderPortal.x, self.enderPortal.y, 20)
        love.graphics.setColor(1,1,1)
    end

    love.graphics.setBlendMode("alpha")
    for _, p in ipairs(self.waterPuddles) do
        local c = p.color or {0.2, 0.45, 0.8}
        love.graphics.setColor(c[1], c[2], c[3], 0.5)
        love.graphics.circle("fill", ix(p.x), ix(p.y), p.r)
        love.graphics.setColor(math.min(1, c[1] + 0.15), math.min(1, c[2] + 0.18), math.min(1, c[3] + 0.25), 0.28)
        love.graphics.circle("fill", ix(p.x - 2), ix(p.y - 2), math.max(2, math.floor(p.r * 0.6)))
    end
    for _, d in ipairs(self.decals) do
        if d.kind == "crate" then
            love.graphics.setColor(0.2, 0.12, 0.06)
            love.graphics.rectangle("fill", d.x, d.y, 12, 8)
            love.graphics.setColor(0, 0, 0, 0.6)
            love.graphics.rectangle("line", d.x, d.y, 12, 8)
        elseif d.kind == "rug" then
            love.graphics.setColor(0.55, 0.18, 0.12)
            love.graphics.rectangle("fill", d.x, d.y, 18, 10)
            love.graphics.setColor(0, 0, 0, 0.3)
            love.graphics.rectangle("line", d.x, d.y, 18, 10)
        elseif d.kind == "barrel" then
            love.graphics.setColor(0.18, 0.08, 0.04)
            love.graphics.circle("fill", d.x + 6, d.y + 4, 6)
            love.graphics.setColor(0, 0, 0, 0.5)
            love.graphics.circle("line", d.x + 6, d.y + 4, 6)
        elseif d.kind == "broken" then
            love.graphics.setColor(0.08, 0.06, 0.06)
            for i = 1, 3 do
                love.graphics.rectangle("fill", d.x + math.random(-4, 8), d.y + math.random(-4, 8), math.random(2, 6), math.random(1, 3))
            end
        end
    end
    love.graphics.setColor(0.9, 0.9, 0.8)
    for _, b in ipairs(self.bones) do
        love.graphics.line(b.x - 4, b.y, b.x + 4, b.y)
    end
    love.graphics.setColor(1,1,1,0.25)
    love.graphics.setLineWidth(1)
    for _, web in ipairs(self.cobwebs) do
        love.graphics.line(web.x, web.y, web.x + 12, web.y)
        love.graphics.line(web.x, web.y, web.x, web.y + 12)
    end
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1,1,1)
    for _, ph in ipairs(self.pillars) do
        love.graphics.setColor(0.12, 0.12, 0.14)
        love.graphics.rectangle("fill", ph.x - 6, ph.y - 6, 12, 12)
        love.graphics.setColor(0,0,0,0.6)
        love.graphics.rectangle("line", ph.x - 6, ph.y - 6, 12, 12)
    end
    for _, b in ipairs(self.brokenTiles) do
        love.graphics.setColor(0.06, 0.05, 0.05)
        love.graphics.rectangle("fill", b.x, b.y, b.w, b.h)
        love.graphics.setColor(0,0,0,0.45)
        love.graphics.rectangle("line", b.x, b.y, b.w, b.h)
    end
    for _, br in ipairs(self.barrels) do
        love.graphics.setColor(0.16, 0.08, 0.03)
        love.graphics.circle("fill", br.x, br.y, br.r)
        love.graphics.setColor(0,0,0,0.5)
        love.graphics.circle("line", br.x, br.y, br.r)
    end
    for _, m in ipairs(self.mossPatches) do
        love.graphics.setColor(0.18, 0.32, 0.12, 0.6)
        love.graphics.circle("fill", m.x, m.y, m.r)
    end
    love.graphics.setBlendMode("alpha")

    love.graphics.pop()
    love.graphics.setCanvas(prevCanvas)
end

function Dungeon:render()
    if not self.staticCanvas then self:buildStaticCanvas() end
    love.graphics.setColor(1,1,1)
    love.graphics.draw(self.staticCanvas, 0, 0)

    local function ix(v) return math.floor(v + 0.5) end
    local time = love.timer.getTime()
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
        love.graphics.setColor(warm[1], warm[2], warm[3], 0.06 * flick)
        love.graphics.polygon("fill", ix(x) - 6 * flick, ix(y) + 2, ix(x) + 6 * flick, ix(y) + 2, ix(x), ix(y) + 40 * flick)
        love.graphics.setBlendMode("alpha")
    end

    love.graphics.setBlendMode("alpha")
    local t = love.timer.getTime()
    for _, d in ipairs(self.dustParticles) do
        local ox = math.sin(t * 0.4 + d.seed) * 6
        local oy = math.cos(t * 0.25 + d.seed) * 4
        local alpha = 0.06 + (math.sin(t + d.seed) + 1) * 0.02
        love.graphics.setColor(1,1,1, alpha)
        love.graphics.circle("fill", d.x + ox, d.y + oy, d.r)
    end
    love.graphics.setBlendMode("alpha")
end

-- utility: check if player reached exit
function Dungeon:playerReachedExit(px, py, playerRadius)
    if not self.enderPortal then return false end
    local dx = px - self.enderPortal.x
    local dy = py - self.enderPortal.y
    local d = math.sqrt(dx*dx + dy*dy)
    return d < (playerRadius + (self.enderPortal.w or 16) / 2)
end

-- Spawn helpers
function Dungeon:getLeftmostSpawnPoint(w, h, padding)
    if #self.rooms == 0 then return nil end
    local room = self.rooms[1]
    local x, y = room.cx, room.cy
    if self:canFitAtCenter(x, y, w, h, padding) then return x, y end
    return self:getRandomSpawnPoint(w, h, padding)
end

function Dungeon:getRightmostSpawnPoint(w, h, padding)
    if #self.rooms == 0 then return nil end
    local room = self.rooms[#self.rooms]
    local x, y = room.cx, room.cy
    if self:canFitAtCenter(x, y, w, h, padding) then return x, y end
    return self:getRandomSpawnPoint(w, h, padding)
end

function Dungeon:getSpawnPointsOutsideSafeRoom(count, w, h, padding, knightX, knightY)
    local results = {}
    padding = padding or 0
    knightX = knightX or 0; knightY = knightY or 0
    local safeR = 150
    for i = 2, #self.rooms do
        if #results >= count then break end
        local room = self.rooms[i]
        local x = room.cx + math.random(-room.w/3, room.w/3)
        local y = room.cy + math.random(-room.h/3, room.h/3)
        if (x - knightX)^2 + (y - knightY)^2 > safeR * safeR then
            if self:canFitAtCenter(x, y, w, h, padding) then
                table.insert(results, {x = x, y = y})
            end
        end
    end
    return results
end

function Dungeon:getRandomSpawnPoint(w, h, padding)
    if #self.walkableTiles == 0 then return nil end
    padding = padding or 0
    local shuffled = {}
    for i=1,#self.walkableTiles do table.insert(shuffled, i) end
    for i=#shuffled,2,-1 do local j = math.random(i); shuffled[i], shuffled[j] = shuffled[j], shuffled[i] end
    for _, idx in ipairs(shuffled) do
        local spot = self.walkableTiles[idx]
        local x = (spot.x - 0.5) * self.gridSize
        local y = (spot.y - 0.5) * self.gridSize
        if self:canFitAtCenter(x, y, w, h, padding) then return x, y end
    end
    return nil
end

-- collision & LOS
function Dungeon:isBlocked(x, y)
    if x < 0 or y < 0 or x >= self.width or y >= self.height then return true end
    local tx = math.floor(x / self.gridSize) + 1
    local ty = math.floor(y / self.gridSize) + 1
    if not self.collisionMap[ty] or self.collisionMap[ty][tx] == nil then return true end
    return self.collisionMap[ty][tx]
end

function Dungeon:hasLineOfSight(x1,y1,x2,y2)
    local dx = x2 - x1; local dy = y2 - y1
    local dist = math.sqrt(dx*dx + dy*dy)
    if dist < 1 then return true end
    local step = self.gridSize / 2
    local steps = math.floor(dist / step)
    for i=1,steps do
        local tx = x1 + (dx / dist) * (i * step)
        local ty = y1 + (dy / dist) * (i * step)
        if self:isBlocked(tx, ty) then return false end
    end
    return true
end

function Dungeon:isColliding(x,y,w,h)
    if x < 0 or y < 0 or x + w > self.width or y + h > self.height then return true end
    local epsilon = 0.0001
    local sx = math.floor(x / self.gridSize) + 1
    local sy = math.floor(y / self.gridSize) + 1
    local ex = math.floor((x + w - epsilon) / self.gridSize) + 1
    local ey = math.floor((y + h - epsilon) / self.gridSize) + 1
    for ty = sy, ey do
        for tx = sx, ex do
            if not self.collisionMap[ty] or self.collisionMap[ty][tx] == nil then return true end
            if self.collisionMap[ty][tx] then return true end
        end
    end
    return false
end

function Dungeon:canFitAtCenter(x,y,w,h,padding)
    if not w or not h then return true end
    padding = padding or 0
    local left = x - w/2; local top = y - h/2
    if left < padding or top < padding or left + w > self.width - padding or top + h > self.height - padding then return false end
    return not self:isColliding(x - w/2, y - h/2, w, h)
end

return Dungeon
