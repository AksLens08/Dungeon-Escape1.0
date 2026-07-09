-- lighting.lua
-- Light FX
local Class = require("system.class")
local Lighting = Class.define()

-- Simplified torch lighting: only a small flickering light around the player.
-- The rest of the screen is dark (torch-in-hand effect).
function Lighting:init(player)
    self.player = player
    -- darkness 1.0 = fully dark, lower values allow ambient light
    self.darkness = 0.95
    -- base radius in pixels (will be multiplied by scale)
    self.baseRadius = 40

    self.lightCanvas = nil
    self.canvasW, self.canvasH = 0, 0
    -- seed for noise-based flicker
    self.noiseSeed = (math.random and math.random() or 0.5) * 1000
end

function Lighting:update(dt)
    -- nothing to update per-frame here; flicker computed in render
end

local function drawRimGlow(x, y, outerRadius, innerRadius, color, intensity)
    -- Draw soft rim between innerRadius and outerRadius (leaves center untouched)
    local steps = 12
    local span = math.max(0.0001, outerRadius - innerRadius)
    for i = steps, 1, -1 do
        local t = i / steps
        local r = innerRadius + span * t
        local a = (intensity or 1) * (t) * 0.03
        love.graphics.setColor(color[1], color[2], color[3], a)
        love.graphics.circle('fill', x, y, r)
    end
end

function Lighting:render(camX, camY, scale)
    local sw, sh = love.graphics.getDimensions()
    if not self.lightCanvas or self.canvasW ~= sw or self.canvasH ~= sh then
        self.lightCanvas = love.graphics.newCanvas(sw, sh)
        self.canvasW, self.canvasH = sw, sh
    end
    -- Compute player light position
    if not self.player then return end
    local time = love.timer.getTime()
    local px, py
    if type(self.player.getLightPosition) == 'function' then
        px, py = self.player:getLightPosition()
    elseif type(self.player.getCenter) == 'function' then
        px, py = self.player:getCenter()
    else
        px, py = (self.player.x or 0) + (self.player.w or 0) / 2, (self.player.y or 0) + (self.player.h or 0) / 2
    end

    local sx, sy = (px * scale) - camX, (py * scale) - camY
    -- slight forward offset to simulate torch held in front of the player
    local faceOffset = 6 * scale
    local ox, oy = 0, -2 * scale
    if type(self.player.direction) == 'string' then
        if self.player.direction == 'right' then ox = faceOffset elseif self.player.direction == 'left' then ox = -faceOffset end
    end

    -- flicker: slow smooth variation (fire) + small fast sparkle
    local slow, fast
    if love.math and love.math.noise then
        slow = love.math.noise(self.noiseSeed, time * 0.6)
        fast = love.math.noise(self.noiseSeed + 100, time * 3.5)
    else
        slow = 0.5 + 0.5 * math.sin(time * 0.6)
        fast = 0.5 + 0.5 * math.sin(time * 3.5)
    end
    -- center slow around 0 and scale: slow contributes larger, fast small sparkle
    local flick = 1 + (slow - 0.5) * 0.28 + (fast - 0.5) * 0.08
    local radius = self.baseRadius * scale * flick

    -- Create a stencil circle marking the visible area (1 inside circle)
    love.graphics.stencil(function()
        love.graphics.circle("fill", sx, sy, radius)
    end, "replace", 1)

    -- Draw black rectangle only where stencil == 0 (outside the circle)
    love.graphics.setStencilTest("equal", 0)
    love.graphics.setColor(0, 0, 0, self.darkness)
    love.graphics.rectangle("fill", 0, 0, sw, sh)
    love.graphics.setStencilTest()

    -- Draw a subtle alpha rim transition between inner and outer radii
    local inner = radius * 0.55
    local outer = radius * 1.15
    -- No additive core or inner fill: keep the center fully normal and only soft rim
    drawRimGlow(sx + ox, sy + oy, outer, inner, {1, 0.95, 0.60}, 1.0 * flick)
end

return Lighting
