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
---@return LuaEntityPrototype? prototype
local function find_inserter(event)
    local player = game.get_player(event.player_index)  ---@as LuaPlayer

    local entity = player.selected
    if not entity then return nil, nil end

    if entity.type == "inserter" then
        return entity, entity.prototype
    elseif entity.type == "entity-ghost" and entity.ghost_type == "inserter" then
        return entity, prototypes.entity[entity.ghost_name]
    else
        return nil, nil
    end
end

---@param player LuaPlayer
---@param inserter LuaEntity
---@param success boolean
local function play_adjustement_sound(player, inserter, success)
    -- Volume and burst behaviour live on the prototypes in data.lua
    player.play_sound{
        path = success and "sai-adjusted" or "sai-blocked",
        position = inserter.position
    }
end

---@param inserter LuaEntity
---@return BeltDirection? belt_direction
local function determine_belt_direction(inserter)
    local position = tile_center(inserter.drop_position)
    local target = nil
    for _, entity in pairs(inserter.surface.find_entities_filtered{position = position}) do
        if (entity.type == "entity-ghost" and belt_types[entity.ghost_type]) or belt_types[entity.type] then
            target = entity; break
        end
    end
    if not target then return nil end

    local inserter_mod = inserter.direction % defines.direction.south  ---@type integer
    local target_mod = target.direction % defines.direction.south  ---@type integer
    return (inserter_mod == target_mod) and "perpendicular" or "parallel"
end


-- ** Dropoff adjustement **
---@alias DropDirection "forwards" | "backwards"
---@alias BeltDirection "parallel" | "perpendicular"

---@param event EventData.CustomInputEvent
local function shift_drop_position(event)
    if not settings.global["sai-set-drop-enable"].value then return end

    local inserter, prototype = find_inserter(event)
    if not inserter or not prototype then return end

    local player = game.get_player(event.player_index)  ---@as LuaPlayer
    local direction = string.gsub(event.input_name, "sai_set_drop_", "")  ---@type DropDirection
    local belt_direction = determine_belt_direction(inserter)

    -- Inserter drop_position is always relative to its direction, so we just apply the y offset
    local relative_drop = prototype.inserter_drop_position  ---@as Vector
    local para_mod = relative_drop[1]  -- the parallel direction is always the x coordinate
    local perp_mod = relative_drop[2]  -- the perpendicular direction is always the y coordinate

    if belt_direction == "parallel" then
        perp_mod = perp_mod + (direction == "forwards" and 0 or -0.5)
    elseif belt_direction == "perpendicular" then
        para_mod = para_mod + (direction == "forwards" and 0.25 or -0.25)
    else
        player.create_local_flying_text{text={"sai.no-belt-found"}, create_at_cursor=true}
        -- Continue to set the drop position to the default
    end

    local center_x, center_y = inserter.position.x, inserter.position.y
    local positions = {
        [defines.direction.north] = {center_x + para_mod, center_y + perp_mod},
        [defines.direction.east] = {center_x - perp_mod, center_y - para_mod},
        [defines.direction.south] = {center_x - para_mod, center_y - perp_mod},
        [defines.direction.west] = {center_x + perp_mod, center_y + para_mod}
    }  ---@type { [defines.direction]: MapPosition }

    local new_position = positions[inserter.direction]
    local old_position = inserter.drop_position
    inserter.drop_position = new_position

    -- Only play a sound if the position actually meaningfully moved. The epsilon is
    -- needed because positions snap to the engine's 1/256 grid on the way back out.
    local moved = math.abs(old_position.x - new_position[1]) > 0.01
        or math.abs(old_position.y - new_position[2]) > 0.01

    if moved or belt_direction == nil then
        play_adjustement_sound(player, inserter, (belt_direction ~= nil))
    end
end

script.on_event("sai_set_drop_forwards", shift_drop_position)
script.on_event("sai_set_drop_backwards", shift_drop_position)


