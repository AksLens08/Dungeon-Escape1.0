-- red_slime.lua
-- Aggressive buff slime
local Push = require("push")

local RedSlime = {}
RedSlime.__index = RedSlime

RedSlime.HITBOX_W = 28
RedSlime.HITBOX_H = 22

function RedSlime.new(x, y)
    local self = setmetatable({}, RedSlime)
    self:init(x, y)
    return self
end

function RedSlime:init(x, y)
    -- Stats and type
    self.w, self.h = RedSlime.HITBOX_W, RedSlime.HITBOX_H
    self.x, self.y = x - self.w / 2, y - self.h / 2
    
    self.type = "enemy"
    self.subType = "slime"
    self.minimapColor = {1, 0.2, 0.2}

    self.hp, self.maxHp, self.damage = 80, 80, 10
    self.dx, self.dy = 0, 0
    self.speed = 65
    self.visionRange = 150
    
    self.state = "idle"
    self.previousState = "idle"
    self.direction = "right"
    self.hasHit = false
    self.timer, self.frame = 0, 0
    self.invuln = 0
    
    self.behaviorTimer = math.random(1, 2)
    self.deadAnimationComplete = false

    self.targetHeight = 40
    self.displayScale = 1.0
    self.frameWidth, self.frameHeight = 0, 0

    self.animations = {
        idle  = { frames = 8, speed = 0.15 },
        walk  = { frames = 8, speed = 0.1 },
        attack = { frames = 4, speed = 0.2 },
        hurt  = { frames = 6, speed = 0.1 },
        death = { frames = 3, speed = 0.15 }
    }
    
    self:updateTexture()
end

function RedSlime:updateTexture()
    -- Select sprite
    local texKey = "red_slime_" .. self.state
    self.texture = gTextures[texKey] or gTextures["red_slime_idle"]
    if self.texture then
        local sw, sh = self.texture:getDimensions()
        local anim = self.animations[self.state] or self.animations.idle
        
        self.frameWidth = sw / anim.frames
        self.frameHeight = sh
        self.displayScale = self.targetHeight / self.frameHeight
        
        self.frame = self.frame % anim.frames
        self.quad = love.graphics.newQuad(self.frame * self.frameWidth, 0, self.frameWidth, self.frameHeight, sw, sh)
    end
end

function RedSlime:update(dt, player, dungeon)
    -- Logic update
    if self.invuln > 0 then self.invuln = self.invuln - dt end

    if self.hp <= 0 then
        if self.state ~= "death" then
            self.state, self.frame, self.timer = "death", 0, 0
            self:updateTexture()
        end
    elseif self.state ~= "hurt" and self.state ~= "attack" then
        self:updateAI(dt, player, dungeon)
    end

    if self.state ~= self.previousState then
        self.frame, self.timer = 0, 0
        self.previousState = self.state
        self:updateTexture()
    end

    self:handleAnimation(dt)

    -- Check for damage during the active lunge frames (1 and 2)
    if self.state == "attack" and (self.frame >= 1 and self.frame <= 2) and not self.hasHit then
        local px, py = player:getCenter()
        local sx, sy = self:getCenter()
        local distSq = (px - sx)^2 + (py - sy)^2
        if distSq < 625 then -- 25 pixel reach (matches the AI trigger distance)
            player:takeDamage(self.damage, self, dungeon)
            self.hasHit = true
        end
    end

    if self.state == "walk" then
        self:move(dungeon, self.dx * dt, self.dy * dt)
    end
end

