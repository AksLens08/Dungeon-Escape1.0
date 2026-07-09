-- skeleton_warrior.lua
local SkeletonWarrior = {}
SkeletonWarrior.__index = SkeletonWarrior

SkeletonWarrior.HITBOX_W = 18
SkeletonWarrior.HITBOX_H = 28

function SkeletonWarrior:new(x, y)
    local self = setmetatable({}, SkeletonWarrior)
    self.w, self.h = SkeletonWarrior.HITBOX_W, SkeletonWarrior.HITBOX_H
    self.x, self.y = x - self.w / 2, y - self.h / 2

    self.type = "enemy"
    self.subType = "skeleton"

    self.hp, self.maxHp = 250, 250
    self.speed = 50
    self.damage = 15
    self.state = "idle"
    self.previousState = "idle"
    self.direction = "left"
    self.timer, self.frame = 0, 0
    self.invuln = 0
    self.attackCooldown = 0
    self.deadAnimationComplete = false
    self.hasHit = false
    
    -- Juice: Knockback variables
    self.knockbackX = 0
    self.knockbackY = 0

    self.visionRange = 250
    self.attackRange = 35
    self.keepDistance = 0

    self.animations = {
        idle   = { frames = 7, speed = 0.12 },
        walk   = { frames = 7, speed = 0.10 },
        attack = { frames = 6, speed = 0.07 },
        death  = { frames = 4, speed = 0.15 }
    }
    
    self.targetHeight = 48
    self.displayScale = 1.0
    self:updateTexture()
    return self
end

function SkeletonWarrior:updateTexture()
    local texKey = "skeleton_warrior_" .. self.state
    local texture = gTextures[texKey]
    local anim = self.animations[self.state]

    if not texture or not anim then
        texture = gTextures["skeleton_warrior_idle"]
        anim = self.animations.idle
    end

    self.texture = texture
    if self.texture then
        local sw, sh = self.texture:getDimensions()
        self.frameWidth = sw / anim.frames
        self.frameHeight = sh
        self.displayScale = self.targetHeight / self.frameHeight
        self.frame = self.frame % anim.frames
        self.quad = love.graphics.newQuad(self.frame * self.frameWidth, 0, self.frameWidth, self.frameHeight, sw, sh)
    end
end

function SkeletonWarrior:update(dt, player, dungeon, projectiles)
    if self.invuln > 0 then self.invuln = self.invuln - dt end

    if self.hp <= 0 then
        if self.state ~= "death" then
            self.state = "death"
        end
    elseif self.attackCooldown > 0 then
        self.attackCooldown = self.attackCooldown - dt
    end

    if self.state ~= self.previousState then
        self.frame, self.timer = 0, 0
        self.previousState = self.state
        self:updateTexture()
    end

    if self.state ~= "death" and self.state ~= "attack" then
        local px, py = player:getCenter()
        local sx, sy = self:getCenter()
        local dx, dy = px - sx, py - sy
        local dist = math.sqrt(dx * dx + dy * dy)

        if dist < self.visionRange and dungeon:hasLineOfSight(sx, sy, px, py) then
            self.direction = dx > 0 and "right" or "left"
            if dist < self.attackRange and self.attackCooldown <= 0 then
                self.state = "attack"
                self.frame, self.timer = 0, 0
                self.hasHit = false
                if Audio then Audio:play("sword_slice") end
            elseif dist < self.keepDistance then
                self.state = "walk"
                local angle = math.atan2(dy, dx)
                self:move(dungeon, math.cos(angle + math.pi) * self.speed * dt, math.sin(angle + math.pi) * self.speed * dt)
            elseif dist > self.attackRange then
                self.state = "walk"
                local angle = math.atan2(dy, dx)
                self:move(dungeon, math.cos(angle) * self.speed * dt, math.sin(angle) * self.speed * dt)
            else
                self.state = "idle"
            end
        else
            self.state = "idle"
        end
    end

    self:handleAnimation(dt, projectiles, player, dungeon)

    -- Juice: Apply physics knockback
    if self.knockbackX ~= 0 or self.knockbackY ~= 0 then
        self:move(dungeon, self.knockbackX * dt, self.knockbackY * dt)
        self.knockbackX = self.knockbackX * 0.85 -- Apply friction
        self.knockbackY = self.knockbackY * 0.85
        if math.abs(self.knockbackX) < 5 then self.knockbackX = 0 end
        if math.abs(self.knockbackY) < 5 then self.knockbackY = 0 end
    end
