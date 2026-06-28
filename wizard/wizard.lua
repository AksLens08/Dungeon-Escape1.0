-- wizard.lua
-- Wizard player
local Push = require("system.push")
local Movement = require("system.movement")
local SpriteAnim = require("system.sprite_anim")

local Wizard = {}
Wizard.__index = Wizard

Wizard.HITBOX_W = 20
Wizard.HITBOX_H = 30

function Wizard:init(x, y)
    -- Setup stats
    self.w, self.h = Wizard.HITBOX_W, Wizard.HITBOX_H
    self.x, self.y = x - self.w / 2, y - self.h / 2
    
    self.type = "player"
    self.subType = "wizard"
    self.minimapColor = {0.7, 0.3, 1} 

    self.hp, self.maxHp, self.mana, self.maxMana, self.damage, self.coins = 100, 100, 100, 100, 20, 0
    self.baseDamage = 20 
    self.buffTimer = 0
    self.hpRegenTimer, self.hpRegenInterval = 0, 2.5
    self.dx, self.dy, self.speed = 0, 0, 70 
    self.stamina, self.maxStamina = 100, 100 
    self.isSprinting = false
    self.slideSide = nil
    
    self.state, self.previousState, self.direction = "idle", "idle", "right"
    self.timer, self.frame = 0, 0
    self.animationFrames = {} 
    self.attackTimer, self.attackCooldown = 0, 0
    self.invuln = 0
    
    -- Juice: Knockback variables
    self.knockbackX = 0
    self.knockbackY = 0

    self.targetHeight = 58
    self.displayScale = 1.0
    self.frameWidth, self.frameHeight = 128, 128
    self.lightCenters = {
        idle   = { x = 64, y = 64 },
        walk   = { x = 64, y = 64 },
        run    = { x = 64, y = 64 },
        attack = { x = 64, y = 64 },
        flame  = { x = 64, y = 64 },
        death  = { x = 64, y = 64 }
    }

    self.animationSpeeds = {
        idle   = 0.12, 
        walk   = 0.11,
        run    = 0.09,
        attack = 0.0875,
        flame  = 0.06,
        death  = 0.12,
        hurt   = 0.1
    }
    
    self:updateTexture()
end

function Wizard.new(x, y)
    local self = setmetatable({}, Wizard)
    self:init(x, y)
    return self
end

function Wizard:moveWithCollision(map, amountX, amountY)
    Movement.moveWithCollision(self, map, amountX, amountY)
end

function Wizard:updateTexture()
    -- Select sprite
    local texKey = "wizard_" .. self.state
    self.texture = gTextures[texKey] or gTextures["wizard_idle"]
    if self.texture then
        local sw, sh = self.texture:getDimensions()
        local maxFrames = math.max(1, math.floor(sw / self.frameWidth))
        
        self.animationFrames[self.state] = maxFrames
        self.frame = self.frame % maxFrames
        self.displayScale = self.targetHeight / 128 

        SpriteAnim.updateQuad(self)
    end
end

