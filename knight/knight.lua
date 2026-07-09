-- knight.lua
-- Melee player
local Class = require("system.class")
local Movement = require("system.movement")
local SpriteAnim = require("system.sprite_anim")
local Knight = Class.define()
Knight.HITBOX_W = 24
Knight.HITBOX_H = 36

function Knight:init(x, y)
    -- Setup stats
    self.w, self.h = Knight.HITBOX_W, Knight.HITBOX_H
    self.x = (x or 0) - self.w / 2
    self.y = (y or 0) - self.h / 2

    self.hp, self.maxHp, self.armor, self.damage, self.coins = 100, 100, 100, 20, 0
    self.baseDamage, self.buffTimer = 20, 0
    self.invuln = 0
    self.hpRegenTimer = 0
    self.hpRegenInterval = 2.5
    self.dx, self.dy, self.speed = 0, 0, 70
    self.stamina, self.maxStamina = 100, 100
    self.isSprinting = false
    self.slideSide = nil
    self.state, self.previousState, self.direction = "idle", "idle", "right"
    self.attackVariant = nil
    self.timer, self.frame = 0, 0
    self.attackTimer, self.attackCooldown = 0, 0
    self.deadAnimationComplete = false

    -- Juice: Knockback variables
    self.knockbackX = 0
    self.knockbackY = 0

    self.targetHeight = 52
    self.growthTimer = 0
    self.frameWidth, self.frameHeight = 128, 128
    self.animationFrames = {}
    self.animationSpeeds = {
        idle = 0.12, walk = 0.08, run = 0.09, attack = 0.07, run_attack = 0.06,
        hurt = 0.1, death = 0.15, defend = 0.1
    }
    self.lightCenters = {
        idle = { x = 33, y = 95.5 },
        walk = { x = 32.5, y = 95.5 },
        run = { x = 32.5, y = 95.5 },
        attack = { x = 54, y = 95.5 },
        run_attack = { x = 54, y = 95.5 },
        hurt = { x = 37.5, y = 98 },
        death = { x = 35, y = 98.5 },
        defend = { x = 33, y = 95.5 }
    }

    self.displayScale, self.visualOffsetX = 1.0, 0
end

function Knight:updateTexture()
    -- Select sprite
    local texKey = "knight_" .. self.state
    self.texture = gTextures[texKey] or gTextures["knight_idle"]

    if self.texture then
        local sw, sh = self.texture:getDimensions()
        local maxFrames = math.max(1, math.floor(sw / self.frameWidth))
        if not self.animationFrames then self.animationFrames = {} end
        self.animationFrames[self.state] = maxFrames
        self.frame = self.frame % maxFrames
        self.displayScale = self.targetHeight / self.frameHeight
        SpriteAnim.updateQuad(self)
    end
end

function Knight:moveWithCollision(map, amountX, amountY)
    Movement.moveWithCollision(self, map, amountX, amountY)
end

