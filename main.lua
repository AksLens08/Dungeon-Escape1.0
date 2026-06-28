-- main.lua
-- Main entry
local Menu     = require("graphics.background")
local Knight   = require("knight.knight")
local Dungeon  = require("graphics.dungeon")
local Lighting = require("graphics.lighting")
local Wizard   = require("wizard.wizard")
local KM       = require("boss.km")
local Coin     = require("collectables.coin")
local BlueSlime  = require("Blue_slime.blue_slime")
local RedSlime   = require("Red_slime.red_slime")
local GreenSlime = require("Green_slime.green_slime")
local SkeletonArcher = require("Skeleton_Archer.skeleton_archer")
local SkeletonWarrior = require("Skeleton_Warrior.skeleton_warrior")
local SkeletonSpearman = require("Skeleton_Spearman.skeleton_spearman")
local Minimap  = require("graphics.minimap")
local Spawner  = require("system.spawner")
local Push     = require("system.push")
Audio = require("Audios.audio")

gameState = "menu"
local mainMenu, player, dungeon, lighting, coins, isPaused, camera, enemies, jumpScareSounds, projectiles, minimap, selectedClass, corpses
local jumpScareTimer, jumpScareDuration = 0, 2
local caughtKM = nil
local COINS_REQUIRED = 20
local SPAWN_PADDING = 24
local coinsCollected = 0
local gameWon = false
gTextures, gFrames, gFonts = {}, {}, {}
gMouse = { leftDown = false, rightDown = false }

local function triggerWinIfReady()
    -- Win check
    if not gameWon and coinsCollected >= COINS_REQUIRED then
        gameWon = true
        gameState = "win"
        Audio:stop("background_music")
        Audio:play("victory_song")
    end
end

local function isWithinRect(x, y, rx, ry, rw, rh)
    return x >= rx and x <= rx + rw and y >= ry and y <= ry + rh
end

local function drawRetryQuitButtons(sw, sh)
    -- End UI
    local btnW, btnH = 320, 80
    local bx = (sw - btnW) / 2
    local ry = sh * 0.5

    love.graphics.setFont(gFonts["button"])
    love.graphics.setColor(0.2, 0.2, 0.2, 1)
    love.graphics.rectangle("fill", bx, ry, btnW, btnH)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("RETRY", bx, ry + 20, btnW, "center")

    love.graphics.setColor(0.2, 0.2, 0.2, 1)
    love.graphics.rectangle("fill", bx, ry + 100, btnW, btnH)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("QUIT", bx, ry + 120, btnW, "center")
end