function Wizard:update(dt, dungeon, gMouse, projectiles, camera, enemies)
    -- Wizard logic
    if self.invuln > 0 then self.invuln = self.invuln - dt end
    if self.attackCooldown > 0 then self.attackCooldown = self.attackCooldown - dt end
    if self.attackTimer > 0 then self.attackTimer = self.attackTimer - dt end

    if self.hp <= 0 then
        self.state = "death"
        self.dx, self.dy = 0, 0
    else
        if self.hp < self.maxHp then
            self.hpRegenTimer = self.hpRegenTimer + dt
            if self.hpRegenTimer >= self.hpRegenInterval then
                self:heal(5)
                self.hpRegenTimer = 0
            end
        end

        if self.buffTimer > 0 then
            self.buffTimer = self.buffTimer - dt
            if self.buffTimer <= 0 then
                self.damage = self.baseDamage
            end
        end

        self.mana = math.min(self.maxMana, self.mana + 1 * dt)

        local isShiftDown = love.keyboard.isDown("lshift", "rshift") 

        local inputX, inputY = 0, 0
        -- Freeze movement during flame cast
        if self.state ~= "flame" then
            if love.keyboard.isDown("w", "up") then inputY = -1 end
            if love.keyboard.isDown("s", "down") then inputY = 1 end
            if love.keyboard.isDown("a", "left") then inputX, self.direction = -1, "left" end
            if love.keyboard.isDown("d", "right") then inputX, self.direction = 1, "right" end
        end

        local isMoving = (inputX ~= 0 or inputY ~= 0) 

        if isMoving and isShiftDown then
            if not self.isSprinting and self.stamina >= 20 then
                self.isSprinting = true
            end
        else
            self.isSprinting = false
        end
        if self.stamina <= 0 then self.isSprinting = false end

        local canRun = self.isSprinting
        local currentSpeed = self.speed 

        if canRun then
            currentSpeed = self.speed * 1.3 
            self.stamina = math.max(0, self.stamina - 25 * dt) 
        else
            self.stamina = math.min(self.maxStamina, self.stamina + 15 * dt) 
        end

        -- Physics movement calculation
        local mag = (inputX ~= 0 and inputY ~= 0) and 0.7071 or 1
        local targetDx = inputX * currentSpeed * mag
        local targetDy = inputY * currentSpeed * mag

        local isStopping = (inputX == 0 and inputY == 0)
        local isTurning = (inputX > 0 and self.dx < 0) or (inputX < 0 and self.dx > 0)
        local weight = isTurning and 45 or (isStopping and 12 or 20)
        
        local lerpFactor = 1 - math.exp(-weight * dt)
        self.dx = self.dx + (targetDx - self.dx) * lerpFactor
        self.dy = self.dy + (targetDy - self.dy) * lerpFactor
        if isStopping and math.abs(self.dx) < 1 then self.dx = 0 end
        if isStopping and math.abs(self.dy) < 1 then self.dy = 0 end

        if (math.abs(self.dx) > 5 or math.abs(self.dy) > 5) and self.hp > 0 then
            if not Audio:isPlaying("footsteps") then Audio:play("footsteps") end
        else
            Audio:stop("footsteps")
        end

        -- State machine
        if gMouse.rightDown and self.attackCooldown <= 0 and self.mana >= 20
            and self.attackTimer <= 0 and self.state ~= "flame" and projectiles then
            self.state = "flame"
            self.flameHitDone = false
            self.mana = self.mana - 20 
            Audio:play("fireball")
            self.dx, self.dy = 0, 0
            self.attackTimer = 0.84 
            self.attackCooldown = 1.0
        elseif gMouse.leftDown and self.attackCooldown <= 0 and self.attackTimer <= 0 then
            self.state = "attack"
            self.attackTimer = 0.35
            Audio:play("sword_slice")
            self.attackCooldown = 1.0
        elseif self.invuln > 0.6 then
            self.state = "hurt"
            self.attackTimer = 0 
        elseif self.attackTimer > 0 and (self.state == "flame" or self.state == "attack") then
            -- Hold attack animation
        elseif canRun then self.state = "run" 
        elseif math.abs(self.dx) > 2 or math.abs(self.dy) > 2 then
            self.state = "walk"
        else
            self.state = "idle"
        end
    end

    if self.state ~= self.previousState then
        self.frame, self.timer = 0, 0
        self.previousState = self.state
        self:updateTexture()
    end

    -- Flame jet collision check
    if self.state == "flame" and self.frame == 8 and not self.flameHitDone and enemies then
        self.flameHitDone = true
        local px, py = self:getCenter()
        for _, enemy in ipairs(enemies) do
            if enemy.hp > 0 then
                local ex, ey = enemy.x + enemy.w / 2, enemy.y + enemy.h / 2
                if enemy.getCenter then ex, ey = enemy:getCenter() end
                local dx, dy = ex - px, ey - py
                local distSq = dx * dx + dy * dy
                local isFacing = (self.direction == "right" and dx > 0) or (self.direction == "left" and dx < 0)

                if isFacing and distSq < 3600 then
                    enemy:takeDamage(40, self, dungeon)
                end
            end
        end
    end

    if self.attackTimer > 0 then
        self.attackTimer = self.attackTimer - dt
    end

    if self.state == "flame" or self.state == "attack" then
        self.dx, self.dy = 0, 0
    end

    self:handleAnimation(dt)
    
    -- Normal movement
    self:moveWithCollision(dungeon, self.dx * dt, self.dy * dt)

    -- Juice: Apply physics knockback
    if self.knockbackX ~= 0 or self.knockbackY ~= 0 then
        self:moveWithCollision(dungeon, self.knockbackX * dt, self.knockbackY * dt)
        self.knockbackX = self.knockbackX * 0.85 -- Apply friction
        self.knockbackY = self.knockbackY * 0.85
        if math.abs(self.knockbackX) < 5 then self.knockbackX = 0 end
        if math.abs(self.knockbackY) < 5 then self.knockbackY = 0 end
    end
end

function Wizard:handleAnimation(dt)
    -- Animation loop
    self.timer = self.timer + dt
    local maxFrames = self.animationFrames[self.state] or 1
    local frameDuration = self.animationSpeeds[self.state] or 0.1
    
    if self.timer > frameDuration then
        self.timer = 0

        if self.state == "death" then
            if self.frame < maxFrames - 1 then self.frame = self.frame + 1 else self.deadAnimationComplete = true end
        elseif self.state == "flame" or self.state == "attack" or self.state == "hurt" then
            if self.frame < maxFrames - 1 then self.frame = self.frame + 1 end
        else
            self.frame = (self.frame + 1) % maxFrames
        end
        self:updateTexture()
    end
end

