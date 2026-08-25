local util = require("util")

-- Add sound effects
local utility_sounds = data.raw["utility-sounds"]["default"]

local adjusted = util.copy(utility_sounds.rotated_small)  ---@as data.SoundPrototype
adjusted.type = "sound"
adjusted.name = "sai-adjusted"
adjusted.volume = (adjusted.volume or 1) * 0.7  -- scale, so a vanilla retune carries over
adjusted.aggregation = {max_count = 1, remove = true, count_already_playing = true}

local blocked = util.copy(utility_sounds.cannot_build)  ---@as data.SoundPrototype
blocked.type = "sound"
blocked.name = "sai-blocked"
blocked.volume = (blocked.volume or 1) * 0.5  -- scale, so a vanilla retune carries over

data:extend{adjusted, blocked}


-- Add keyboard shortcuts
data:extend{
    {
        type = "custom-input",
        name = "sai_set_drop_forwards",
        key_sequence = "CONTROL + mouse-wheel-up",
        consuming = "game-only",
        order = "sai-a"
    },
    {
        type = "custom-input",
        name = "sai_set_drop_backwards",
        key_sequence = "CONTROL + mouse-wheel-down",
        consuming = "game-only",
        order = "sai-b"
    },
    {
        type = "custom-input",
        name = "sai_rotate_pickup_clockwise",
        key_sequence = "ALT + mouse-wheel-up",
        consuming = "game-only",
        order = "sai-c"
    },
    {
        type = "custom-input",
        name = "sai_rotate_pickup_anti_clockwise",
        key_sequence = "ALT + mouse-wheel-down",
        consuming = "game-only",
        order = "sai-d"
    }
}