function Knight:update(dt, map, gMouse)
    -- Knight logic
    if self.invuln > 0 then self.invuln = self.invuln - dt end
    if self.attackCooldown > 0 then self.attackCooldown = self.attackCooldown - dt end

    if self.hp <= 0 then
        self.state = "death"
        self.dx, self.dy = 0, 0
    else
        if self.buffTimer > 0 then
            self.buffTimer = self.buffTimer - dt
            if self.buffTimer <= 0 then
                self.damage = self.baseDamage
            end
        end

        if self.hp < self.maxHp then
            self.hpRegenTimer = self.hpRegenTimer + dt
            if self.hpRegenTimer >= self.hpRegenInterval then
                self:heal(10)
                self.hpRegenTimer = 0
            end
        end

        -- Input
        local moveX, moveY = 0, 0
        local isShiftDown = love.keyboard.isDown("lshift", "rshift")
        if not (gMouse and gMouse.rightDown) then
            if love.keyboard.isDown("w", "up") then moveY = moveY - 1 end
            if love.keyboard.isDown("s", "down") then moveY = moveY + 1 end
            if love.keyboard.isDown("a", "left") then moveX = moveX - 1 end
            if love.keyboard.isDown("d", "right") then moveX = moveX + 1 end
        end

        if moveX ~= 0 then
            self.direction = (moveX > 0) and "right" or "left"
        end

        local isMoving = (moveX ~= 0 or moveY ~= 0)

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

        local mag = (moveX ~= 0 and moveY ~= 0) and 0.7071 or 1
        local targetDx = moveX * currentSpeed * mag
        local targetDy = moveY * currentSpeed * mag

        local isStopping = (moveX == 0 and moveY == 0)
        local isTurning = (moveX > 0 and self.dx < 0) or (moveX < 0 and self.dx > 0)
        local weight = isTurning and 45 or (isStopping and 12 or 20)
        
        local lerpFactor = 1 - math.exp(-weight * dt)
        self.dx = self.dx + (targetDx - self.dx) * lerpFactor
        self.dy = self.dy + (targetDy - self.dy) * lerpFactor
        if isStopping and math.abs(self.dx) < 1 then self.dx = 0 end
        if isStopping and math.abs(self.dy) < 1 then self.dy = 0 end

        -- States
        if self.invuln > 0.7 then
            self.state = "hurt"
            self.attackTimer = 0
        elseif (gMouse and gMouse.rightDown) then
            self.state = "defend"
            self.attackTimer = 0
        elseif self.attackTimer > 0 then
            -- Maintain attack state
        elseif (gMouse and gMouse.leftDown) and self.attackCooldown <= 0 then
            local canRunAttack = isShiftDown and self.stamina >= 15
            self.state = canRunAttack and "run_attack" or "attack"
            if canRunAttack then
                self.stamina = math.max(0, self.stamina - 15)
            end
            self.attackTimer = 0.35
            Audio:play("sword_slice")
            self.attackCooldown = 1
        elseif canRun then self.state = "run"
        elseif isMoving then self.state = "walk"
        else self.state = "idle" end
    end
    
    if self.attackTimer > 0 then 
        self.attackTimer = self.attackTimer - dt 
    end

    if self.state ~= self.previousState then
        self.frame, self.timer = 0, 0
        self.previousState = self.state
        self:updateTexture()
    end

    -- Animation
    self.timer = self.timer + dt
    local frameDuration = self.animationSpeeds[self.state] or 0.1
    local maxFrames = self.animationFrames[self.state] or 1
    if self.timer > frameDuration then
        self.timer = 0

        if self.state == "death" then
            if self.frame < maxFrames - 1 then
                self.frame = self.frame + 1
            else
                self.deadAnimationComplete = true
            end
        else
            self.frame = (self.frame + 1) % maxFrames
        end

        self:updateTexture()
    end

    if (self.state == "walk" or self.state == "run") and self.hp > 0 then
        if not Audio:isPlaying("footsteps") then
            Audio:play("footsteps")
        end
    else
        Audio:stop("footsteps")
    end

    -- Juice: Apply physics knockback
    if self.knockbackX ~= 0 or self.knockbackY ~= 0 then
        self:moveWithCollision(map, self.knockbackX * dt, self.knockbackY * dt)
        self.knockbackX = self.knockbackX * 0.85 -- Apply friction
        self.knockbackY = self.knockbackY * 0.85
        if math.abs(self.knockbackX) < 5 then self.knockbackX = 0 end
        if math.abs(self.knockbackY) < 5 then self.knockbackY = 0 end
    end

    self:moveWithCollision(map, self.dx * dt, self.dy * dt)
end

function Knight:takeDamage(amount, attacker, dungeon)
    -- Shielding
    if self.state == "defend" or love.mouse.isDown(2) then
        Audio:play("shield_hit")
        return
    end

    if self.invuln <= 0 and self.hp > 0 then
        local hpBefore = self.hp
        if self.armor > 0 then
            self.armor = self.armor - amount
            if self.armor < 0 then
                self.hp = self.hp + self.armor
                self.armor = 0
            end
        else
            self.hp = self.hp - amount
        end

        if self.hp < hpBefore then
            Audio:play("hurt")
        else
            Audio:play("knight_hurt")
        end

        self.invuln = 0.8

        -- Juice: Trigger hit effects
        Effect:triggerHitstop(0.1)
        Effect:triggerShake(0.3, 4)
        Effect:spawnParticles(self.x + self.w/2, self.y + self.h/2, {1, 0, 0, 1}, 10)

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

function Knight:heal(amount)
    self.hp = math.min(self.maxHp, self.hp + amount)
end

function Knight:applyAttackBuff(duration)
    self.buffTimer = duration
    self.damage = self.baseDamage * 2
end

function Knight:getCenter()
    return self.x + self.w / 2, self.y + self.h / 2
end

