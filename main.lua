-- main.lua
local Menu     = require("background")
local Knight   = require("knight")
local Dungeon  = require("dungeon")
local Lighting = require("lighting")
local Enemy    = require("enemy")
local KM       = require("km")
local Coin     = require("coin")
Audio          = require("audio") -- Global audio manager

gameState = "menu" -- Start at the main menu
local mainMenu, player, dungeon, lighting, coins, isPaused, camera, enemies, jumpScareSound, projectiles
local jumpScareTimer, jumpScareDuration = 0, 2
gTextures, gFrames, gFonts = {}, {}, {}
gMouse = { leftDown = false, rightDown = false }

local function createJumpscareSound()
    local sampleRate = 44100
    local length = sampleRate * 0.4
    local soundData = love.sound.newSoundData(length, sampleRate, 16, 1)

    for i = 0, length - 1 do
        local t = i / sampleRate
        local freq = 300 + t * 800
        local value = math.sin(2 * math.pi * freq * t) * (1 - t / 0.4)
        soundData:setSample(i, value)
    end

    return love.audio.newSource(soundData, "static")
end

local function startGame()
    if player then return end
    projectiles = {}
    dungeon = Dungeon:new("graphics/dungeon.png", 16)
    
    local spawnX, spawnY = dungeon:getLeftmostSpawnPoint(Knight.HITBOX_W, Knight.HITBOX_H)

    -- Hard Fallback: If map is broken, spawn in the middle of the PNG bounds
    if not spawnX then
        spawnX = dungeon.width / 2
        spawnY = dungeon.height / 2
    end

    player = Knight:new(spawnX, spawnY)
    enemies = {}

    -- Spawn exactly 10 Wizards all around the map as requested
    local Enemy = require("enemy")
    for i = 1, 10 do
        local ex, ey = dungeon:getRandomSpawnPoint(Enemy.HITBOX_W, Enemy.HITBOX_H)
        if ex then
            table.insert(enemies, Enemy:new(ex, ey))
        else
            -- Fallback: Spawn at dungeon center if random spot fails
            table.insert(enemies, Enemy:new(dungeon.width / 2, dungeon.height / 2))
        end
    end

    -- KM Bosses removed for now as requested
    -- for i = 1, math.random(5, 10) do
    --     local kx, ky = dungeon:getRandomSpawnPoint(KM.HITBOX_W, KM.HITBOX_H)
    --     if kx then
    --         table.insert(enemies, KM:new(kx, ky))
    --     end
    -- end

    coins = Coin.spawnGroup(dungeon, 10)

    -- lighting = Lighting:new(player)
    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()
    local worldScale = 3
    local playerCenterX, playerCenterY = player:getCenter()
    camera.x = (playerCenterX * worldScale) - sw / 2
    camera.y = (playerCenterY * worldScale) - sh / 2

    if Audio:isPlaying("menu_music") then
        Audio:stop("menu_music")
    end
    Audio:play("dungeon_music")
end