function Wizard:takeDamage(amount, attacker, dungeon)
    -- Damage and KB
    if self.invuln <= 0 and self.hp > 0 then
        self.hp = self.hp - amount
        self.invuln = 0.8
        Audio:play("hurt")

        -- Juice: Trigger hit effects
        triggerHitstop(0.1)
        triggerShake(0.3, 4)
        spawnParticles(self.x + self.w/2, self.y + self.h/2, {1, 0, 0, 1}, 10)

        -- Juice: Apply physics knockback
        if attacker and type(attacker) == "table" then
            local ax, ay = attacker.x, attacker.y
            if attacker.getCenter then ax, ay = attacker:getCenter() end
            
            local dx = self.x - ax
            local dy = self.y - ay
            local dist = math.sqrt(dx*dx + dy*dy)
            
            if dist > 0 then
                self.knockbackX = (dx / dist) * 350 -- Push strength
                self.knockbackY = (dy / dist) * 350
            end
        end
    end
end

function Wizard:heal(amount)
    self.hp = math.min(self.maxHp, self.hp + amount)
end

function Wizard:applyAttackBuff(duration)
    self.buffTimer = duration
    self.damage = self.baseDamage * 2 
end

function Wizard:getCenter()
    return self.x + self.w / 2, self.y + self.h / 2 
end

function Wizard:getLightPosition()
    -- Light offset
    local pivotX = self.x + self.w / 2
    local pivotY = self.y + self.h
    local center = self.lightCenters[self.state] or self.lightCenters.idle
    local offsetY = (center.y - self.frameHeight) * self.displayScale

    return pivotX, pivotY + offsetY
end

function Wizard:drawHUD()
    -- Draw UI
    local barW, barH = 260, 28
    local margin = 20
    love.graphics.setFont(gFonts["hud"])
    
    local function drawMedievalBar(x, y, current, max, label, color, subLabel)
        love.graphics.setColor(0.05, 0.05, 0.05, 1)
        love.graphics.rectangle("fill", x - 4, y - 4, barW + 8, barH + 8)
        love.graphics.setColor(0.3, 0.3, 0.35, 1)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", x - 4, y - 4, barW + 8, barH + 8)

        -- Corner Rivets
        love.graphics.setColor(0.5, 0.5, 0.5, 1)
        love.graphics.circle("fill", x - 4, y - 4, 3)
        love.graphics.circle("fill", x + barW + 4, y - 4, 3)
        love.graphics.circle("fill", x - 4, y + barH + 4, 3)
        love.graphics.circle("fill", x + barW + 4, y + barH + 4, 3)

        -- Stone Background
        love.graphics.setColor(0.15, 0.15, 0.15, 1)
        love.graphics.rectangle("fill", x, y, barW, barH)

        -- The Fill
        local percent = math.max(0, current / max)
        love.graphics.setColor(color[1], color[2], color[3], 1)
        love.graphics.rectangle("fill", x, y, barW * percent, barH)

        -- Medieval Bevel
        love.graphics.setColor(0, 0, 0, 0.3)
        love.graphics.rectangle("fill", x, y + barH * 0.7, barW * percent, barH * 0.3)
        love.graphics.setColor(1, 1, 1, 0.15)
        love.graphics.rectangle("fill", x, y, barW * percent, 4)

        -- Text
        love.graphics.setColor(0.8, 0.7, 0.5, 1)
        love.graphics.print(label, x, y - 22)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(math.max(0, math.ceil(current)) .. " " .. subLabel, x, y + 4, barW, "center")
    end

    -- Draw Health
    local hpX, hpY = margin + 5, margin + 25
    drawMedievalBar(hpX, hpY, self.hp, self.maxHp, "HEALTH", {0.6, 0.1, 0.1}, "/ " .. self.maxHp)

    -- Draw Mana
    local manaX, manaY = margin + 5, hpY + barH + 35
    drawMedievalBar(manaX, manaY, self.mana, self.maxMana, "MANA BAR", {0.3, 0.1, 0.6}, "/ " .. self.maxMana)

    -- Draw Stamina
    local staX, staY = margin + 5, manaY + barH + 35
    drawMedievalBar(staX, staY, self.stamina, self.maxStamina, "STAMINA", {0.2, 0.6, 0.2}, "/ " .. self.maxStamina)

    -- Coin Counter
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", margin, staY + barH + 15, 140, 30, 4)
    love.graphics.setColor(0.9, 0.8, 0.5, 1)
    love.graphics.print("COINS: " .. (self.coins or 0) .. " / 20", margin + 10, staY + barH + 20)
    
    love.graphics.setLineWidth(1)
end

function Wizard:handleInput(key) end

function Wizard:render()
    -- Draw Wizard
    if self.texture and self.quad then
        local scaleX = (self.direction == "right" and 1 or -1) * self.displayScale
        local pivotX = self.x + self.w / 2
        local pivotY = self.y + self.h
        
        love.graphics.setColor(1, 1, 1)

        if self.invuln > 0 then
            love.graphics.setColor(1, 0.5, 0.5) 
        end

        love.graphics.draw(self.texture, self.quad, pivotX, pivotY, 0, scaleX, self.displayScale, self.frameWidth / 2, self.frameHeight)
    end
    love.graphics.setColor(1, 1, 1)
end

return Wizard