end

function SkeletonWarrior:handleAnimation(dt, projectiles, player, dungeon)
    self.timer = self.timer + dt
    local anim = self.animations[self.state] or self.animations.idle
    if self.timer > anim.speed then
        self.timer = 0

        if self.state == "attack" and self.frame == 3 and not self.hasHit then
            local px, py = player:getCenter()
            local sx, sy = self:getCenter()
            local dx, dy = px - sx, py - sy
            local distSq = dx*dx + dy*dy
            if distSq < (self.attackRange + 10)^2 then
                player:takeDamage(self.damage, self, dungeon)
                self.hasHit = true
            end
        end

        if self.state == "death" then
            if self.frame < anim.frames - 1 then
                self.frame = self.frame + 1
            else
                self.deadAnimationComplete = true
            end
        else
            if self.frame < anim.frames - 1 then
                self.frame = self.frame + 1
            else
                if self.state == "attack" then 
                    self.state = "idle"
                    self.attackCooldown = 2.0
                end
                self.frame = 0
            end
        end
        self:updateTexture()
    end
end

function SkeletonWarrior:move(dungeon, dx, dy)
    if not dungeon then return end

    local steps = math.ceil(math.max(math.abs(dx), math.abs(dy)) / 2)
    if steps == 0 then return end
    local stepX, stepY = dx / steps, dy / steps

    for i = 1, steps do
        if not dungeon:isColliding(self.x + stepX, self.y, self.w, self.h) then
            self.x = self.x + stepX
        end
        if not dungeon:isColliding(self.x, self.y + stepY, self.w, self.h) then
            self.y = self.y + stepY
        end
    end
end

function SkeletonWarrior:takeDamage(amount, attacker, dungeon, kbMult)
    if self.invuln <= 0 and self.hp > 0 then
        self.hp = self.hp - amount
        self.invuln = 0.5
        if Audio then Audio:play("hurt") end

        if self.hp <= 0 then
            if attacker then
                if attacker.mana then
                    attacker.mana = math.min(attacker.maxMana, attacker.mana + 20)
                elseif attacker.armor then
                    attacker.armor = math.min(100, attacker.armor + 20)
                end
            end
        end

        -- Juice: Apply physics knockback
        if attacker and type(attacker) == "table" then
            local ax, ay = attacker.x, attacker.y
            if attacker.getCenter then ax, ay = attacker:getCenter() end
            
            local dx = self.x - ax
            local dy = self.y - ay
            local dist = math.sqrt(dx*dx + dy*dy)
            
            if dist > 0 then
                local strength = 300 * (kbMult or 0.5) -- Scale push strength
                self.knockbackX = (dx / dist) * strength
                self.knockbackY = (dy / dist) * strength
            end
        end
    end
end

function SkeletonWarrior:getCenter() return self.x + self.w / 2, self.y + self.h / 2 end

function SkeletonWarrior:render()
    if self.deadAnimationComplete or not self.texture then return end
    local scaleX = (self.direction == "right" and 1 or -1) * self.displayScale
    local pivotX, pivotY = self.x + self.w / 2, self.y + self.h
    love.graphics.setColor(1, 1, 1)
    if self.invuln > 0 then 
        love.graphics.setColor(1, 0.4, 0.4) 
    end
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

return SkeletonWarrior