function love.load()
    math.randomseed(os.time())
    love.window.setFullscreen(true)
    love.graphics.setDefaultFilter("nearest", "nearest") -- keep it pixelated
    -- Don't crash if an image is missing
    local function safelyLoadImage(path)
        if love.filesystem.getInfo(path) then
            return love.graphics.newImage(path)
        end
        print("Warning: Could not find image at " .. path)
        return nil
    end

    isPaused = false
    projectiles = {}
    enemies = {}
    camera = { x = 0, y = 0 }
    gFonts = {
        ["title"]  = love.graphics.newFont(120),
        ["button"] = love.graphics.newFont(40),
        ["hud"]    = love.graphics.newFont(20)
    }

    gTextures = {
        ["background"]     = safelyLoadImage("graphics/main-menu.png"),
        ["dungeon_layout"] = safelyLoadImage("graphics/dungeon.png"),
        ["knight_idle"]    = safelyLoadImage("knight/Idle.png"),
        ["knight_walk"]    = safelyLoadImage("knight/Walk.png"),
        ["knight_attack"]  = safelyLoadImage("knight/Attack 1.png"),
        ["knight_hurt"]    = safelyLoadImage("knight/Hurt.png"),
        ["knight_death"]   = safelyLoadImage("knight/Dead.png"),
        ["knight_defend"]  = safelyLoadImage("knight/Defend.png"), 
        ["km"]             = safelyLoadImage("enemy/KM.png"), -- Changed to lowercase to match km.lua
        -- Wizard animations
        ["wizard_idle"]    = safelyLoadImage("wizard/Idle.png"),
        ["wizard_walk"]    = safelyLoadImage("wizard/Walk.png"),
        ["wizard_attack"]  = safelyLoadImage("wizard/Attack_1.png"),
        ["wizard_death"]   = safelyLoadImage("wizard/Dead.png"),
        ["wizard_fire"]    = safelyLoadImage("wizard/Fireball.png"),
        ["wizard_charge"]  = safelyLoadImage("wizard/Charge.png"),
        ["wizard_hurt"]    = safelyLoadImage("wizard/Hurt.png")
    }

    Coin.load()

    -- Create a quad for the projectile so it only draws the fireball frame from the sheet
    if gTextures["wizard_fire"] then
        gFrames["fireball_anim"] = {}
        for i = 0, 7 do
            -- Crop the quad (x + 80, width 48) to isolate the fireball and remove the wizard character
            table.insert(gFrames["fireball_anim"], love.graphics.newQuad(i * 128 + 80, 0, 48, 128, gTextures["wizard_fire"]:getDimensions()))
        end
    end

    jumpScareSound = createJumpscareSound()
    jumpScareTimer = 0

    Audio:load()

    mainMenu = Menu:new()
    Audio:play("menu_music")
end

function love.update(dt)
    if gameState == "play" and not player then
        startGame()
    end

    if gameState == "dead" then
        jumpScareTimer = jumpScareTimer + dt
        if jumpScareTimer > jumpScareDuration then
            gameState = "gameover"
        end
        return
    end

    if gameState == "play" and player and not isPaused then
        player:update(dt, dungeon, gMouse)
        
        -- Center camera smoothly tracking player positions
        local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
        local worldScale = 3
        local playerCenterX, playerCenterY = player:getCenter()
        camera.x = (playerCenterX * worldScale) - sw / 2
        camera.y = (playerCenterY * worldScale) - sh / 2

        -- Enemy Logic: Update, Catch detection, and Combat
        if enemies then
            for i = #enemies, 1, -1 do
                local enemy = enemies[i]
                enemy:update(dt, player, dungeon, projectiles)
                
                -- Catch detection for KM/Bosses
                if enemy.caught and gameState == "play" then
                    gameState = "dead"
                    if jumpScareSound then jumpScareSound:stop() love.audio.play(jumpScareSound) end
                end

                -- Combat check: If player is attacking on the 'hit' frame
                if player.state == "attack" and player.frame == 2 and enemy.hp > 0 then
                    local ex, ey = enemy.x + enemy.w / 2, enemy.y + enemy.h / 2
                    local dx, dy = playerCenterX - ex, playerCenterY - ey
                    local distSq = dx*dx + dy*dy
                    if distSq < 2500 then enemy:takeDamage(player.damage) end -- 50px range
                end

                -- Cleanup dead enemies
                if enemy.deadAnimationComplete then table.remove(enemies, i) end
            end
        end

        Coin.updateAll(coins, dt, player)

        -- Update Projectiles (Fireballs)
        for i = #projectiles, 1, -1 do
            local p = projectiles[i]
            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt
            
            -- Update animation frame
            p.timer = (p.timer or 0) + dt
            if p.timer > 0.08 then
                p.timer = 0
                p.frame = (p.frame % 8) + 1
            end

            -- Collision with walls or Player
            if dungeon:isBlocked(p.x, p.y) then
                table.remove(projectiles, i)
            else
                local px, py = player:getCenter()
                if math.sqrt((p.x - px)^2 + (p.y - py)^2) < 18 then
                    player:takeDamage(15)
                    table.remove(projectiles, i)
                end
            end
        end

        if player.hp <= 0 and player.deadAnimationComplete then
            gameState = "gameover"
        end
    end
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    elseif key == "p" and gameState == "play" then
        isPaused = not isPaused
    elseif gameState == "play" and player and not isPaused then
        player:handleInput(key)
    end
