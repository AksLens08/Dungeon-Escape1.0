-- lighting.lua
local Class = require("class")
local Lighting = Class.define()

function Lighting:init(knight)
    self.knight = knight
    self.radius = 60
    self.darkness = 1.0

    -- Radial attenuation shader for torch effect
    self.shader = love.graphics.newShader([[
        #define MAX_LIGHTS 32
        extern vec2 lightPositions[MAX_LIGHTS];
        extern float lightRadii[MAX_LIGHTS];
        extern int numLights;
        extern float darkness;

        vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen_coords)
        {
            float minAlpha = 1.0;
            
            for (int i = 0; i < numLights; i++) {
                float dist = distance(screen_coords, lightPositions[i]);
                float alpha = clamp(dist / lightRadii[i], 0.0, 1.0);
                minAlpha = min(minAlpha, alpha);
            }

            return vec4(0.0, 0.0, 0.0, minAlpha * darkness);
        }
    ]])
end

function Lighting:render(camX, camY, scale, extraLights)
    local sw, sh = love.graphics.getDimensions()
    local targetX, targetY = self.knight:getLightPosition()
    
    -- Start with the knight's light position and radius
    local flatPositions = { (targetX * scale) - camX, (targetY * scale) - camY }
    local radii = { self.radius * scale }

    if extraLights then
        for i = 1, math.min(#extraLights, 31) do
            local fire = extraLights[i]
            table.insert(flatPositions, (fire.x * scale) - camX)
            table.insert(flatPositions, (fire.y * scale) - camY)
            table.insert(radii, fire.lightRadius * scale)
        end
    end

    love.graphics.setShader(self.shader)
    self.shader:send("numLights", #radii) -- numLights should be the count of actual lights
    self.shader:send("lightPositions", flatPositions)
    self.shader:send("lightRadii", radii)
    self.shader:send("darkness", self.darkness)

    love.graphics.setColor(1, 1, 1)
    -- Draw full-screen quad to trigger shader
    love.graphics.rectangle("fill", 0, 0, sw, sh)

    love.graphics.setShader()
    love.graphics.setColor(1, 1, 1)
end

return Lighting
