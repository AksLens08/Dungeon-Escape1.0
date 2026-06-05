-- lighting.lua
local Class = require("system.class")
local Lighting = Class.define()

function Lighting:init(knight)
    self.knight = knight
    self.radius = 80
    self.darkness = 0

    -- Radial attenuation shader for torch effect
    self.shader = love.graphics.newShader([[
        uniform vec2 lightPos;
        uniform float lightRadius;
        uniform float darkness;

        vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen_coords)
        {
            float dist = distance(screen_coords, lightPos);
            float alpha = clamp(dist / lightRadius, 0.0, 1.0);
            return vec4(0.0, 0.0, 0.0, alpha * darkness);
        }
    ]])
end

function Lighting:render(camX, camY, scale)
    local sw, sh = love.graphics.getDimensions()
    local targetX, targetY = self.knight:getLightPosition()

    love.graphics.setShader(self.shader)
    self.shader:send("lightPos", { (targetX * scale) - camX, (targetY * scale) - camY })
    self.shader:send("lightRadius", self.radius * scale)
    self.shader:send("darkness", self.darkness)

    love.graphics.setColor(1, 1, 1)
    -- Draw full-screen quad to trigger shader
    love.graphics.rectangle("fill", 0, 0, sw, sh)

    love.graphics.setShader()
    love.graphics.setColor(1, 1, 1)
end

return Lighting