end

function love.mousepressed(x, y, button)
    if button == 1 and not isPaused then gMouse.leftDown = true end
    if button == 2 then gMouse.rightDown = true end

    if gameState == "menu" and button == 1 then
        local choice = mainMenu:checkClick(x, y)
        if choice and mainMenu:handleInput(choice) then
            gameState = "play" 
        end
    elseif gameState == "gameover" and button == 1 then
        local sw, sh = love.graphics.getDimensions()
        local btnW, btnH = 320, 80
        local bx = (sw - btnW) / 2
        
        -- Retry: reset player and transition to play state (startGame will trigger)
        local ry = sh * 0.5
        if x >= bx and x <= bx + btnW and y >= ry and y <= ry + btnH then
            Audio:play("button_click")
            player = nil
            isPaused = false
            gameState = "play"
        elseif y >= (sh * 0.5 + 100) and y <= (sh * 0.5 + 100 + btnH) and x >= bx and x <= bx + btnW then
            -- Quit
            Audio:play("button_click")
            love.event.quit()
        end
    end
end

function love.mousereleased(_, _, button)
    if button == 1 then gMouse.leftDown = false end
    if button == 2 then gMouse.rightDown = false end
end

function love.draw()
    love.graphics.clear(0.05, 0.05, 0.05)
    love.graphics.setColor(1, 1, 1, 1)

    if gameState == "menu" then
        if mainMenu then mainMenu:render() end
    elseif gameState == "play" or gameState == "dead" or gameState == "gameover" then
        love.graphics.push()
        love.graphics.scale(3, 3) 
        love.graphics.translate(-camera.x / 3, -camera.y / 3)

        -- Safety check for dungeon rendering
        if dungeon and type(dungeon.render) == "function" then 
            dungeon:render() 
        end

        if coins then Coin.drawAll(coins) end -- Correct static call

        if enemies then
            for _, e in ipairs(enemies) do
                if e and type(e.render) == "function" then
                    e:render()
                end
            end
        end

        if player and type(player.render) == "function" then
            player:render()
        end

        -- Draw Fireballs
        for _, p in ipairs(projectiles) do
            local tex, anim = gTextures["wizard_fire"], gFrames["fireball_anim"]
            if tex and anim and anim[p.frame] then
                -- Origin 24 is the center of the 48px cropped width
                love.graphics.draw(tex, anim[p.frame], p.x, p.y, p.angle, 0.5, 0.5, 24, 64)
            end
        end

        love.graphics.pop()

        if player then player:drawHUD() end
        if isPaused then
            love.graphics.setColor(0, 0, 0, 0.5)
            love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
            love.graphics.setColor(1, 1, 1)
            love.graphics.setFont(gFonts["title"])
            love.graphics.printf("PAUSED", 0, love.graphics.getHeight()/2 - 60, love.graphics.getWidth(), "center")
        end
    end

    if gameState == "dead" then
        love.graphics.setColor(1, 0, 0, 1)
        love.graphics.setFont(gFonts["title"])
        love.graphics.printf("KM GOT YOU", 0, love.graphics.getHeight()/2 - 60, love.graphics.getWidth(), "center")
    elseif gameState == "gameover" then
        love.graphics.setColor(1, 0, 0, 1)
        love.graphics.setFont(gFonts["title"])
        love.graphics.printf("GAME OVER", 0, love.graphics.getHeight()*0.2, love.graphics.getWidth(), "center")

        local sw, sh = love.graphics.getDimensions()
        local btnW, btnH = 320, 80
        local bx = (sw - btnW) / 2
        love.graphics.setFont(gFonts["button"])

        local ry = sh * 0.5
        love.graphics.setColor(0.2, 0.2, 0.2, 1)
        love.graphics.rectangle("fill", bx, ry, btnW, btnH)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf("RETRY", bx, ry + 20, btnW, "center")

        local qy = sh * 0.5 + 100
        love.graphics.setColor(0.2, 0.2, 0.2, 1)
        love.graphics.rectangle("fill", bx, qy, btnW, btnH)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf("QUIT", bx, qy + 20, btnW, "center")
    end
end
