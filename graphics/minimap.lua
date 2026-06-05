-- minimap.lua
local Class = require("system.class")
local Minimap = Class.define()

local MINIMAP_SCALE_SMALL   = 0.12
local MINIMAP_PADDING       = 1
local MINIMAP_MARGIN        = 1
local MINIMAP_OFFSET_X      = 20
local CORNER_RADIUS         = 3

local BLIP_PLAYER  = 10
local BLIP_ENEMY   = 3
local BLIP_KM      = 5
local BLIP_COIN    = 2

local COL_BG_BORDER  = { 0.10, 0.10, 0.14, 0.92 }
local COL_BG_INNER   = { 0.05, 0.05, 0.08, 0.82 }
local COL_FLOOR      = { 0.60, 0.60, 0.60, 1.00 }
local COL_WALL       = { 0.10, 0.08, 0.06, 0.00 }
local COL_PLAYER     = { 0.20, 0.90, 0.30, 1.00 }
local COL_ENEMY      = { 0.95, 0.25, 0.15, 1.00 }
local COL_KM         = { 1.00, 0.00, 0.00, 1.00 }
local COL_COIN       = { 1.00, 0.85, 0.15, 1.00 }
local COL_VIEWPORT   = { 1.00, 1.00, 1.00, 0.18 }
local COL_VP_BORDER  = { 1.00, 1.00, 1.00, 0.40 }
local COL_LABEL      = { 0.85, 0.85, 0.85, 0.85 }
local COL_KEY_HINT   = { 0.55, 0.55, 0.55, 0.70 }

function Minimap:init(dungeon)
    self.dungeon    = dungeon
    self.alpha      = 1
    self.mapCanvas  = nil
    self.position   = "top-right"
    self.player     = nil
    self.camera     = { x = 0, y = 0 }
    self.offsetX = 0
    self.offsetY = 0
    self.followPlayer = true
    self.dragStartX = 0
    self.dragStartY = 0
    self.scaleAnim  = MINIMAP_SCALE_SMALL
    self.pulse      = 0
    self:_buildCanvas()
end

