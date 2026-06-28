-- background.lua
-- Menu background
local Class = require("system.class")

local Menu = Class.define()

function Menu:init()
    self.image = gTextures["background"] or nil
    self.options = { "Play", "Quit" }
    self.isOpen = true
end

function Menu:render()
    -- Render UI
    if not self.isOpen then return end

    local sw, sh = love.graphics.getDimensions()

    if self.image then
        local sx = sw / self.image:getWidth()
        local sy = sh / self.image:getHeight()
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(self.image, 0, 0, 0, sx, sy)
    else
        love.graphics.setColor(0.08, 0.08, 0.12, 1)
        love.graphics.rectangle("fill", 0, 0, sw, sh)
    end

    if gFonts and gFonts["title"] then
        love.graphics.setFont(gFonts["title"])
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf("DUNGEON ESCAPE", 0, sh * 0.25, sw, "center")
    end

    if not gFonts or not gFonts["button"] then return end
    love.graphics.setFont(gFonts["button"])

    for i, option in ipairs(self.options) do
        local btnW, btnH = 320, 80
        local bx = (sw - btnW) / 2
        local by = sh * 0.5 + ((i - 1) * 110)

        love.graphics.setColor(0.1, 0.1, 0.1, 0.9)
        love.graphics.rectangle("fill", bx, by, btnW, btnH, 5)
        
        love.graphics.setColor(1, 1, 1)
        love.graphics.rectangle("line", bx, by, btnW, btnH, 5)

        love.graphics.printf(option, bx, by + (btnH - gFonts["button"]:getHeight()) / 2, btnW, "center")
    end
    love.graphics.setColor(1, 1, 1)
end

function Menu:checkClick(x, y)
    -- Button detection
    local sw, sh = love.graphics.getDimensions()
    for i, option in ipairs(self.options) do
        local btnW, btnH = 320, 80
        local bx = (sw - btnW) / 2
        local by = sh * 0.5 + ((i - 1) * 110)

        if x >= bx and x <= bx + btnW and y >= by and y <= by + btnH then
            return i
        end
    end
    return nil
end

function Menu:handleInput(choice)
    -- Button logic
    Audio:play("button_click")

    if choice == 1 then
        self.isOpen = false
        return true
    elseif choice == 2 then
        love.event.quit()
    end
    return false
end

return Menu