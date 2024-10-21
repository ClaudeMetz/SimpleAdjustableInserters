-- Add keyboard shortcuts
data:extend{
    {
        type = "custom-input",
        name = "sai_set_drop_forwards",
        key_sequence = "CONTROL + mouse-wheel-up",
        include_selected_prototype = true,
        consuming = "game-only",
        order = "sai-a"
    },
    {
        type = "custom-input",
        name = "sai_set_drop_backwards",
        key_sequence = "CONTROL + mouse-wheel-down",
        include_selected_prototype = true,
        consuming = "game-only",
        order = "sai-b"
    },
    {
        type = "custom-input",
        name = "sai_rotate_pickup_clockwise",
        key_sequence = "SHIFT + mouse-wheel-up",
        include_selected_prototype = true,
        consuming = "game-only",
        order = "sai-c"
    },
    {
        type = "custom-input",
        name = "sai_rotate_pickup_anti_clockwise",
        key_sequence = "SHIFT + mouse-wheel-down",
        include_selected_prototype = true,
        consuming = "game-only",
        order = "sai-d"
    }
}
