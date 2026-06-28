-- system/effect.lua
-- Game feel effects: hitstop, screen shake, particles
local Effect = {}

local hitstopTimer = 0
local shakeTimer = 0
local shakeMagnitude = 0
local particles = {}

function Effect:triggerHitstop(duration)
    hitstopTimer = duration or 0.05 
end

function Effect:triggerShake(duration, magnitude)
    shakeTimer = duration or 0.2
    shakeMagnitude = magnitude or 2 
end

function Effect:spawnParticles(x, y, color, count)
    for i = 1, (count or 8) do
        table.insert(particles, {
            x = x, y = y,
            vx = love.math.random(-80, 80), 
            vy = love.math.random(-80, 80), 
            life = 0.5,                       
            color = color or {1, 0, 0, 1}     
        })
    end
end

function Effect:update(dt)
    if hitstopTimer > 0 then hitstopTimer = hitstopTimer - dt end
    if shakeTimer > 0 then
        shakeTimer = shakeTimer - dt
        if shakeTimer <= 0 then shakeMagnitude = 0 end
    end
    for i = #particles, 1, -1 do
        local p = particles[i]
        p.x = p.x + (p.vx * dt)
        p.y = p.y + (p.vy * dt)
        p.life = p.life - dt
        if p.life <= 0 then table.remove(particles, i) end
    end
end

function Effect:getShakeOffset()
    if shakeTimer > 0 then
        return love.math.random(-shakeMagnitude, shakeMagnitude), 
               love.math.random(-shakeMagnitude, shakeMagnitude)
    end
    return 0, 0
end

function Effect:drawParticles()
    for _, p in ipairs(particles) do
        local alpha = math.max(0, p.life * 2) 
        love.graphics.setColor(p.color[1], p.color[2], p.color[3], alpha)
        love.graphics.rectangle("fill", p.x, p.y, 3, 3) 
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function Effect:isHitstopActive()
    return hitstopTimer > 0
end

return Effect