-- lua/inspect_dungeon_colors.lua
-- Inspect dungeon PNGs and list top colors + sample pixels
-- Usage (run inside Love2D):
--   local inspector = require("lua.inspect_dungeon_colors")
--   inspector.run()

local M = {}

local files = {
    "graphics/Dungeon(1).png",
    "graphics/Dungeon(2).png",
    "graphics/Dungeon(3).png",
    "graphics/Dungeon(4).png",
}

local function to255(r)
    return math.floor(math.max(0, math.min(1, r)) * 255 + 0.5)
end

local function printTopColors(countMap)
    local list = {}
    for k, cnt in pairs(countMap) do
        local r,g,b = k:match("(%d+),(%d+),(%d+)")
        table.insert(list, {cnt = cnt, r = tonumber(r), g = tonumber(g), b = tonumber(b)})
    end
    table.sort(list, function(a,b) return a.cnt > b.cnt end)
    for i=1, math.min(20, #list) do
        local v = list[i]
        print(string.format("[%3d] %d  (%3d,%3d,%3d)", i, v.cnt, v.r, v.g, v.b))
    end
end

function M.run()
    if not love or not love.image or not love.filesystem then
        print("This inspector must be run inside Love2D (use require and call run() from main.lua or a debug hook).")
        return
    end

    for _, name in ipairs(files) do
        local info = love.filesystem.getInfo(name)
        if not info then
            print(name, "MISSING")
        else
            local ok, img = pcall(love.image.newImageData, name)
            if not ok or not img then
                print(name, "failed to load")
            else
                print(name, img:getFormat(), img:getWidth(), img:getHeight())
                local w, h = img:getWidth(), img:getHeight()
                local countMap = {}
                local maxColors = 1000000
                local total = w * h
                -- count colors
                for y = 0, h-1 do
                    for x = 0, w-1 do
                        local r,g,b,a = img:getPixel(x,y)
                        -- ignore fully transparent pixels
                        if a > 0 then
                            local ri,gi,bi = to255(r), to255(g), to255(b)
                            local key = string.format("%d,%d,%d", ri,gi,bi)
                            countMap[key] = (countMap[key] or 0) + 1
                        end
                    end
                end
                if not next(countMap) then
                    print('No opaque colors found')
                else
                    print('Top colors:')
                    printTopColors(countMap)
                end

                local samples = {
                    {x = math.floor(w/2), y = math.floor(h/2)},
                    {x = 10, y = 10},
                    {x = 100, y = 100},
                    {x = math.max(0,w-10), y = math.max(0,h-10)},
                    {x = math.floor(w/4), y = math.floor(h/4)},
                    {x = math.floor(w/2), y = math.floor(h/4)},
                    {x = math.floor(w/4), y = math.floor(h/2)},
                }
                for _, s in ipairs(samples) do
                    local sx, sy = s.x, s.y
                    if sx >= 0 and sx < w and sy >= 0 and sy < h then
                        local r,g,b,a = img:getPixel(sx, sy)
                        print(string.format('sample %d %d -> (%d,%d,%d) a=%.2f', sx, sy, to255(r), to255(g), to255(b), a))
                    end
                end
            end
        end
        print('---')
    end
end

return M