local function drawSelectionButtons(sw, sh)
    -- Hero picker
    local btnW, btnH = 320, 80
    local bx = (sw - btnW) / 2
    local ry = sh * 0.45

    love.graphics.setFont(gFonts["title"])
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("SELECT HERO", 0, sh * 0.15, sw, "center")

    love.graphics.setFont(gFonts["button"])
    -- Knight Button
    love.graphics.setColor(0.15, 0.15, 0.2, 0.9)
    love.graphics.rectangle("fill", bx, ry, btnW, btnH, 5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("KNIGHT", bx, ry + 20, btnW, "center")

    -- Wizard Button
    love.graphics.setColor(0.2, 0.15, 0.25, 0.9)
    love.graphics.rectangle("fill", bx, ry + 110, btnW, btnH, 5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("WIZARD", bx, ry + 130, btnW, "center")
end

local function startGame()
    -- Init world
    if player then return end
    projectiles = {}
    corpses = {}
    coinsCollected = 0
    gameWon = false
    dungeon = Dungeon:new("graphics/dungeon.png", 16)
    
    local spawnX, spawnY = dungeon:getLeftmostSpawnPoint(Knight.HITBOX_W, Knight.HITBOX_H, SPAWN_PADDING)
    if not spawnX then
        spawnX, spawnY = dungeon:getRandomSpawnPoint(Knight.HITBOX_W, Knight.HITBOX_H, SPAWN_PADDING)
    end
    if not spawnX then
        print("Warning: Could not find a walkable spawn point for the knight.")
        return
    end

    if selectedClass == "wizard" then
        player = Wizard.new(spawnX, spawnY)
    else
        player = Knight:new(spawnX, spawnY)
    end

    enemies = {}
    caughtKM = nil

    -- Boss
    local kmX, kmY = dungeon:getRightmostSpawnPoint(KM.HITBOX_W, KM.HITBOX_H, SPAWN_PADDING)
    if kmX then
        local boss = KM:new(kmX, kmY)
        boss.hp = 1000
        table.insert(enemies, boss)
    else
        print("Warning: Could not find a walkable spawn point for KM in the boss room.")
    end

    -- Enemies
    local slimeSpawns = dungeon:getSpawnPointsOutsideSafeRoom(18, BlueSlime.HITBOX_W, BlueSlime.HITBOX_H, SPAWN_PADDING)
    local slimeClasses = { BlueSlime, RedSlime, GreenSlime }
    for i, pos in ipairs(slimeSpawns) do
        local classIndex = math.min(#slimeClasses, math.floor((i - 1) / 6) + 1)
        local class = slimeClasses[classIndex]
        table.insert(enemies, class.new(pos.x, pos.y))
    end

    local archerSpawns = dungeon:getSpawnPointsOutsideSafeRoom(6, SkeletonArcher.HITBOX_W, SkeletonArcher.HITBOX_H, SPAWN_PADDING)
    for _, pos in ipairs(archerSpawns) do
        local skeleton = SkeletonArcher:new(pos.x, pos.y)
        skeleton.hp, skeleton.maxHp = 250, 250
        table.insert(enemies, skeleton)
    end

    local warriorSpawns = dungeon:getSpawnPointsOutsideSafeRoom(6, SkeletonWarrior.HITBOX_W, SkeletonWarrior.HITBOX_H, SPAWN_PADDING)
    for _, pos in ipairs(warriorSpawns) do
        table.insert(enemies, SkeletonWarrior:new(pos.x, pos.y))
    end

    local spearmanSpawns = dungeon:getSpawnPointsOutsideSafeRoom(6, SkeletonSpearman.HITBOX_W, SkeletonSpearman.HITBOX_H, SPAWN_PADDING)
    for _, pos in ipairs(spearmanSpawns) do
        local skeleton = SkeletonSpearman:new(pos.x, pos.y)
        skeleton.hp, skeleton.maxHp = 250, 250
        table.insert(enemies, skeleton)
    end

    -- Coins
    coins = {}
    local attemptedCoins = 0
    local roomThreshold = dungeon.tileSize * 5

    while #coins < COINS_REQUIRED and attemptedCoins < COINS_REQUIRED * 10 do
        attemptedCoins = attemptedCoins + 1
        local x, y = Spawner.getValidSpawnPoint(dungeon, Coin.w, Coin.h, SPAWN_PADDING, 50)
        if x and y then
            if x > roomThreshold and x < (dungeon.width - roomThreshold) then
                local duplicate = false
                for _, coin in ipairs(coins) do
                    if math.abs(coin.x - (x - Coin.w / 2)) < Coin.w and math.abs(coin.y - (y - Coin.h / 2)) < Coin.h then
                        duplicate = true
                        break
                    end
                end
                if not duplicate then table.insert(coins, Coin:new(x, y)) end
            end
        end
    end
    if #coins < COINS_REQUIRED then
        print(string.format("Warning: Only spawned %d/%d coins.", #coins, COINS_REQUIRED))
    end

    minimap = Minimap:new(dungeon)
    lighting = Lighting:new(player)

    local sw = love.graphics.getWidth()
    local sh = love.graphics.getHeight()
    local worldScale = 3
    local playerCenterX, playerCenterY = player:getCenter()
    camera.x = (playerCenterX * worldScale) - sw / 2
    camera.y = (playerCenterY * worldScale) - sh / 2
    print(string.format("Camera initialized at: x=%.2f, y=%.2f", camera.x, camera.y))

    if Audio:isPlaying("menu_music") then
        -- Switch music track
        Audio:stop("menu_music")
    end
    Audio:play("background_music")
end

function love.load()
    math.randomseed(os.time())
    love.window.setFullscreen(true)
    love.graphics.setDefaultFilter("nearest", "nearest")
    local function safelyLoadImage(path)
        -- Asset loader with file check
        if love.filesystem.getInfo(path) then
            return love.graphics.newImage(path)
        end
        print("Warning: Could not find image at " .. path)
        return nil
    end

    isPaused = false
    projectiles = {}
    enemies = {}
    corpses = {}
    camera = { x = 0, y = 0 }
    gFonts = {
        ["title"]  = love.graphics.newFont(120),
        ["button"] = love.graphics.newFont(40),
        ["hud"]    = love.graphics.newFont(20)
    }

    -- Texture mapping
    gTextures = {
        ["background"]     = safelyLoadImage("graphics/main-menu.png"),
        ["dungeon_layout"] = safelyLoadImage("graphics/dungeon.png"),
        ["knight_idle"]    = safelyLoadImage("knight/Idle.png"),
        ["knight_walk"]    = safelyLoadImage("knight/Walk.png"),
        ["knight_attack"]    = safelyLoadImage("knight/Attack 1.png"),
        ["knight_attack2"]   = safelyLoadImage("knight/Attack 2.png"),
        ["knight_attack3"]   = safelyLoadImage("knight/Attack 3.png"),
        ["knight_run_attack"] = safelyLoadImage("knight/Run+Attack.png"),
        ["knight_run"]       = safelyLoadImage("knight/Run.png"),
        ["knight_jump"]      = safelyLoadImage("knight/Jump.png"),
        ["knight_protect"]   = safelyLoadImage("knight/Protect.png"),
        ["knight_hurt"]      = safelyLoadImage("knight/Hurt.png"),
        ["knight_death"]     = safelyLoadImage("knight/Dead.png"),
        ["knight_defend"]    = safelyLoadImage("knight/Defend.png"),
        ["km"]             = safelyLoadImage("boss/KM.png"),
        ["game_won"]       = safelyLoadImage("graphics/Game_Won.png"),
        ["km_caught"]      = safelyLoadImage("boss/KM_got_you.png"),
        ["wizard_idle"]    = safelyLoadImage("wizard/Idle.png"),
        ["wizard_walk"]    = safelyLoadImage("wizard/Walk.png"),
        ["wizard_attack"]  = safelyLoadImage("wizard/Attack_1.png"),
        ["wizard_death"]   = safelyLoadImage("wizard/Dead.png"),
        ["wizard_flame"]   = safelyLoadImage("wizard/Flame_jet.png"),
        ["wizard_fire"]    = safelyLoadImage("wizard/Fireball.png"),
        ["wizard_charge"]  = safelyLoadImage("wizard/Charge.png"),
        ["wizard_hurt"]    = safelyLoadImage("wizard/Hurt.png"),
        ["wizard_run"]     = safelyLoadImage("wizard/Run.png"), -- Add wizard run texture
        ["blue_slime_idle"]   = safelyLoadImage("Blue_slime/Idle.png"),
        ["blue_slime_walk"]   = safelyLoadImage("Blue_slime/Walk.png") or safelyLoadImage("Blue_slime/Hop.png"),
        ["blue_slime_attack"] = safelyLoadImage("Blue_slime/Attack_1.png"),
        ["blue_slime_hurt"]   = safelyLoadImage("Blue_slime/Hurt.png"),
        ["blue_slime_death"]  = safelyLoadImage("Blue_slime/Dead.png"),
        ["red_slime_idle"]    = safelyLoadImage("Red_slime/Idle.png"),
        ["red_slime_walk"]    = safelyLoadImage("Red_slime/Walk.png") or safelyLoadImage("Red_slime/Hop.png"),
        ["red_slime_attack"]  = safelyLoadImage("Red_slime/Attack_1.png"),
        ["red_slime_hurt"]    = safelyLoadImage("Red_slime/Hurt.png"),
        ["red_slime_death"]   = safelyLoadImage("Red_slime/Dead.png"),
        ["green_slime_idle"]  = safelyLoadImage("Green_slime/Idle.png"),
        ["green_slime_walk"]  = safelyLoadImage("Green_slime/Walk.png") or safelyLoadImage("Green_slime/Hop.png"),
        ["green_slime_attack"]= safelyLoadImage("Green_slime/Attack_1.png"),
        ["green_slime_hurt"]  = safelyLoadImage("Green_slime/Hurt.png"),
        ["green_slime_death"] = safelyLoadImage("Green_slime/Dead.png"),
        ["skeleton_archer_idle"]   = safelyLoadImage("Skeleton_Archer/Idle.png"),
        ["skeleton_archer_walk"]   = safelyLoadImage("Skeleton_Archer/Walk.png"),
        ["skeleton_archer_attack"] = safelyLoadImage("Skeleton_Archer/Shot_1.png"),
        ["skeleton_archer_death"]  = safelyLoadImage("Skeleton_Archer/Dead.png"),
        ["arrow"]                  = safelyLoadImage("Skeleton_Archer/arrow.png"),
        ["skeleton_warrior_idle"]   = safelyLoadImage("Skeleton_Warrior/Idle.png"),
        ["skeleton_warrior_walk"]   = safelyLoadImage("Skeleton_Warrior/Walk.png"),
        ["skeleton_warrior_attack"] = safelyLoadImage("Skeleton_Warrior/Attack_2.png"),
        ["skeleton_warrior_death"]  = safelyLoadImage("Skeleton_Warrior/Dead.png"),
        ["skeleton_spearman_idle"]   = safelyLoadImage("Skeleton_Spearman/Idle.png"),
        ["skeleton_spearman_walk"]   = safelyLoadImage("Skeleton_Spearman/Walk.png"),
        ["skeleton_spearman_attack"] = safelyLoadImage("Skeleton_Spearman/Attack_1.png") or safelyLoadImage("Skeleton_Spearman/Attack1.png"),
        ["skeleton_spearman_death"]  = safelyLoadImage("Skeleton_Spearman/Dead.png")
    }

    Coin.load()

    -- FX setup
    if gTextures["wizard_fire"] then
        gFrames["fireball_anim"] = {}
        for i = 0, 7 do
            table.insert(gFrames["fireball_anim"], love.graphics.newQuad(i * 128 + 80, 0, 48, 128, gTextures["wizard_fire"]:getDimensions()))
        end
    end

    jumpScareSounds = {}
    local jsFiles = { "Audios/Jumpscare1.mp3", "Audios/Jumpscare2.mp3" }
    for _, path in ipairs(jsFiles) do
        if love.filesystem.getInfo(path) then
            table.insert(jumpScareSounds, love.audio.newSource(path, "static"))
        end
    end
    jumpScareTimer = 0

    Audio:load()
    Audio:addSound("victory_song", "Audios/victory_song.mp3", "static")

    mainMenu = Menu:new()
    Audio:play("menu_music")
end

function love.update(dt)
    -- Game loop
    if gameState == "play" and not player then
        startGame()
    end

    if gameState == "dead" then
        if player then
            player:update(dt, dungeon, gMouse, projectiles, camera, enemies)
            
            local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
            local worldScale = 3
            local playerCenterX, playerCenterY = player:getCenter()
            camera.x = (playerCenterX * worldScale) - sw / 2
            camera.y = (playerCenterY * worldScale) - sh / 2

            if player.deadAnimationComplete then
                gameState = "gameover"
            end
        end
        return
    end

    if gameState == "play" and player and not isPaused then
        if minimap then minimap:update(player, enemies, coins, camera, dt) end

        local projCountBefore = #projectiles
        player:update(dt, dungeon, gMouse, projectiles, camera, enemies)
        for i = projCountBefore + 1, #projectiles do
            local p = projectiles[i]
            if p.type ~= "arrow" and (p.owner == "player" or p.owner == player) then
                Audio:play("fireball")
            end
        end
        
        local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
        local worldScale = 3
        local playerCenterX, playerCenterY = player:getCenter()
        camera.x = (playerCenterX * worldScale) - sw / 2
        camera.y = (playerCenterY * worldScale) - sh / 2

        if enemies then
            for i = #enemies, 1, -1 do
                local enemy = enemies[i]
                local projectileCountBefore = #projectiles
                enemy:update(dt, player, dungeon, projectiles)
                for pIdx = projectileCountBefore + 1, #projectiles do
                    local p = projectiles[pIdx]
                    if p.type ~= "arrow" and (p.owner == "player" or p.owner == player) then
                        Audio:play("fireball")
                    end
                end
                
                if enemy.caught and gameState == "play" then
                    -- Jumpscare
                    gameState = "dead"
                    jumpScareTimer = 0
                    Audio:stop("background_music")
                    if enemy.name == "KM" then
                        caughtKM = enemy
                    end
                    if #jumpScareSounds > 0 then
                        local s = jumpScareSounds[math.random(#jumpScareSounds)]
                        s:stop()
                        love.audio.play(s)
                    end
                end

                if (player.state == "attack" or player.state == "run_attack") and player.frame == 2 and enemy.hp > 0 then
                    -- Melee check
                    local ex, ey = enemy.x + (enemy.w or 0) / 2, enemy.y + (enemy.h or 0) / 2
                    if enemy.getCenter then ex, ey = enemy:getCenter() end
                    
                    local dx, dy = playerCenterX - ex, playerCenterY - ey
                    local distSq = dx*dx + dy*dy
                    if distSq < 1000 then
                        local kbMult = (selectedClass == "wizard") and 0.5 or 1.0
                        enemy:takeDamage(player.damage, player, dungeon, kbMult)
                    end
                end

                local isDeadAnimComplete = enemy.deadAnimationComplete
                if type(isDeadAnimComplete) == "boolean" then
                    -- Death list
                    if isDeadAnimComplete then
                        local _, _, qw, qh = 0, 0, 0, 0
                        if enemy.quad then
                            _, _, qw, qh = enemy.quad:getViewport()
                        end

                        table.insert(corpses, {
                            texture = enemy.texture,
                            quad = enemy.quad,
                            x = enemy.x,
                            y = enemy.y,
                            w = enemy.w or 20,
                            h = enemy.h or 30,
                            direction = enemy.direction,
                            displayScale = enemy.displayScale or 1.0,
                            frameWidth = enemy.frameWidth or qw,
                            frameHeight = enemy.frameHeight or qh,
                        })
                        table.remove(enemies, i)
                    end
                end
            end
        end

        local coinsBefore = player.coins
        Coin.updateAll(coins, dt, player)
        if player.coins ~= coinsBefore then
            coinsCollected = math.min(player.coins, COINS_REQUIRED)
            player.coins = coinsCollected
            triggerWinIfReady()
        end

        -- Projectiles
        for i = #projectiles, 1, -1 do
            local p = projectiles[i]
            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt
            p.life = (p.life or 3) - dt
            
            p.timer = (p.timer or 0) + dt
            if p.frame and p.timer > 0.08 then
                p.timer = 0
                p.frame = (p.frame % 8) + 1
            end

            if p.life <= 0
                or dungeon:isBlocked(p.x, p.y)
                or p.x < 0 or p.y < 0
                or p.x > dungeon.width or p.y > dungeon.height then
                table.remove(projectiles, i)
            else
                local removed = false
                if p.owner ~= "player" then
                    -- Damage player
                    local px, py = player:getCenter()
                    if math.sqrt((p.x - px)^2 + (p.y - py)^2) < 10 and player.hp > 0 and (player.invuln or 0) <= 0 then
                        player:takeDamage(15, p.owner, dungeon)
                        table.remove(projectiles, i)
                        removed = true
                    end
                end

                if not removed and p.owner == "player" then
                    -- Damage enemies
                    for j = #enemies, 1, -1 do
                        local e = enemies[j]
                        local ex, ey = e.x + (e.w or 0) / 2, e.y + (e.h or 0) / 2
                        if e.getCenter then ex, ey = e:getCenter() end
                        
                        if math.sqrt((p.x - ex)^2 + (p.y - ey)^2) < 20 and e.hp > 0 and (e.invuln or 0) <= 0 then
                            local kbMult = (selectedClass == "wizard") and 1.5 or 1.0
                            e:takeDamage(player.damage or 40, player, dungeon, kbMult)
                            table.remove(projectiles, i)
                            removed = true
                            break
                        end
                    end
                end
            end
        end

        if player.hp <= 0 and gameState == "play" then
            gameState = "dead"
            jumpScareTimer = 0
            Audio:stop("background_music")
            if #jumpScareSounds > 0 then
                local s = jumpScareSounds[math.random(#jumpScareSounds)]
                s:play()
            end
        end
    end
end

function love.keypressed(key)
    -- Controls
    if key == "escape" then
        love.event.quit()
    elseif key == "p" and gameState == "play" then
        isPaused = not isPaused
    elseif key == "x" and gameState == "play" and minimap then
        minimap:setPositionNext()
    elseif key == "c" and gameState == "play" and player then
        coinsCollected = math.min(coinsCollected + 1, COINS_REQUIRED)
        player.coins = coinsCollected
        triggerWinIfReady()
    end
end

function love.mousepressed(x, y, button)
    -- Mouse inputs
    if button == 1 and not isPaused then gMouse.leftDown = true end
    if button == 2 then gMouse.rightDown = true end

    if gameState == "menu" and button == 1 then
        local choice = mainMenu:checkClick(x, y)
        if choice and mainMenu:handleInput(choice) then
            gameState = "selection" 
        end
    elseif gameState == "selection" and button == 1 then
        local sw, sh = love.graphics.getDimensions()
        local btnW, btnH = 320, 80
        local bx = (sw - btnW) / 2
        local ry = sh * 0.45

        if isWithinRect(x, y, bx, ry, btnW, btnH) then
            Audio:play("button_click")
            selectedClass = "knight"
            gameState = "play"
        elseif isWithinRect(x, y, bx, ry + 110, btnW, btnH) then
            Audio:play("button_click")
            selectedClass = "wizard"
            gameState = "play"
        end
    elseif (gameState == "gameover" or gameState == "dead" or gameState == "win") and button == 1 then
        local sw, sh = love.graphics.getDimensions()
        local btnW, btnH = 320, 80
        local bx = (sw - btnW) / 2
        local ry = sh * 0.5

        if isWithinRect(x, y, bx, ry, btnW, btnH) then
            Audio:play("button_click")
            player = nil
            isPaused = false
            Audio:stop("victory_song")
            gameState = "play"
        elseif isWithinRect(x, y, bx, ry + 100, btnW, btnH) then
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
    -- Draw cycle
    love.graphics.clear(0.05, 0.05, 0.05)
    love.graphics.setColor(1, 1, 1, 1)

    if gameState == "menu" then
        if mainMenu then mainMenu:render() end
    elseif gameState == "selection" then
        local sw, sh = love.graphics.getDimensions()
        drawSelectionButtons(sw, sh)
    elseif gameState == "play" or gameState == "dead" or gameState == "gameover" then
        love.graphics.push()
        love.graphics.scale(3, 3) 
        love.graphics.translate(-camera.x / 3, -camera.y / 3)

        if dungeon and type(dungeon.render) == "function" then 
            dungeon:render() 
        end

        if coins then Coin.drawAll(coins) end

        -- Corpses
        love.graphics.setColor(0.6, 0.6, 0.6, 0.8)
        for _, c in ipairs(corpses) do
            if c.texture and c.quad then
                local scaleX = (c.direction == "right" and 1 or -1) * c.displayScale
                local pivotX = c.x + c.w / 2
                local pivotY = c.y + c.h
                
                local ox = (c.frameWidth and c.frameWidth > 0) and (c.frameWidth / 2) or 0
                local oy = (c.frameHeight and c.frameHeight > 0) and c.frameHeight or 0
                if c.frameData then ox, oy = c.frameData.originX, c.frameData.originY end

                love.graphics.draw(c.texture, c.quad, pivotX, pivotY, 0, scaleX, c.displayScale, ox, oy)
            end
        end
        love.graphics.setColor(1, 1, 1, 1)

        -- Entities
        if enemies then
            for _, e in ipairs(enemies) do
                if e and type(e.render) == "function" then
                    e:render()
                    if e.subType ~= "slime" and e.subType ~= "skeleton" and e.hp and e.maxHp and e.hp < e.maxHp and e.hp > 0 then
                        love.graphics.setColor(0, 0, 0, 0.5)
                        love.graphics.rectangle("fill", e.x, e.y - 10, e.w or 20, 3)
                        love.graphics.setColor(0, 1, 0)
                        love.graphics.rectangle("fill", e.x, e.y - 10, (e.w or 20) * (e.hp / e.maxHp), 3)
                        love.graphics.setColor(1, 1, 1)
                    end
                end
            end
        end

        -- Player
        if player and type(player.render) == "function" then
            player:render()
        end

        -- FX
        for _, p in ipairs(projectiles) do
            local tex, anim = gTextures["wizard_fire"], gFrames["fireball_anim"]
            if p.type == "arrow" then
                local arrowTex = gTextures["arrow"]
                if arrowTex then
                    love.graphics.draw(arrowTex, p.x, p.y, p.angle, 0.2, 0.2, arrowTex:getWidth() / 2, arrowTex:getHeight() / 2)
                end
            else
                if tex and anim and anim[p.frame] then
                    love.graphics.draw(tex, anim[p.frame], p.x, p.y, p.angle, 0.5, 0.5, 24, 64)
                end
            end
        end

        love.graphics.pop()

        -- Lighting
        if lighting and player then
            lighting:render(camera.x, camera.y, 3)
        end

        -- UI
        if player then player:drawHUD() end

        if minimap and player then minimap:draw() end

        if isPaused then
            love.graphics.setColor(0, 0, 0, 0.5)
            love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
            love.graphics.setColor(1, 1, 1)
            love.graphics.setFont(gFonts["title"])
            love.graphics.printf("PAUSED", 0, love.graphics.getHeight()/2 - 60, love.graphics.getWidth(), "center")
        end
    end

    if gameState == "dead" then
    elseif gameState == "gameover" then
        love.graphics.setColor(1, 0, 0, 1)
        love.graphics.setFont(gFonts["title"])
        love.graphics.printf("YOU DIED", 0, love.graphics.getHeight()*0.2, love.graphics.getWidth(), "center")

        local sw, sh = love.graphics.getDimensions()
        drawRetryQuitButtons(sw, sh)
    elseif gameState == "win" then
        local img = gTextures["game_won"]
        local sw, sh = love.graphics.getDimensions()
        
        if img then
            local iw, ih = img:getDimensions()
            local scale = math.max(sw / iw, sh / ih)
            love.graphics.setColor(1, 1, 1)
            love.graphics.draw(img, sw / 2, sh / 2, 0, scale, scale, iw / 2, ih / 2)
        end

        love.graphics.setColor(1, 0.8, 0, 1)
        love.graphics.setFont(gFonts["title"])
        love.graphics.printf("VICTORY", 0, sh * 0.15, sw, "center")

        drawRetryQuitButtons(sw, sh)
    end
end
