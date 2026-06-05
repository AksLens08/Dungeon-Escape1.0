-- system/class.lua
-- Generic OOP utility for metatable-based inheritance and instantiation

local Class = {}

function Class.define()
    local cls = {}
    cls.__index = cls

    function cls:new(...)
        local instance = setmetatable({}, cls)
        if type(instance.init) == "function" then
            instance:init(...)
        end
        return instance
    end

    -- Syntactic sugar for Class:new(...)
    setmetatable(cls, {
        __call = function(_, ...)
            return cls:new(...)
        end
    })

    return cls
end

return Class
