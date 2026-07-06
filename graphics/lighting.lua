-- lighting.lua
-- Light FX
local Class = require("system.class")
local Lighting = Class.define()

-- Lighting system: renders multiple soft lights to a canvas, supports torch flicker,
-- player light, ambient fog, and simple additive blending to brighten areas.
function Lighting:init(knight, dungeon)
    self.knight = knight
    self.dungeon = dungeon
    self.darkness = 0
    self.playerRadius = 90

    self.lightCanvas = nil
    self.canvasW, self.canvasH = 0, 0

    self.ambientFog = {0.02, 0.03, 0.04, 0.15}

    -- per-torch seeds handled in dungeon.torches
end

function Lighting:update(dt)
    -- nothing heavy here; torches are animated in render via time
end

local function drawSoftLight(x, y, radius, intensity)
    -- approximate soft falloff with concentric circles
    local steps = 6
    for i = steps, 1, -1 do
        local r = radius * (i / steps)
        local a = intensity * (i / steps) * 0.9
        love.graphics.setColor(1,1,1,a)
        love.graphics.circle('fill', x, y, r)
    end
end

function Lighting:render(camX, camY, scale)
    local sw, sh = love.graphics.getDimensions()
    -- ensure canvas matches screen
    if not self.lightCanvas or self.canvasW ~= sw or self.canvasH ~= sh then
        self.lightCanvas = love.graphics.newCanvas(sw, sh)
        self.canvasW, self.canvasH = sw, sh
    end

    -- draw lights into canvas with additive blending
    love.graphics.setCanvas(self.lightCanvas)
    love.graphics.clear(0,0,0,0)
    love.graphics.setBlendMode('add')

    local time = love.timer.getTime()

    -- player light
    if self.knight and self.knight.getLightPosition then
        local px, py = self.knight:getLightPosition()
        local sx, sy = (px * scale) - camX, (py * scale) - camY
        local pr = self.playerRadius * scale
        drawSoftLight(sx, sy, pr, 0.9)
    end

    -- torches
    if self.dungeon and self.dungeon.torches then
        for _, t in ipairs(self.dungeon.torches) do
            local tx, ty = (t.x * scale) - camX, (t.y * scale) - camY
            local s = (t.seed or 0) + time * 6
            local flick = 1 + math.sin(s) * 0.12 + (math.sin(s*1.7) * 0.06)
            local radius = 60 * flick * scale
            drawSoftLight(tx, ty, radius, 0.85 * flick)
            -- small warm center
            love.graphics.setColor(1,0.8,0.5, 0.9 * flick)
            love.graphics.circle('fill', tx, ty, 6 * scale)
        end
    end

    love.graphics.setBlendMode('alpha')
    love.graphics.setCanvas()

    -- composite: darken screen then add lights
    love.graphics.setColor(0,0,0, self.darkness)
    love.graphics.rectangle('fill', 0, 0, sw, sh)
    love.graphics.setBlendMode('add')
    love.graphics.setColor(1,1,1,1)
    love.graphics.draw(self.lightCanvas, 0, 0)
    love.graphics.setBlendMode('alpha')

    -- ambient fog/color grade
    love.graphics.setColor(self.ambientFog)
    love.graphics.rectangle('fill', 0, 0, sw, sh)
    love.graphics.setColor(1,1,1)
end

return Lighting
