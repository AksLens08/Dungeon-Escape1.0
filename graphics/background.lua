-- background.lua
local Class = require("system.class")

local Menu = Class.define()

function Menu:init()
    self.image = gTextures["background"] or nil
    self.options = { "Play", "Quit" }
    self.isOpen = true
end

function Menu:render()
    if not self.isOpen then return end

    -- Aspect-ratio matching draw
    if self.image then
        local sx = love.graphics.getWidth() / self.image:getWidth()
        local sy = love.graphics.getHeight() / self.image:getHeight()
        love.graphics.draw(self.image, 0, 0, 0, sx, sy)
    else
        -- Fallback background color
        love.graphics.clear(0.1, 0.1, 0.1)
    end

    -- Title
    love.graphics.setFont(gFonts["title"])
    love.graphics.setColor(1, 1, 1) -- White color
    love.graphics.printf(
        "DUNGEON ESCAPE",
        0,
        love.graphics.getHeight() * 0.3,
        love.graphics.getWidth(),
        "center"
    )

    -- Options
    love.graphics.setFont(gFonts["button"])
    for i, option in ipairs(self.options) do
        local btnW, btnH = 320, 80
        local bx = (love.graphics.getWidth() - btnW) / 2
        local by = love.graphics.getHeight() * 0.5 + (i * 100)

        love.graphics.setColor(0.15, 0.15, 0.15, 0.9)
        love.graphics.rectangle("fill", bx, by, btnW, btnH, 5)
        
        love.graphics.setColor(1, 1, 1)
        love.graphics.rectangle("line", bx, by, btnW, btnH, 5)

        love.graphics.printf(option, bx, by + (btnH - gFonts["button"]:getHeight()) / 2, btnW, "center")
    end
    love.graphics.setColor(1, 1, 1)
end

function Menu:checkClick(x, y)
    for i, option in ipairs(self.options) do
        local btnW, btnH = 320, 80
        local bx = (love.graphics.getWidth() - btnW) / 2
        local by = love.graphics.getHeight() * 0.5 + (i * 100)

        if x >= bx and x <= bx + btnW and y >= by and y <= by + btnH then
            return i
        end
    end
    return nil
end

function Menu:handleInput(choice)
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