function Knight:getLightPosition()
    -- Light offset
    local pivotX = self.x + self.w / 2
    local pivotY = self.y + self.h
    local center = self.lightCenters[self.state] or self.lightCenters.idle
    local offsetY = (center.y - self.frameHeight) * self.displayScale

    return pivotX, pivotY + offsetY
end

function Knight:drawHUD()
    -- Draw UI
    local barW, barH = 260, 28
    local margin = 20

    love.graphics.setFont(gFonts["hud"])

    local function drawMedievalBar(x, y, current, max, label, color, subLabel)
        -- 1. Outer Border
        love.graphics.setColor(0.05, 0.05, 0.05, 1)
        love.graphics.rectangle("fill", x - 4, y - 4, barW + 8, barH + 8)
        love.graphics.setColor(0.3, 0.3, 0.35, 1)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", x - 4, y - 4, barW + 8, barH + 8)

        -- 2. Corner Rivets
        love.graphics.setColor(0.5, 0.5, 0.5, 1)
        love.graphics.circle("fill", x - 4, y - 4, 3)
        love.graphics.circle("fill", x + barW + 4, y - 4, 3)
        love.graphics.circle("fill", x - 4, y + barH + 4, 3)
        love.graphics.circle("fill", x + barW + 4, y + barH + 4, 3)

        -- 3. Stone Background
        love.graphics.setColor(0.15, 0.15, 0.15, 1)
        love.graphics.rectangle("fill", x, y, barW, barH)

        -- 4. The Fill
        local percent = math.max(0, current / max)
        love.graphics.setColor(color[1], color[2], color[3], 1)
        love.graphics.rectangle("fill", x, y, barW * percent, barH)

        -- 5. Medieval Bevel
        love.graphics.setColor(0, 0, 0, 0.3)
        love.graphics.rectangle("fill", x, y + barH * 0.7, barW * percent, barH * 0.3)
        love.graphics.setColor(1, 1, 1, 0.15)
        love.graphics.rectangle("fill", x, y, barW * percent, 4)

        -- 6. Text
        love.graphics.setColor(0.8, 0.7, 0.5, 1)
        love.graphics.print(label, x, y - 22)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(math.max(0, math.ceil(current)) .. " " .. subLabel, x, y + 4, barW, "center")
    end

    -- Draw Health
    local hpX, hpY = margin + 5, margin + 25
    drawMedievalBar(hpX, hpY, self.hp, self.maxHp, "HEALTH", {0.6, 0.1, 0.1}, "/ " .. self.maxHp)

    -- Draw Armor
    local armX, armY = margin + 5, hpY + barH + 35
    drawMedievalBar(armX, armY, self.armor, 100, "ARMOR", {0.1, 0.4, 0.7}, "/ 100")

    -- Draw Stamina
    local staX, staY = margin + 5, armY + barH + 35
    drawMedievalBar(staX, staY, self.stamina, self.maxStamina, "STAMINA", {0.2, 0.6, 0.2}, "/ " .. self.maxStamina)

    -- Coin Counter
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", margin, staY + barH + 15, 140, 30, 4)
    love.graphics.setColor(0.9, 0.8, 0.5, 1)
    love.graphics.print("COINS: " .. (self.coins or 0) .. " / 20", margin + 10, staY + barH + 20)
    
    love.graphics.setLineWidth(1)
end

function Knight:render()
    -- Draw Knight
    local pivotX = self.x + self.w / 2
    local pivotY = self.y + self.h
    local center = self.lightCenters[self.state] or self.lightCenters.idle

    local drawScale = self.displayScale * (self.growthTimer > 0 and 1.5 or 1)
    local scaleX = (self.direction == "right" and 1 or -1) * drawScale

    if self.hp <= 0 then
        love.graphics.setColor(0.3, 0, 0)
    elseif self.attackTimer > 0 then
        love.graphics.setColor(1, 1, 0.7)
    elseif self.state == "hurt" then -- FIXED: Only pulse red when in the "hurt" state
        local pulse = 0.5 + 0.5 * math.sin(love.timer.getTime() * 25)
        love.graphics.setColor(1, pulse, pulse)
    else
        love.graphics.setColor(1, 1, 1)
    end

    if self.texture and self.quad then
        love.graphics.draw(self.texture, self.quad, pivotX, pivotY, 0, scaleX, drawScale, center.x, self.frameHeight)
    else
        local size = 16
        local centerY = math.floor(self.y + self.h / 2)
        love.graphics.rectangle("fill", pivotX - size / 2, centerY - size / 2, size, size)
    end
    love.graphics.setColor(1, 1, 1)
end

return Knight