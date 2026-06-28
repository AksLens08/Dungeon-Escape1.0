-- graphics/ui.lua
-- UI drawing functions
local UI = {}

function UI:drawRetryQuitButtons(sw, sh, fonts)
    local btnW, btnH = 320, 80
    local bx = (sw - btnW) / 2
    local ry = sh * 0.5

    love.graphics.setFont(fonts["button"])
    love.graphics.setColor(0.2, 0.2, 0.2, 1)
    love.graphics.rectangle("fill", bx, ry, btnW, btnH)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("RETRY", bx, ry + 20, btnW, "center")

    love.graphics.setColor(0.2, 0.2, 0.2, 1)
    love.graphics.rectangle("fill", bx, ry + 100, btnW, btnH)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("QUIT", bx, ry + 120, btnW, "center")
end

function UI:drawSelectionButtons(sw, sh, fonts)
    local btnW, btnH = 320, 80
    local bx = (sw - btnW) / 2
    local ry = sh * 0.45

    love.graphics.setFont(fonts["title"])
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("SELECT HERO", 0, sh * 0.15, sw, "center")

    love.graphics.setFont(fonts["button"])
    love.graphics.setColor(0.15, 0.15, 0.2, 0.9)
    love.graphics.rectangle("fill", bx, ry, btnW, btnH, 5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("KNIGHT", bx, ry + 20, btnW, "center")

    love.graphics.setColor(0.2, 0.15, 0.25, 0.9)
    love.graphics.rectangle("fill", bx, ry + 110, btnW, btnH, 5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("WIZARD", bx, ry + 130, btnW, "center")
end

function UI:isWithinRect(x, y, rx, ry, rw, rh)
    return x >= rx and x <= rx + rw and y >= ry and y <= ry + rh
end

return UI