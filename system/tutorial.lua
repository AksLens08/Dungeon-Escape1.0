-- system/tutorial.lua
-- Lightweight stage-based tutorial controller for static dungeon layouts
local Tutorial = {}
Tutorial.__index = Tutorial

local function makeRoom(x, y, w, h)
    return {x = x, y = y, w = w, h = h}
end

local function makeLayout(rooms, connections, exitRoom)
    return {
        rooms = rooms,
        connections = connections,
        exitRoom = exitRoom,
    }
end

function Tutorial:new(heroType)
    local self = setmetatable({}, Tutorial)
    self.heroType = heroType or "knight"
    self.active = false
    self.finished = false
    self.currentStageIndex = 1
    self.promptTimer = 0
    self.promptText = ""
    self.stages = {
        {
            id = "intro",
            title = "First Steps",
            prompt = "Move with WASD and reach the exit. This room is safe.",
            layout = makeLayout(
                {makeRoom(220, 240, 320, 260), makeRoom(760, 240, 320, 260)},
                {{1, 2}},
                2
            ),
            enemies = {}
        },
        {
            id = "skill_demo",
            title = self.heroType == "wizard" and "Wizard Skill Demo" or "Knight Skill Demo",
            prompt = self.heroType == "wizard"
                and "Skill demo: left click fires a bolt, and right click unleashes a flame jet."
                or "Skill demo: left click attacks, and right click lets you defend.",
            layout = makeLayout(
                {makeRoom(220, 240, 320, 260), makeRoom(760, 240, 320, 260)},
                {{1, 2}},
                2
            ),
            enemies = {}
        },
        {
            id = "blue",
            title = "Blue Slime",
            prompt = "A blue slime lunges at close range. Circle it, then strike when it commits.",
            layout = makeLayout(
                {makeRoom(220, 240, 320, 260), makeRoom(760, 240, 320, 260)},
                {{1, 2}},
                2
            ),
            enemies = {
                {type = "blue_slime", x = 900, y = 340}
            }
        },
        {
            id = "red",
            title = "Red Slime",
            prompt = "The red slime is more aggressive. Keep your footing and punish its rush.",
            layout = makeLayout(
                {makeRoom(220, 240, 320, 260), makeRoom(760, 240, 320, 260)},
                {{1, 2}},
                2
            ),
            enemies = {
                {type = "red_slime", x = 900, y = 340}
            }
        },
        {
            id = "green",
            title = "Green Slime",
            prompt = "The green slime is patient. Wait for an opening and then attack.",
            layout = makeLayout(
                {makeRoom(220, 240, 320, 260), makeRoom(760, 240, 320, 260)},
                {{1, 2}},
                2
            ),
            enemies = {
                {type = "green_slime", x = 900, y = 340}
            }
        },
        {
            id = "archer",
            title = "Archer",
            prompt = "The archer keeps distance. Use the room space to dodge and close the gap.",
            layout = makeLayout(
                {makeRoom(220, 240, 320, 260), makeRoom(760, 240, 320, 260)},
                {{1, 2}},
                2
            ),
            enemies = {
                {type = "skeleton_archer", x = 900, y = 340}
            }
        },
        {
            id = "warrior",
            title = "Warrior",
            prompt = "The warrior is sturdy. Stay mobile and strike after its swings.",
            layout = makeLayout(
                {makeRoom(220, 240, 320, 260), makeRoom(760, 240, 320, 260)},
                {{1, 2}},
                2
            ),
            enemies = {
                {type = "skeleton_warrior", x = 900, y = 340}
            }
        },
        {
            id = "spearman",
            title = "Spearman",
            prompt = "The spearman controls space with long reach. Keep your movement tight.",
            layout = makeLayout(
                {makeRoom(220, 240, 320, 260), makeRoom(760, 240, 320, 260)},
                {{1, 2}},
                2
            ),
            enemies = {
                {type = "skeleton_spearman", x = 900, y = 340}
            }
        },
        {
            id = "mixed",
            title = "Combined Trial",
            prompt = "The final room mixes every foe. Use what you learned and survive.",
            layout = makeLayout(
                {makeRoom(220, 180, 320, 260), makeRoom(760, 180, 320, 260), makeRoom(1280, 180, 320, 260)},
                {{1, 2}, {2, 3}},
                3
            ),
            enemies = {
                {type = "blue_slime", x = 860, y = 300},
                {type = "red_slime", x = 990, y = 300},
                {type = "green_slime", x = 1120, y = 300},
                {type = "skeleton_archer", x = 860, y = 420},
                {type = "skeleton_warrior", x = 990, y = 420},
                {type = "skeleton_spearman", x = 1120, y = 420}
            }
        }
    }
    return self
end

function Tutorial:start()
    self.currentStageIndex = 1
    self.active = true
    self.finished = false
    self.promptTimer = 4.5
    self.promptText = self:getCurrentStage().prompt or ""
    return self:getCurrentStage()
end

function Tutorial:getCurrentStage()
    return self.stages[self.currentStageIndex]
end

function Tutorial:getCurrentStageIndex()
    return self.currentStageIndex
end

function Tutorial:getStage(index)
    return self.stages[index]
end

function Tutorial:isActive()
    return self.active and not self.finished
end

function Tutorial:advance()
    if self.currentStageIndex >= #self.stages then
        self.active = false
        self.finished = true
        self.promptText = "Tutorial complete."
        self.promptTimer = 3.5
        return false
    end

    self.currentStageIndex = self.currentStageIndex + 1
    self.promptTimer = 4.5
    self.promptText = self:getCurrentStage().prompt or ""
    return true
end

function Tutorial:update(dt)
    if self.promptTimer and self.promptTimer > 0 then
        self.promptTimer = self.promptTimer - dt
    end
end

function Tutorial:drawOverlay(font)
    if not self.active or not self.promptText or self.promptTimer <= 0 then return end

    local sw, sh = love.graphics.getDimensions()
    local boxX, boxY = 44, math.max(20, sh - 172)
    local boxW, boxH = sw - 88, 128
    local title = self:getCurrentStage().title or "Tutorial"
    local prompt = self.promptText or ""

    love.graphics.setColor(0, 0, 0, 0.72)
    love.graphics.rectangle("fill", boxX, boxY, boxW, boxH, 12)
    love.graphics.setColor(0.95, 0.8, 0.25, 0.95)
    love.graphics.rectangle("line", boxX, boxY, boxW, boxH, 12)

    love.graphics.setColor(1, 1, 1, 1)
    if font then love.graphics.setFont(font) end
    love.graphics.printf(string.format("[%s/%s] %s", self.currentStageIndex, #self.stages, title), boxX + 20, boxY + 20, boxW - 40, "center")

    love.graphics.setColor(0.92, 0.92, 0.92, 1)
    love.graphics.printf(prompt, boxX + 24, boxY + 58, boxW - 48, "center")
end

return Tutorial