function RedSlime:updateAI(dt, player, dungeon)
    -- State-based AI
    local px, py = player:getCenter()
    local sx, sy = self:getCenter()
    local dx, dy = px - sx, py - sy
    local dist = math.sqrt(dx * dx + dy * dy)

    self.behaviorTimer = self.behaviorTimer - dt

    if self.behaviorTimer <= 0 and dist < 25 and dungeon:hasLineOfSight(sx, sy, px, py) then
        self.state = "attack"
        self.dx, self.dy = 0, 0
        self.frame, self.timer = 0, 0
        self.hasHit = false
        self.direction = (px > sx) and "right" or "left"
        self:updateTexture()
        return
    end

    if self.state == "idle" then
        self.dx, self.dy = 0, 0
        if self.behaviorTimer <= 0 then
            if dist < self.visionRange and dungeon:hasLineOfSight(sx, sy, px, py) then
                self.state = "walk"
                self.behaviorTimer = 0.8
                local angle = math.atan2(dy, dx)
                self.dx = math.cos(angle) * self.speed
                self.dy = math.sin(angle) * self.speed
                self.direction = self.dx > 0 and "right" or "left"
            else
                self.behaviorTimer = math.random(1, 3)
            end
        end
    elseif self.state == "walk" then
        if self.behaviorTimer <= 0 then
            self.state = "idle"
            self.behaviorTimer = math.random(1, 2)
        end
    end
end

function RedSlime:move(map, amountX, amountY)
    if not map then return end

    -- Stepped movement prevents tunneling and allows sliding along walls
    local steps = math.ceil(math.max(math.abs(amountX), math.abs(amountY)) / 2)
    if steps == 0 then return end
    local stepX, stepY = amountX / steps, amountY / steps

    for i = 1, steps do
        if not map:isColliding(self.x + stepX, self.y, self.w, self.h) then
            self.x = self.x + stepX
        end
        if not map:isColliding(self.x, self.y + stepY, self.w, self.h) then
            self.y = self.y + stepY
        end
    end
end

function RedSlime:handleAnimation(dt)
    -- Frame timing
    self.timer = self.timer + dt
    local anim = self.animations[self.state] or self.animations.idle
    if self.timer > anim.speed then
        self.timer = 0
        local maxFrames = anim.frames
        if self.state == "death" then
            if self.frame < maxFrames - 1 then self.frame = self.frame + 1 else self.deadAnimationComplete = true end
        elseif self.state == "hurt" or self.state == "attack" then
            if self.frame < maxFrames - 1 then self.frame = self.frame + 1 
            else self.state, self.frame = "idle", 0; self.behaviorTimer = math.random(1, 2) end
        else
            self.frame = (self.frame + 1) % maxFrames
        end
        self:updateTexture()
    end
end

function RedSlime:takeDamage(amount, attacker, dungeon, kbMult)
    -- Damage and buffs
    if self.invuln <= 0 and self.hp > 0 then
        self.hp = self.hp - amount
        self.invuln = 0.4
        Audio:play("slime_hurt")

        -- Grant player buff
        if self.hp <= 0 then
            if attacker and attacker.applyAttackBuff then
                attacker:applyAttackBuff(10)
            end
        else
            self.state, self.frame, self.timer = "hurt", 0, 0; self:updateTexture()
        end

        if attacker and type(attacker) == "table" then
            local pushDx, pushDy = Push.execute(attacker, self, 15, kbMult or 0.5, false)
            if pushDx and pushDy then
                self:move(dungeon, pushDx, pushDy)
            end
        end
    end
end

function RedSlime:getCenter() return self.x + self.w / 2, self.y + self.h / 2 end
function RedSlime:render()
    if self.deadAnimationComplete or not self.texture then return end
    local scaleX = (self.direction == "right" and 1 or -1) * self.displayScale
    local pivotX, pivotY = self.x + self.w / 2, self.y + self.h
    love.graphics.setColor(1, 1, 1)
    if self.invuln > 0 then love.graphics.setColor(1, 0.5, 0.5) end
    love.graphics.draw(self.texture, self.quad, pivotX, pivotY, 0, scaleX, self.displayScale, self.frameWidth / 2, self.frameHeight)
    love.graphics.setColor(1, 1, 1)
    if self.hp < self.maxHp and self.hp > 0 then
        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.rectangle("fill", self.x, self.y - 10, self.w, 3)
        love.graphics.setColor(0, 1, 0)
        love.graphics.rectangle("fill", self.x, self.y - 10, self.w * (self.hp / self.maxHp), 3)
        love.graphics.setColor(1, 1, 1)
    end
end
return RedSlime