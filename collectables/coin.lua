-- coin.lua
-- Coin collectables
local Class = require("system.class")
local Coin = Class.define()

Coin.frames = {}
Coin.w = 6
Coin.h = 6
Coin.drawScale = 0.75
Coin.defaultPickupRadius = 22

function Coin.load()
    -- Load sprites
    for i = 1, 9 do
        local name = "collectables/goldCoin" .. i .. ".png"
        local path = name
        if love.filesystem.getInfo(path) then
            local img = love.graphics.newImage(path)
            table.insert(Coin.frames, img)
        end
    end
end

function Coin:getDrawSize()
    if #Coin.frames > 0 then
        return Coin.frames[1]:getWidth() * Coin.drawScale
    end
    return self.w
end

function Coin:getCenter()
    -- Pickup origin
    local size = self:getDrawSize()
    return self.x + size / 2, self.y + size / 2
end

-- Center helper
local function getPlayerCenter(player)
    if player.getCenter then
        return player:getCenter()
    end
    return player.x + player.w / 2, player.y + player.h / 2
end

function Coin.updateAll(list, dt, player)
    -- Check collisions
    if list == nil or not player then return end

    local px, py = getPlayerCenter(player)
    local pickupRadius = player.pickupRadius or Coin.defaultPickupRadius
    local pickupRadiusSq = pickupRadius * pickupRadius

    for i = #list, 1, -1 do
        local c = list[i]
        local cx, cy = c:getCenter()
        local dx, dy = px - cx, py - cy

        if dx * dx + dy * dy <= pickupRadiusSq then
            player.coins = (player.coins or 0) + 1
            Audio:play("coin_collect")
            table.remove(list, i)
        end
    end
end

function Coin.drawAll(list)
    -- Draw batch
    if list == nil then return end
    local frame = 1
    if #Coin.frames > 0 then
        local time = love.timer.getTime()
        frame = math.floor(time * 10) % #Coin.frames + 1
    end

    for i = 1, #list do
        local currentCoin = list[i]

        if #Coin.frames > 0 then
            love.graphics.setColor(1, 1, 1)
            love.graphics.draw(Coin.frames[frame], currentCoin.x, currentCoin.y, 0, Coin.drawScale, Coin.drawScale)
        else
            love.graphics.setColor(1, 0.8, 0)
            love.graphics.circle("fill", currentCoin.x + 3, currentCoin.y + 3, 3)
        end
    end
end

function Coin:init(x, y)
    self.w = Coin.w
    self.h = Coin.h
    self.x = (x or 0) - self.w / 2
    self.y = (y or 0) - self.h / 2
end

return Coin
