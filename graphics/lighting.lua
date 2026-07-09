-- lighting.lua
-- Light FX
local Class = require("system.class")
local Lighting = Class.define()

-- Simplified torch lighting: only a small flickering light around the player.
-- The rest of the screen is dark (torch-in-hand effect).
function Lighting:init(player)
    self.player = player
    -- darkness 1.0 = fully dark, lower values allow ambient light
    self.darkness = 1.0
    -- base radius in pixels (will be multiplied by scale)
    self.baseRadius = 64

    self.lightCanvas = nil
    self.canvasW, self.canvasH = 0, 0
end

function Lighting:update(dt)
    -- nothing to update per-frame here; flicker computed in render
end

local function drawSoftLight(x, y, radius, intensity)
    -- smoother falloff using multiple rings
    local steps = 8
    for i = steps, 1, -1 do
        local r = radius * (i / steps)
        local a = intensity * (i / steps)
        love.graphics.setColor(1, 1, 1, a)
        love.graphics.circle('fill', x, y, r)
    end
end

function Lighting:render(camX, camY, scale)
    local sw, sh = love.graphics.getDimensions()
    if not self.lightCanvas or self.canvasW ~= sw or self.canvasH ~= sh then
        self.lightCanvas = love.graphics.newCanvas(sw, sh)
        self.canvasW, self.canvasH = sw, sh
    end

    -- Draw the player light onto the canvas using additive blending
    love.graphics.setCanvas(self.lightCanvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setBlendMode('add')

    if self.player then
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

        -- flicker effect
        local flick = 1 + (math.sin(time * 12) * 0.08) + (math.sin(time * 7.3) * 0.04)
        local radius = self.baseRadius * scale * flick
        local intensity = 1.0 * flick

        -- central warm core
        love.graphics.setColor(1, 0.9, 0.7, 0.9 * flick)
        love.graphics.circle('fill', sx, sy, math.max(4 * scale, radius * 0.08))

        -- soft falloff rings
        drawSoftLight(sx, sy, radius, intensity * 0.9)
    end

    love.graphics.setBlendMode('alpha')
    love.graphics.setCanvas()

    -- Composite: fill screen with black, then add the light canvas
    love.graphics.setColor(0, 0, 0, self.darkness)
    love.graphics.rectangle('fill', 0, 0, sw, sh)

    love.graphics.setBlendMode('add')
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self.lightCanvas, 0, 0)
    love.graphics.setBlendMode('alpha')
end

return Lighting