function Minimap:_buildCanvas()
    local d = self.dungeon
    if not d then return end
    local cw = d.width
    local ch = d.height
    self.mapCanvas = love.graphics.newCanvas(cw, ch)
    self.mapCanvas:setFilter("nearest", "nearest")
    love.graphics.push("all")
    love.graphics.setCanvas(self.mapCanvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setBlendMode("alpha")
    local gs = d.gridSize
    for ty, row in pairs(d.collisionMap) do
        for tx, blocked in pairs(row) do
            if not blocked then
                love.graphics.setColor(COL_FLOOR)
                local px = (tx - 1) * gs
                local py = (ty - 1) * gs
                love.graphics.rectangle("fill", px, py, gs, gs)
            end
        end
    end
    love.graphics.setCanvas()
    love.graphics.pop()
end

function Minimap:update(player, enemies, coins, camera, dt)
    local d = self.dungeon
    if not d then return end
    self.player = player
    self.enemies = enemies or {}
    self.camera = camera or { x = 0, y = 0 }
    local sc = self.scaleAnim
    local mapW = d.width * sc
    local mapH = d.height * sc
    self.scaleAnim = MINIMAP_SCALE_SMALL
    sc = MINIMAP_SCALE_SMALL
    self.pulse = (self.pulse or 0) + (dt or 0.016) * 3
    if self.followPlayer and self.player then
        local px, py = self.player:getCenter()
        local targetOffsetX = (mapW / 2) - (px * sc)
        local targetOffsetY = (mapH / 2) - (py * sc)
        
        local followSpeed = 10
        self.offsetX = self.offsetX + (targetOffsetX - self.offsetX) * math.min(1, followSpeed * (dt or 0.016))
        self.offsetY = self.offsetY + (targetOffsetY - self.offsetY) * math.min(1, followSpeed * (dt or 0.016))
    end
    self.offsetX = math.max(-(d.width * sc) + (mapW / 2), math.min(mapW / 2, self.offsetX))
    self.offsetY = math.max(-(d.height * sc) + (mapH / 2), math.min(mapH / 2, self.offsetY))
end

function Minimap:setPositionNext()
    local order = {"top-right", "bottom-right", "bottom-left", "top-left"}
    local idx = 1
    for i, pos in ipairs(order) do
        if pos == self.position then idx = i; break end
    end
    self.position = order[(idx % #order) + 1]
end

local function setCol(c, a)
    love.graphics.setColor(c[1], c[2], c[3], (c[4] or 1) * (a or 1))
end

function Minimap:draw()
    if not self.mapCanvas then return end
    local d    = self.dungeon
    local sc   = self.scaleAnim
    local mapW = d.width  * sc
    local mapH = d.height * sc
    local sw, sh = love.graphics.getDimensions()
local frameX, frameY = 0, 0
if self.position == "top-right" then
    frameX = sw - mapW - MINIMAP_PADDING - MINIMAP_MARGIN * 2
    frameY = MINIMAP_PADDING + MINIMAP_MARGIN * 2
elseif self.position == "top-left" then
    frameX = MINIMAP_PADDING + MINIMAP_MARGIN * 2
    frameY = MINIMAP_PADDING + MINIMAP_MARGIN * 2
elseif self.position == "bottom-right" then
    frameX = sw - mapW - MINIMAP_PADDING - MINIMAP_MARGIN * 2
    frameY = sh - mapH - MINIMAP_PADDING - MINIMAP_MARGIN * 2
elseif self.position == "bottom-left" then
    frameX = MINIMAP_PADDING + MINIMAP_MARGIN * 2
    frameY = sh - mapH - MINIMAP_PADDING - MINIMAP_MARGIN * 2
end

frameX = frameX + MINIMAP_OFFSET_X
local frameW = mapW + MINIMAP_MARGIN * 2
local frameH = mapH + MINIMAP_MARGIN * 2 + 22

    love.graphics.push("all")
    love.graphics.setBlendMode("alpha")

    -- ── map area calculations ─────────────────────────────────────────────────
    local mapOriginX = frameX + MINIMAP_MARGIN
    local mapOriginY = frameY + 22 + MINIMAP_MARGIN
    local mapCircleX = mapOriginX + mapW / 2
    local mapCircleY = mapOriginY + mapH / 2
    local mapCircleRadius = (math.min(mapW, mapH) / 2) * 0.9

    -- ── circular background & border ──────────────────────────────────────────
    setCol(COL_BG_BORDER)
    love.graphics.circle("fill", mapCircleX, mapCircleY, mapCircleRadius + 2)
    setCol(COL_BG_INNER)
    love.graphics.circle("fill", mapCircleX, mapCircleY, mapCircleRadius)

    -- ── label ─────────────────────────────────────────────────────────────────
    local font = gFonts and gFonts["hud"]
    if font then
        love.graphics.setFont(font)
    end
    setCol(COL_LABEL)
    love.graphics.print("MINIMAP", frameX + MINIMAP_MARGIN, frameY + 4)

    -- Apply stencil to make the map content circular
    love.graphics.stencil(function()
        love.graphics.circle("fill", mapCircleX, mapCircleY, mapCircleRadius)
    end, "replace", 1)
    love.graphics.setStencilTest("greater", 0)

    -- ── Start Content Layer ──────────────────────────────────────────────────
    
    -- ── dungeon canvas ────────────────────────────────────────────────────────
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self.mapCanvas, mapOriginX + self.offsetX, mapOriginY + self.offsetY, 0, sc, sc)

    -- ── KM Boss blip ──────────────────────────────────────────────────────────
    if self.enemies then
        for _, e in ipairs(self.enemies) do
            -- Only draw the KM boss blip if they are alive
            if e and e.name == "KM" and e.hp and e.hp > 0 then -- KM is now a boss
                local ex = mapOriginX + self.offsetX + (e.x + (e.w or 16) / 2) * sc
                local ey = mapOriginY + self.offsetY + (e.y + (e.h or 16) / 2) * sc
                setCol(COL_KM)
                love.graphics.circle("fill", ex, ey, BLIP_KM)
            end
        end
    end

    -- ── player blip ───────────────────────────────────────────────────────────
    if self.player then
        local bxCenter, byCenter = self.player:getCenter()
        local bx = mapOriginX + self.offsetX + bxCenter * sc
        local by = mapOriginY + self.offsetY + byCenter * sc

        -- Outer glow pulse
        love.graphics.setColor(COL_PLAYER[1], COL_PLAYER[2], COL_PLAYER[3],
            0.3 + 0.2 * math.sin(self.pulse))
        love.graphics.circle("fill", bx, by, BLIP_PLAYER + 3)

        -- Core dot
        setCol(COL_PLAYER)
        love.graphics.circle("fill", bx, by, BLIP_PLAYER)

        -- White center pinpoint
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.circle("fill", bx, by, 1.5)
    end

    -- Disable stencil after drawing map elements
    love.graphics.setStencilTest()

    love.graphics.pop()
end

return Minimap