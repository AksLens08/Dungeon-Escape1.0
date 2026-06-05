-- coin.lua
local Class = require("system.class")
local Coin = Class.define()

Coin.frames = {}
Coin.w = 6
Coin.h = 6

function Coin.load()
    for i = 1, 9 do
        local name = "collectables/goldCoin" .. i .. ".png"
        local path = name
        if love.filesystem.getInfo(path) then
            local img = love.graphics.newImage(path)
            table.insert(Coin.frames, img)
        end
    end
end

function Coin.updateAll(list, dt, player)
    if list == nil then return end

    for i = #list, 1, -1 do
        local c = list[i]
        
        if player.x < c.x + c.w and player.x + player.w > c.x then
            if player.y < c.y + c.h and player.y + player.h > c.y then
            player.coins = player.coins + 1

            Audio:play("coin_collect")

            table.remove(list, i)
            end
        end
    end
end

function Coin.drawAll(list)
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
            love.graphics.draw(Coin.frames[frame], currentCoin.x, currentCoin.y, 0, 0.75, 0.75)
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