-- ** Pickup rotation **
---@alias Rotation "clockwise" | "anti_clockwise"

---@param event EventData.CustomInputEvent
local function rotate_pickup_direction(event)
    if not settings.global["sai-rotate-pickup-enable"].value then return end

    local inserter, prototype = find_inserter(event)
    if not inserter or not prototype then return end

    local player = game.get_player(event.player_index)  ---@as LuaPlayer
    local direction = string.gsub(event.input_name, "sai_rotate_pickup_", "")  ---@type Rotation

    -- Inserter pickup_position is always relative to its direction, so we just apply the y offset
    local relative_pickup = prototype.inserter_pickup_position  ---@as Vector
    local pickup_modifier = relative_pickup[2] * (direction == "clockwise" and -1 or 1)
    local center_x, center_y = inserter.position.x, inserter.position.y

    local threeway_x = threeway_compare(center_x, inserter.pickup_position.x)
    local threeway_y = threeway_compare(center_y, inserter.pickup_position.y)
    -- This looks arcane, but it cancels out correctly with either threeway being 0
    local pickup_position = {
        center_x + threeway_y * pickup_modifier,
        center_y - threeway_x * pickup_modifier
    }

    if not settings.global["sai-zero-degree-inserter"].value then
        local drop_center = tile_center(inserter.drop_position)
        if pickup_position[1] == drop_center[1] and pickup_position[2] == drop_center[2] then
            player.create_local_flying_text{text={"sai.zero-degree-disabled"}, create_at_cursor=true}
            play_adjustement_sound(player, inserter, false)
            return
        end
    end

    inserter.pickup_position = pickup_position
    play_adjustement_sound(player, inserter, true)
end

script.on_event("sai_rotate_pickup_clockwise", rotate_pickup_direction)
script.on_event("sai_rotate_pickup_anti_clockwise", rotate_pickup_direction)


-- ** Reach adjustement prevention **
---@param event EventData.on_entity_settings_pasted
local function prevent_reach_adjustement(event)
    if settings.global["sai-allow-reach-adjustement"].value then return end

    local source, destination = event.source, event.destination
    if source.type ~= "inserter" or destination.type ~= "inserter" then return end

    local cx, cy = destination.position.x, destination.position.y
    local src_p, dest_p = source.prototype, destination.prototype

    -- Self-inverse transform between inserter-local (para, perp) and world-space offset
    local function wo(dir, p, q)
        if dir == defines.direction.north then return p, q
        elseif dir == defines.direction.east then return -q, -p
        elseif dir == defines.direction.south then return -p, -q
        else return q, p end
    end

    do  -- Drop: preserve lane offset relative to each inserter's own prototype reach
        local sd, dd = src_p.inserter_drop_position, dest_p.inserter_drop_position
        local p, q = wo(source.direction, source.drop_position.x - source.position.x, source.drop_position.y - source.position.y)
        local wx, wy = wo(destination.direction, dd[1] + p - sd[1], dd[2] + q - sd[2])
        destination.drop_position = {cx + wx, cy + wy}
    end

    do  -- Pickup: preserve world-space rotation angle so 90° rotations paste correctly
        local sp, dp = src_p.inserter_pickup_position, dest_p.inserter_pickup_position
        local spwx, spwy = wo(source.direction, sp[1], sp[2])
        local sawx = source.pickup_position.x - source.position.x
        local sawy = source.pickup_position.y - source.position.y
        local dot = spwx * sawx + spwy * sawy
        local cross = spwx * sawy - spwy * sawx
        local len_sq = spwx * spwx + spwy * spwy
        local dpwx, dpwy = wo(destination.direction, dp[1], dp[2])
        destination.pickup_position = {
            cx + (dpwx * dot - dpwy * cross) / len_sq,
            cy + (dpwx * cross + dpwy * dot) / len_sq
        }
    end
end

script.on_event(defines.events.on_entity_settings_pasted, prevent_reach_adjustement)


-- TODO Play around with using inserter-throughput-lib for throughput display
