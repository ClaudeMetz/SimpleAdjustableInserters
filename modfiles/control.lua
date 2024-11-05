-- ** Util **
local belt_types = {
    ["transport-belt"] = true,
    ["linked-belt"] = true,
    ["underground-belt"] = true,
    ["splitter"] = true,
    ["lane-splitter"] = true,
    ["loader"] = true,
    ["loader-1x1"] = true
}

---@param a number
---@param b number
---@return number result
local function threeway_compare(a, b)
    if a < b then return - 1
    elseif a > b then return 1
    else return 0 end
end

---@param position MapPosition
---@return MapPosition center_position
local function tile_center(position)
    return {math.floor(position.x) + 0.5, math.floor(position.y) + 0.5}
end

---@param event EventData.CustomInputEvent
---@return LuaEntity? inserter
local function find_inserter(event)
    local player = game.get_player(event.player_index)  --[[@as LuaPlayer]]

    local prototype = event.selected_prototype
    if not prototype or prototype.derived_type ~= "inserter" then
        if prototype and prototype.derived_type == "entity-ghost" then
            player.create_local_flying_text{text={"sai.ghost_inserter"}, create_at_cursor=true}
        end
        return nil
    end

    return player.surface.find_entity(prototype.name, tile_center(event.cursor_position))
end

---@param inserter LuaEntity
---@return BeltDirection? belt_direction
local function determine_belt_direction(inserter)
    local position = tile_center(inserter.drop_position)
    local target = nil
    for _, entity in pairs(inserter.surface.find_entities_filtered{position = position}) do
        if belt_types[entity.type] or belt_types[entity.ghost_type] then target = entity; break end
    end
    if not target then return nil end

    local inserter_mod  = inserter.direction % defines.direction.south  ---@type integer
    local target_mod = target.direction % defines.direction.south  ---@type integer
    return (inserter_mod == target_mod) and "perpendicular" or "parallel"
end


-- ** Dropoff adjustement **
---@alias DropDirection "forwards" | "backwards"
---@alias BeltDirection "parallel" | "perpendicular"

---@param event EventData.CustomInputEvent
local function shift_drop_position(event)
    if not settings.global["sai-set-drop-enable"].value then return end

    local inserter = find_inserter(event)
    if not inserter then return end

    local direction = string.gsub(event.input_name, "sai_set_drop_", "")  ---@type DropDirection
    local belt_direction = determine_belt_direction(inserter)

    -- Inserter drop_position is always relative to its direction, so we just apply the y offset
    local relative_drop = inserter.prototype.inserter_drop_position  --[[@as Vector]]
    local para_mod = relative_drop[1]  -- the parallel direction is always the x coordinate
    local perp_mod = relative_drop[2]  -- the perpendicular direction is always the y coordinate
    -- Sets the the drop point to the default if no belt is found

    if belt_direction == "parallel" then
        perp_mod = perp_mod + (direction == "forwards" and 0 or -0.5)
    elseif belt_direction == "perpendicular" then
        para_mod = para_mod + (direction == "forwards" and 0.25 or -0.25)
    end

    local center_x, center_y = inserter.position.x, inserter.position.y
    local positions = {
        [defines.direction.north] = {center_x + para_mod, center_y + perp_mod},
        [defines.direction.east] = {center_x - perp_mod, center_y - para_mod},
        [defines.direction.south] = {center_x - para_mod, center_y - perp_mod},
        [defines.direction.west] = {center_x + perp_mod, center_y + para_mod}
    }  ---@type { [defines.direction]: MapPosition }
    inserter.drop_position = positions[inserter.direction]
end

script.on_event("sai_set_drop_forwards", shift_drop_position)
script.on_event("sai_set_drop_backwards", shift_drop_position)


-- ** Pickup rotation **
---@alias Rotation "clockwise" | "anti_clockwise"

---@param event EventData.CustomInputEvent
local function rotate_pickup_direction(event)
    if not settings.global["sai-rotate-pickup-enable"].value then return end

    local inserter = find_inserter(event)
    if not inserter then return end
    local direction = string.gsub(event.input_name, "sai_rotate_pickup_", "")  ---@type Rotation

    -- Inserter pickup_position is always relative to its direction, so we just apply the y offset
    local relative_pickup = inserter.prototype.inserter_pickup_position  --[[@as Vector]]
    local pickup_modifier = relative_pickup[2] * (direction == "clockwise" and -1 or 1)
    local center_x, center_y = inserter.position.x, inserter.position.y

    local threeway_x = threeway_compare(center_x, inserter.pickup_position.x)
    local threeway_y = threeway_compare(center_y, inserter.pickup_position.y)
    -- This looks arcane, but it cancels out correctly with either threeway being 0
    inserter.pickup_position = {
        center_x + threeway_y * pickup_modifier,
        center_y - threeway_x * pickup_modifier
    }
end

script.on_event("sai_rotate_pickup_clockwise", rotate_pickup_direction)
script.on_event("sai_rotate_pickup_anti_clockwise", rotate_pickup_direction)


-- TODO
-- Play around with using inserter-throughput-lib for throughput display
-- Could maybe adjust ghosts by pasting blueprint over it, seems to work manually
