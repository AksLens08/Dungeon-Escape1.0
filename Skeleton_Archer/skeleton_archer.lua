-- skeleton_archer.lua
-- Ranged enemy AI
local SkeletonArcher = {}
SkeletonArcher.__index = SkeletonArcher

SkeletonArcher.HITBOX_W = 26
SkeletonArcher.HITBOX_H = 38

function SkeletonArcher:new(x, y)
    local self = setmetatable({}, SkeletonArcher)
    self.w, self.h = SkeletonArcher.HITBOX_W, SkeletonArcher.HITBOX_H

    local spawnX = tonumber(x) or 0
    local spawnY = tonumber(y) or 0
    self.x, self.y = spawnX - self.w / 2, spawnY - self.h / 2

    self.hp, self.maxHp = 40, 40
    self.speed = 50
    self.state = "idle"
    self.previousState = "idle"
    self.direction = "left"
    self.timer, self.frame = 0, 0
    self.animationFrames = {}
    self.invuln = 0
    self.attackCooldown = 0
    
    self.visionRange = 250
    self.attackRange = 180
    self.keepDistance = 100

    -- Juice: Knockback variables
    self.knockbackX = 0
    self.knockbackY = 0

    self.animationSpeeds = {
        idle   = 0.12,
        walk   = 0.10,
        attack = 0.08,
        death  = 0.15
    }
    
    self.targetHeight, self.frameWidth, self.frameHeight = 62, 128, 128
    self.displayScale = 1.0
    self:updateTexture()
    return self
end

function SkeletonArcher:updateTexture()
    -- Update visuals
    local texKey = "skeleton_archer_" .. self.state
    self.texture = gTextures[texKey] or gTextures["skeleton_archer_idle"]
    if self.texture then
        local sw, sh = self.texture:getDimensions()
        local maxFrames = math.max(1, math.floor(sw / self.frameWidth))
        
        self.animationFrames[self.state] = maxFrames
        self.frame = self.frame % maxFrames
        self.displayScale = self.targetHeight / 128

        self.quad = love.graphics.newQuad(self.frame * self.frameWidth, 0, self.frameWidth, self.frameHeight, sw, sh)
    end
end

function SkeletonArcher:update(dt, player, dungeon, projectiles)
    -- Update logic
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

    -- AI logic
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
            elseif dist < self.keepDistance then
                self.state = "walk"
                local angle = math.atan2(dy, dx)
                self:move(dungeon, math.cos(angle + math.pi) * self.speed * dt, math.sin(angle + math.pi) * self.speed * dt)
            elseif dist > self.attackRange - 20 then
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

    self:handleAnimation(dt, projectiles, player)

    -- Juice: Apply physics knockback
    if self.knockbackX ~= 0 or self.knockbackY ~= 0 then
        self:move(dungeon, self.knockbackX * dt, self.knockbackY * dt)
        self.knockbackX = self.knockbackX * 0.85 -- Apply friction
        self.knockbackY = self.knockbackY * 0.85
        if math.abs(self.knockbackX) < 5 then self.knockbackX = 0 end
        if math.abs(self.knockbackY) < 5 then self.knockbackY = 0 end
    end
end

function SkeletonArcher:handleAnimation(dt, projectiles, player)
    -- Frame cycle
    self.timer = self.timer + dt
    local maxFrames = self.animationFrames[self.state] or 1
    local speed = self.animationSpeeds[self.state] or 0.1
    
    if self.timer > speed then
        self.timer = 0
        -- Fire shot
        if self.state == "attack" and self.frame == 12 then
            local px, py = player:getCenter()
            local sx, sy = self:getCenter()
            local angle = math.atan2(py - sy, px - sx)
            table.insert(projectiles, {
                x = sx, y = sy, 
                vx = math.cos(angle) * 200, vy = math.sin(angle) * 200,
                angle = angle, type = "arrow", owner = self, frame = 1, life = 4
            })
        end

        if self.state == "death" then
            if self.frame < maxFrames - 1 then
                self.frame = self.frame + 1
            else
                self.deadAnimationComplete = true
            end
        else
            if self.frame < maxFrames - 1 then
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

function SkeletonArcher:move(dungeon, dx, dy)
    -- Movement
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

function SkeletonArcher:takeDamage(amount, attacker, dungeon, kbMult)
    -- Damage and KB
    if self.hp > 0 then
        self.hp = self.hp - amount
        self.invuln = 0.5
        
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

function SkeletonArcher:getCenter() return self.x + self.w / 2, self.y + self.h / 2 end

function SkeletonArcher:render()
    if self.deadAnimationComplete or not self.texture then return end
    local scaleX = (self.direction == "right" and 1 or -1) * self.displayScale
    local pivotX, pivotY = self.x + self.w / 2, self.y + self.h
    
    love.graphics.setColor(1, 1, 1)
    if self.invuln > 0 then 
        love.graphics.setColor(1, 0.4, 0.4) 
        self.invuln = self.invuln - love.timer.getDelta()
    end

    love.graphics.draw(self.texture, self.quad, pivotX, pivotY, 0, scaleX, self.displayScale, self.frameWidth / 2, self.frameHeight)
    love.graphics.setColor(1, 1, 1)
end

return SkeletonArcher