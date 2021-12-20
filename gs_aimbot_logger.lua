-- local variables for API functions. any changes to the line below will be lost on re-generation
local bit_band, client_color_log, client_delay_call, client_eye_position, client_key_state, client_log, client_screen_size, client_set_event_callback, client_unset_event_callback, client_userid_to_entindex, database_read, database_write, entity_get_local_player, entity_get_player_name, entity_get_player_weapon, entity_get_prop, entity_hitbox_position, entity_is_alive, globals_chokedcommands, globals_lastoutgoingcommand, globals_realtime, globals_tickcount, plist_get, renderer_measure_text, renderer_text, require, table_concat, table_remove, ui_get, ui_new_button, ui_new_checkbox, ui_new_color_picker, ui_new_combobox, ui_new_multiselect, pairs, error, globals_absoluteframetime, json_stringify, math_cos, math_deg, math_floor, math_max, math_rad, math_sin, renderer_blur, renderer_circle, renderer_circle_outline, renderer_gradient, renderer_line, renderer_rectangle, renderer_world_to_screen, table_insert, table_sort, tostring, getmetatable, setmetatable, type, assert, ui_mouse_position, ui_reference, ui_set_callback, ui_set_visible, unpack, ui_new_slider, ui_new_label, vtable_bind, vtable_thunk, math_min, math_abs = bit.band, client.color_log, client.delay_call, client.eye_position, client.key_state, client.log, client.screen_size, client.set_event_callback, client.unset_event_callback, client.userid_to_entindex, database.read, database.write, entity.get_local_player, entity.get_player_name, entity.get_player_weapon, entity.get_prop, entity.hitbox_position, entity.is_alive, globals.chokedcommands, globals.lastoutgoingcommand, globals.realtime, globals.tickcount, plist.get, renderer.measure_text, renderer.text, require, table.concat, table.remove, ui.get, ui.new_button, ui.new_checkbox, ui.new_color_picker, ui.new_combobox, ui.new_multiselect, pairs, error, globals.absoluteframetime, json.stringify, math.cos, math.deg, math.floor, math.max, math.rad, math.sin, renderer.blur, renderer.circle, renderer.circle_outline, renderer.gradient, renderer.line, renderer.rectangle, renderer.world_to_screen, table.insert, table.sort, tostring, getmetatable, setmetatable, type, assert, ui.mouse_position, ui.reference, ui.set_callback, ui.set_visible, unpack, ui.new_slider, ui.new_label, vtable_bind, vtable_thunk, math.min, math.abs

local ffi = require("ffi")
local vector = require("vector")

local clipboard = require("gamesense/clipboard")
local table_gen = require("gamesense/table_gen")
local easing = require("gamesense/easing")

local G_SCRIPT_VERSION = "v1.0.1" -- used to recreate database

local g_database_accessor =
    (function()
    local m_table, m_default_table, m_db_key = {}, {}, ""

    local m_set_default_table = function(t)
        m_default_table = t
    end

    local m_set_db_key = function(key)
        m_db_key = key
    end

    local m_read_table = function()
        local t = database_read(m_db_key)
        m_table = t or m_default_table

        return m_table
    end

    local m_erase_data = function()
        database_write(m_db_key, nil)
        m_table = m_default_table

        client_delay_call(0.05, client.reload_active_scripts)
    end

    client_set_event_callback("shutdown", function() database_write(m_db_key, m_table) end)

    return { set_default_table = m_set_default_table, set_db_key = m_set_db_key, read_table = m_read_table, erase_data = m_erase_data }
end)()

g_database_accessor.set_default_table({
        m_total_fired_shots = 0, m_total_fired_sp_shots = 0, m_total_lethal_shots = 0, m_total_kills = 0, m_total_zeus_kills = 0,
        m_fired_shots_by_hitbox = { head = 0, body = 0, limbs = 0 }, m_sp_fired_shots_by_hitbox = { head = 0, body = 0, limbs = 0},
        m_hits = {
            m_total_hits = 0, m_lethal_kills = 0, m_lethal_mismatches = 0,
            m_basic_hits = { m_count = 0, m_mismatches = 0,
                m_per_hitbox = { head = 0, body = 0, limbs = 0 }, m_mismatches_per_hitbox = { head = 0, body = 0, limbs = 0 }
            },
            m_sp_hits = { m_count = 0, m_mismatches = 0,
            m_per_hitbox = { head = 0, body = 0, limbs = 0 }, m_mismatches_per_hitbox = { head = 0, body = 0, limbs = 0 }
            }
        },
        m_misses = {
            m_total_misses = 0, m_total_misses_by_hitbox = { head = 0, body = 0, limbs = 0 },
            m_spread_misses = {
                m_count = 0, m_sp_count = 0,
                m_per_hitbox = { head = 0, body = 0, limbs = 0 }, m_sp_per_hitbox = { head = 0, body = 0, limbs = 0 }
            },
            m_unknown_misses = {
                m_count = 0, m_sp_count = 0,
                m_per_hitbox = { head = 0, body = 0, limbs = 0 }, m_sp_per_hitbox = { head = 0, body = 0, limbs = 0 }
            },
            m_pred_misses = {
                m_count = 0, m_sp_count = 0,
                m_per_hitbox = { head = 0, body = 0, limbs = 0 }, m_sp_per_hitbox = { head = 0, body = 0, limbs = 0 }
            },
            m_death_misses = {
                m_count = 0, m_deaths = { m_local_death = 0, m_enemy_death = 0 }
            }, m_unreg_misses = { m_count = 0 }
        },
        m_additional_data = {
            m_hitchances = {}, m_backtracks = {}, m_average_spread_angles = {}
        },
        m_renderer_data = { m_draggable_position_x = 15, m_draggable_position_y = ({ client_screen_size() })[2] * 0.55 }
    }
)

g_database_accessor.set_db_key(("gs-shot-data-stats-%s"):format(G_SCRIPT_VERSION))

local g_master_switch = ui_new_checkbox("lua", "b", "[+] aimbot shot collector")

local g_event_logger = ui_new_multiselect("lua", "b", "[+] send aimbot events to...", { "display", "console" })

local g_statistics_display = ui_new_combobox("lua", "b", "[+] display statistics...", { "-", "attached to player", "draggable" })

local g_statistics_style = ui_new_combobox("lua", "b", "\nstatistics style", {"mini", "full sized"})

local g_statistics_attach_while_scoped = ui_new_checkbox("lua", "b", "attach statistics while scoped")

local g_statistics_offset_label_firstperson = ui_new_label("lua", "b", "offsets (first person)")
local g_statistics_offset_x_firstperson, g_statistics_offset_y_firstperson = ui_new_slider("lua", "b", "\nstat_offset_x_fp", -200, 200, 0, false), ui_new_slider("lua", "b", "\nstat_offset_y_fp", -200, 200, 100, false)

local g_statistics_offset_label_thirdperson = ui_new_label("lua", "b", "offsets (third person)")
local g_statistics_offset_x_thirdperson, g_statistics_offset_y_thirdperson = ui_new_slider("lua", "b", "\nstat_offset_x_tp", -200, 200, 0, false), ui_new_slider("lua", "b", "\nstat_offset_y_tp", -200, 200, 100, false)

local g_accent_color_picker = ui_new_color_picker("lua", "b", "accent color picker", 170, 0, 125, 255)

local g_erase_statistics = ui_new_button("lua", "b", "erase shot stats", g_database_accessor.erase_data)

local g_log_worker = (function()
    local m_contains = function(t, val)
        for k, v in pairs(t) do
            if v == val then return true end
        end

        return false
    end

    local on_output = function() end

    client_set_event_callback("shutdown", function() client_unset_event_callback("output", on_output) end)

    local m_log_track_list = {}

    local m_colors = {
        red = { 255, 0, 0 },
        green = { 173, 250, 47 },
        accent = { ui_get(g_accent_color_picker) }
    }

    local m_process_string_colors = function(...)
        local t, a, t_it = {}, {...}, 1
        for i = 1, #a do
            local v = a[i]; local ty = type(v)
            if ty == "string" then
                t[t_it] = v
            else
                local r, g, b = v.r, v.g, v.b
                if not r then r, g, b = unpack(m_colors[v.rgb]) end
                t[t_it] = ("\a%02x%02x%02xFF%s\aFFFFFFFF"):format(r, g, b, v.text)
            end
            t_it = t_it + 1
        end
        return table_concat(t, "")
    end

    local m_print_multicolor_text = function(...)
        client_set_event_callback("output", on_output); client_color_log(m_colors.green[1], m_colors.green[2], m_colors.green[3], "[gamesense] \0"); client_unset_event_callback("output", on_output) -- absolute insanity
        local a = {...}
        for i = 1, #a do
            local v = a[i]
            if type(v) == "string" then
                client_color_log( 255, 255, 255, ("%s\0"):format(v) )
            else
                local r, g, b = v.r, v.g, v.b
                if not r then r, g, b = unpack(m_colors[v.rgb]) end
                client_color_log( r, g, b, ("%s\0"):format(v.text) )
            end
            if i == #a then client_color_log(255, 255, 255, " ") end
        end
    end

    local m_add_event_to_log = function(...)
        local selections = ui_get(g_event_logger)
        if #selections == 0 then
            return
        end

        m_colors.accent = { ui_get(g_accent_color_picker) }

        local is_console = m_contains(selections, "console")
        local is_display = m_contains(selections, "display")

        if is_console and is_display then
            client_set_event_callback("output", on_output)
            -- this is disgusting and I hate it
            m_print_multicolor_text(...)
            client_unset_event_callback("output", on_output)
        elseif is_console then
            m_print_multicolor_text(...)
        end

        if not is_display then
            return
        end

        m_log_track_list[#m_log_track_list+1] = { m_time = globals_realtime() + 3, m_string = m_process_string_colors(...) }

        if #m_log_track_list > 5 then
            for i = 1, #m_log_track_list - 5 do
                m_log_track_list[i].m_time = globals_realtime() + 0.1
            end
        end
    end

    local m_think = function()
        if #m_log_track_list == 0 then
            return
        end

        local time = globals_realtime()
        local screen_width, screen_height = client_screen_size()
        local render_position_x, render_position_y = screen_width * 0.5, screen_height * 0.15

        for k, v in pairs(m_log_track_list) do
            local record_time = v.m_time

            if time > record_time then
                table_remove(m_log_track_list, k)
            end
        end

        for i = #m_log_track_list, 1, -1 do
            local rec = m_log_track_list[i]
            local time_delta = rec.m_time - time
            local is_coming_in, is_fading_away = time_delta > 2.5, time_delta < 0.5
            local position_x_offset, position_y_offset = is_coming_in and easing.quad_in(3 - time_delta, 0, 1, 0.5) or 1, is_fading_away and easing.quad_out(time_delta, 0, 1, 0.5) or 1
            local alpha = is_fading_away and time_delta * 100 or 255

            local str = rec.m_string:gsub("\a(%x%x)(%x%x)(%x%x)(%x%x)", ("\a%%1%%2%%3%02x"):format(alpha))

            renderer_text(render_position_x * position_x_offset, render_position_y * position_y_offset, 255, 255, 255, alpha, "dc", 0, str)
            render_position_y = render_position_y - ({ renderer_measure_text("d", str) })[2] - 3
        end
    end

    return { add_event_to_log = m_add_event_to_log, on_paint = m_think }
end)()

local g_aimbot_worker =
    (function()
    local g_aimbot_history_table = g_database_accessor.read_table()

    local m_aimbot_shot_tracklist, m_bullet_impact_tracklist = {}, {}

    local g_safepoint_reference, g_avoid_unsafe_hitboxes_reference, g_mindamage_reference, g_fbaim_reference = ui_reference("rage", "aimbot", "force safe point"), ui_reference("rage", "aimbot", "avoid unsafe hitboxes"), ui_reference("rage", "aimbot", "minimum damage"),
        ui_reference("rage", "other", "force body aim")

    local m_helpers = (function()
        local this = {}

        local m_hitgroup_indices = {
            ["Head"] = {1}, ["Chest"] = {2}, ["Stomach"] = {3}, ["Arms"] = {4, 5}, ["Legs"] = {6, 7},
            ["Feet"] = {6, 7} -- can't be fucked to jerryrig my own tracing to reveal what hitbox we are actually targeting inshallah
        }

        this.is_safe_pointed = function(entity_index, hitgroup)
            local sp_state = ui_get(g_safepoint_reference)

            if sp_state then
                return true
            end

            local plist_state = plist_get(entity_index, "Override safe point")

            if plist_state ~= "-" then
                return plist_state == "On"
            end

            local sp_hitgroups = ui_get(g_avoid_unsafe_hitboxes_reference)

            return (function()
                for i = 1, #sp_hitgroups do
                    local _hitgroup = sp_hitgroups[i]
                    local list = m_hitgroup_indices[_hitgroup]

                    for j = 1, #list do
                        if list[j] == hitgroup then
                            return true
                        end
                    end
                end

                return false
            end)() -- i hate goto i hate goto
        end

        this.is_forcing_bodyaim = function(entity_index)
            return plist_get(entity_index, "Override prefer body aim") == "Force" or ui_get(g_fbaim_reference)
        end

        this.get_hitgroup_class = function(h)
            if h == 1 then
                return "head"
            elseif h <= 3 then
                return "body"
            else
                return "limbs"
            end
        end

        return this
    end)()

    local m_get_bullet_spread = function(id)
        local aim_data = m_aimbot_shot_tracklist[id]

        if not aim_data then
            return
        end

        local impact_data = m_bullet_impact_tracklist[globals_lastoutgoingcommand() + globals_chokedcommands()]

        if not impact_data then
            return -- "lost track of shot........"
        end

        local shoot_pos = aim_data.m_aim_pos

        local ideal_dir = vector(shoot_pos:to(aim_data.m_shot_vector):angles())
        local dist = ideal_dir:dist2d(vector(shoot_pos:to(impact_data[1]):angles()))

        while dist > 180 do
            dist = dist - 360
        end

        while dist < -180 do
            dist = dist + 360
        end

        return math_abs(dist)
    end

    local m_handle_bullet_impact = function(ev)
        if not ev or not ev.userid or not ev.x or not ev.y or not ev.z then
            return
        end

        local entity_index = client_userid_to_entindex(ev.userid)

        if entity_index ~= entity_get_local_player() then
            return
        end

        local seq_num = globals_lastoutgoingcommand() + globals_chokedcommands()

        local t = m_bullet_impact_tracklist[seq_num]

        if not t then
            m_bullet_impact_tracklist[seq_num] = {
                vector(ev.x, ev.y, ev.z)
            }

            return client_delay_call(5, table_remove, m_bullet_impact_tracklist, seq_num)
        end; t[#t + 1] = vector(ev.x, ev.y, ev.z)
    end

    local m_add_value_to_buffer = function(tbl, val, upper) local cnt = #tbl + 1 tbl[cnt] = val if cnt > upper then table_remove(tbl, 1) end end

    local m_flag_builder = {
        { "H", function(ev) return ev.high_priority end },
        { "LTHL", function(ev, aim_data) local hp = entity_get_prop(ev.target, "m_iHealth") or 999; if ev.damage >= hp then aim_data.m_lethal = true; return true end return false end },
        { "FB", function(ev) return m_helpers.is_forcing_bodyaim(ev.target) end },
        { "", function(ev) if plist_get(ev.target, "Force body yaw") then return true, ("BODY %.d°"):format(plist_get(ev.target, "Force body yaw value")) end return false end }
    }

    local m_build_flag_table = function(ev, aim_data)
        local flag_table = {}

        local flag_it = 1

        for i = 1, #m_flag_builder do
            local flag_value = m_flag_builder[i]; local is_active, custom_flag = flag_value[2](ev, aim_data)
            if is_active then
                flag_table[flag_it] = custom_flag or flag_value[1]
                flag_it = flag_it + 1
            end
        end

        return flag_table
    end

    local m_handle_aim_fire = function(ev)
        local aim_data = {}
        aim_data.m_aim_pos, aim_data.m_shot_vector = vector(client_eye_position()), vector(ev.x, ev.y, ev.z)
        aim_data.m_command_number, aim_data.m_backtrack_amount = globals_lastoutgoingcommand() + globals_chokedcommands() + 1, math_max(0, globals_tickcount() - ev.tick)
        aim_data.m_hitgroup, aim_data.m_hit_chance, aim_data.m_damage, aim_data.m_hitgroup_class = ev.hitgroup, ev.hit_chance, ev.damage, m_helpers.get_hitgroup_class(ev.hitgroup)
        aim_data.m_minimum_damage = ui_get(g_mindamage_reference)
        aim_data.m_safepoint = m_helpers.is_safe_pointed(ev.target, ev.hitgroup)

        if aim_data.m_safepoint then
            g_aimbot_history_table.m_total_fired_sp_shots = g_aimbot_history_table.m_total_fired_sp_shots + 1
            g_aimbot_history_table.m_sp_fired_shots_by_hitbox[aim_data.m_hitgroup_class] = g_aimbot_history_table.m_sp_fired_shots_by_hitbox[aim_data.m_hitgroup_class] + 1
        end

        aim_data.m_lethal = false
        aim_data.m_flags = table_concat(m_build_flag_table(ev, aim_data), ",")
        aim_data.m_zeus = bit_band(entity_get_prop(entity_get_player_weapon(entity_get_local_player()), "m_iItemDefinitionIndex"), 0xFFFF) == 31

        g_aimbot_history_table.m_total_fired_shots = g_aimbot_history_table.m_total_fired_shots + 1
        g_aimbot_history_table.m_fired_shots_by_hitbox[aim_data.m_hitgroup_class] = g_aimbot_history_table.m_fired_shots_by_hitbox[aim_data.m_hitgroup_class] + 1

        if aim_data.m_lethal then
            g_aimbot_history_table.m_total_lethal_shots = g_aimbot_history_table.m_total_lethal_shots + 1
        end

        m_aimbot_shot_tracklist[ev.id] = aim_data
        m_add_value_to_buffer(g_aimbot_history_table.m_additional_data.m_hitchances, ev.hit_chance, 250)
        m_add_value_to_buffer(g_aimbot_history_table.m_additional_data.m_backtracks, aim_data.m_backtrack_amount, 250)
    end

    local m_hitgroups = { "head", "chest", "stomach", "left arm", "right arm", "left leg", "right leg", "neck" }

    local m_handle_aim_hit = function(ev)
        local shot_id = ev.id

        local aim_data = m_aimbot_shot_tracklist[shot_id]

        if not aim_data then
            return
        end

        local hit_hitgroup, dealt_damage = ev.hitgroup, ev.damage
        local aimed_hitgroup, aimed_damage, mindmg, hitgroup_class = aim_data.m_hitgroup, aim_data.m_damage, aim_data.m_minimum_damage, m_helpers.get_hitgroup_class(hit_hitgroup) -- we're not using the pre-set hitgroup class due to mismatches

        local spread_angle = m_get_bullet_spread(shot_id)

        g_aimbot_history_table.m_hits.m_total_hits = g_aimbot_history_table.m_hits.m_total_hits + 1

        local hit_data_table =
            aim_data.m_safepoint and g_aimbot_history_table.m_hits.m_sp_hits or
            g_aimbot_history_table.m_hits.m_basic_hits

        hit_data_table.m_count, hit_data_table.m_per_hitbox[hitgroup_class] = hit_data_table.m_count + 1, hit_data_table.m_per_hitbox[hitgroup_class] + 1

        local is_damage_mismatch = dealt_damage < mindmg or dealt_damage < aimed_damage; local is_hitbox_mismatch = is_damage_mismatch and aimed_hitgroup ~= hit_hitgroup

        if dealt_damage > 100 or aim_data.m_lethal and not is_damage_mismatch then
            g_aimbot_history_table.m_hits.m_lethal_kills = g_aimbot_history_table.m_hits.m_lethal_kills + 1
        elseif aim_data.m_lethal and is_damage_mismatch then
            g_aimbot_history_table.m_hits.m_lethal_mismatches = g_aimbot_history_table.m_hits.m_lethal_mismatches + 1
        end

        if not entity_is_alive(ev.target) then
            g_aimbot_history_table.m_total_kills = g_aimbot_history_table.m_total_kills + 1

            if aim_data.m_zeus then
                g_aimbot_history_table.m_total_zeus_kills = g_aimbot_history_table.m_total_zeus_kills + 1
            end
        end

        if is_damage_mismatch or is_hitbox_mismatch then
            hit_data_table.m_mismatches = hit_data_table.m_mismatches + 1
            hit_data_table.m_mismatches_per_hitbox[aim_data.m_hitgroup_class] =
                hit_data_table.m_mismatches_per_hitbox[aim_data.m_hitgroup_class] + 1
        end

        if spread_angle then
            m_add_value_to_buffer(g_aimbot_history_table.m_additional_data.m_average_spread_angles, spread_angle, 250)
        end

        g_log_worker.add_event_to_log(
            ("[%d] Hit "):format(shot_id),
            { rgb = "green", text = entity_get_player_name(ev.target) }, "'s ",
            { rgb = "green", text = m_hitgroups[hit_hitgroup] }, " (targeted ",
            { rgb = "green", text = m_hitgroups[aim_data.m_hitgroup] }, ") for ",
            { rgb = "green", text = ("%d"):format(dealt_damage) }, " HP (",
            { rgb = "green", text = ("%d"):format(entity_get_prop(ev.target, "m_iHealth")) }, " HP remaining) (spread: ",
            { rgb = "green", text = ("%s"):format(spread_angle and ("%.3f°"):format(spread_angle) or "lost track of shot") }, ") - (pred. damage: ",
            { rgb = "green", text = ("%d"):format(aim_data.m_damage) }, " HP, minimum damage ",
            { rgb = "green", text = ("%d"):format(mindmg) }, " HP | Hit chance: ",
            { rgb = "green", text = ("%d%%"):format(ev.hit_chance) }, " | Bt: ",
            { rgb = "green", text = ("%d"):format(aim_data.m_backtrack_amount) }, "t | Safe point: ",
            { rgb = "green", text = tostring(aim_data.m_safepoint) }, ") (Flags: ",
            { rgb = "green", text = (#aim_data.m_flags == 0 and "None" or aim_data.m_flags) }, ")"
        )
    end

    local m_miss_data_tables =
        (function()
            local t = g_aimbot_history_table.m_misses
            return { ["spread"] = t.m_spread_misses, ["?"] = t.m_unknown_misses, ["prediction error"] = t.m_pred_misses, ["unregistered shot"] = t.m_unreg_misses, ["death"] = t.m_death_misses }
    end)()

    local m_full_data_processor_fn = function(tbl, aim_data)
        local hitgroup_class = aim_data.m_hitgroup_class

        if aim_data.m_safepoint then
            tbl.m_sp_count = tbl.m_sp_count + 1
            tbl.m_sp_per_hitbox[hitgroup_class] = tbl.m_sp_per_hitbox[hitgroup_class] + 1
        else
            tbl.m_count = tbl.m_count + 1
            tbl.m_per_hitbox[hitgroup_class] = tbl.m_per_hitbox[hitgroup_class] + 1
        end

        g_aimbot_history_table.m_misses.m_total_misses_by_hitbox[hitgroup_class] = g_aimbot_history_table.m_misses.m_total_misses_by_hitbox[hitgroup_class] + 1
    end

    local m_miss_data_processor_functions = {
        ["spread"] = m_full_data_processor_fn, ["?"] = m_full_data_processor_fn, ["prediction error"] = m_full_data_processor_fn, ["unregistered shot"] = function(tbl) tbl.m_count = tbl.m_count + 1 end,
        ["death"] = function(tbl)
            tbl.m_count = tbl.m_count + 1
            local is_local_dead = not entity_is_alive(entity_get_local_player())
            if is_local_dead then tbl.m_deaths.m_local_death = tbl.m_deaths.m_local_death + 1 else tbl.m_deaths.m_enemy_death = tbl.m_deaths.m_enemy_death + 1 end
        end
    }

    local m_handle_aim_miss = function(ev)
        local id = ev.id
        local aim_data = m_aimbot_shot_tracklist[id]

        if not aim_data then
            return
        end

        local miss_reason = ev.reason
        g_aimbot_history_table.m_misses.m_total_misses = g_aimbot_history_table.m_misses.m_total_misses + 1
        m_miss_data_processor_functions[miss_reason](m_miss_data_tables[miss_reason], aim_data)

        local spread_angle = m_get_bullet_spread(id)

        if spread_angle then
            m_add_value_to_buffer(g_aimbot_history_table.m_additional_data.m_average_spread_angles, spread_angle, 250)
        end

        g_log_worker.add_event_to_log(
            ("[%d] Missed "):format(id),
            { rgb = "red", text = entity_get_player_name(ev.target) }, "'s ",
            { rgb = "red", text = m_hitgroups[ev.hitgroup] }, " due to ",
            { rgb = "red", text = miss_reason }, " (spread: ",
            { rgb = "red", text = ("%s"):format(spread_angle and ("%.3f°"):format(spread_angle) or "lost track of shot") }, ")  - (pred. damage: ",
            { rgb = "red", text = ("%d"):format(aim_data.m_damage) }, " HP, minimum damage ",
            { rgb = "red", text = ("%d"):format(aim_data.m_minimum_damage) }, " HP | Hit chance: ",
            { rgb = "red", text = ("%d%%"):format(ev.hit_chance) }, " | Bt: ",
            { rgb = "red", text = ("%d"):format(aim_data.m_backtrack_amount) }, "t | Safe point: ",
            { rgb = "red", text = tostring(aim_data.m_safepoint) }, ") (Flags: ",
            { rgb = "red", text = (#aim_data.m_flags == 0 and "None" or aim_data.m_flags) }, ")"
        )
    end

    return { on_aim_fire = m_handle_aim_fire, on_bullet_impact = m_handle_bullet_impact, on_aim_hit = m_handle_aim_hit, on_aim_miss = m_handle_aim_miss, get_database_ptr = function() return g_aimbot_history_table end }
end)()

local g_container_manager = (function()
    local m_aimbot_data_ptr = g_aimbot_worker.get_database_ptr()
    local m_aimbot_dataset_processor = (function()
        local m_last_data_update_time = 0

        local m_aimbot_data_table = {
            m_ready = false,
            m_total_accuracy_rate = 0, m_accuracy_by_spec = { head = 0, body = 0, limbs = 0, sp = 0, lethal = 0 },
            m_total_shots = 0, m_total_kills = 0, m_total_headshots = 0, m_total_zeus = 0,

            m_average_hc = 0,
            m_average_spread = 0,
            m_average_shots_per_kill = 0,

            m_miss_reasons = {
                { m_refer_table = "m_unknown_misses", m_name = "CRR", m_full_name = "CORRECT", m_count = 0, m_percentage = 0 },
                { m_refer_table = "m_spread_misses", m_name = "SPR", m_full_name = "SPREAD", m_count = 0, m_percentage = 0 },
                { m_refer_table = "m_pred_misses", m_name = "PRED", m_full_name = "PRED", m_count = 0, m_percentage = 0 },
                { m_refer_table = "m_death_misses", m_name = "DTH", m_full_name = "DEATH", m_count = 0, m_percentage = 0 },
                { m_refer_table = "m_unreg_misses", m_name = "UNR", m_full_name = "UNREG", m_count = 0, m_percentage = 0 }
            }, m_most_common_reason = ""
        }

        local m_calculate_head_body_limb_accuracy = function()
            local total_shots_by_hitbox = m_aimbot_data_ptr.m_fired_shots_by_hitbox
            local tables = { m_aimbot_data_ptr.m_hits.m_basic_hits, m_aimbot_data_ptr.m_hits.m_sp_hits }
            local new_tbl = { head = 0, body = 0, limbs = 0 }
            for i = 1, 2 do
                local t = tables[i]

                new_tbl.head = new_tbl.head + t.m_per_hitbox.head; new_tbl.body = new_tbl.body + t.m_per_hitbox.body; new_tbl.limbs = new_tbl.limbs + t.m_per_hitbox.limbs
            end

            for k, v in pairs(new_tbl) do m_aimbot_data_table.m_accuracy_by_spec[k] = v / math_max(1, total_shots_by_hitbox[k]) end
        end

        local m_miss_table_compare = function(a, b)
            return a.m_count > b.m_count
        end

        local m_get_avg_from_table = function(tbl)
            local val = 0
            local cnt = #tbl
            for i = 1, cnt do
                val = val + tbl[i]
            end

            return val / math_max(1, cnt)
        end

        local m_calculate_miss_chart = function()
            local misses = m_aimbot_data_ptr.m_misses
            local total_misses = misses.m_total_misses

            for i = 1, 5 do
                local it = m_aimbot_data_table.m_miss_reasons[i]
                local corresponding_table = misses[it.m_refer_table]

                it.m_count = corresponding_table.m_count + (corresponding_table.m_sp_count or 0)
                it.m_percentage = it.m_count / math_max(1, total_misses)
            end

            table_sort(m_aimbot_data_table.m_miss_reasons, m_miss_table_compare)
        end

        local m_update_aim_data = function()
            -- here we calculate all the fancy stats and shit for the visuals - the stats for the console implementation are calculated separately (i'm black i know)

            if m_aimbot_data_ptr.m_total_fired_shots < 5 then
                m_aimbot_data_table.m_ready = false
                return
            end

            m_aimbot_data_table.m_total_accuracy_rate = m_aimbot_data_ptr.m_hits.m_total_hits / m_aimbot_data_ptr.m_total_fired_shots

            m_aimbot_data_table.m_accuracy_by_spec.sp = m_aimbot_data_ptr.m_hits.m_sp_hits.m_count / math_max(1, m_aimbot_data_ptr.m_total_fired_sp_shots)
            m_aimbot_data_table.m_accuracy_by_spec.lethal = m_aimbot_data_ptr.m_hits.m_lethal_kills / math_max(1, m_aimbot_data_ptr.m_total_lethal_shots)

            m_calculate_head_body_limb_accuracy()

            m_aimbot_data_table.m_total_shots, m_aimbot_data_table.m_total_kills, m_aimbot_data_table.m_total_zeus = m_aimbot_data_ptr.m_total_fired_shots, m_aimbot_data_ptr.m_total_kills, m_aimbot_data_ptr.m_total_zeus_kills
            m_aimbot_data_table.m_total_headshots = m_aimbot_data_ptr.m_hits.m_basic_hits.m_per_hitbox.head + m_aimbot_data_ptr.m_hits.m_sp_hits.m_per_hitbox.head

            m_calculate_miss_chart()

            if m_aimbot_data_table.m_total_accuracy_rate == 1 then
                m_aimbot_data_table.m_most_common_reason = "NONE"
            else
                m_aimbot_data_table.m_most_common_reason = m_aimbot_data_table.m_miss_reasons[1].m_full_name
            end

            m_aimbot_data_table.m_average_hc = m_get_avg_from_table(m_aimbot_data_ptr.m_additional_data.m_hitchances)
            m_aimbot_data_table.m_average_spread = m_get_avg_from_table(m_aimbot_data_ptr.m_additional_data.m_average_spread_angles)
            m_aimbot_data_table.m_average_shots_per_kill = m_aimbot_data_table.m_total_shots / math_max(1, m_aimbot_data_table.m_total_kills)

            m_aimbot_data_table.m_ready = true
        end

        local m_check_for_data_update = function()
            local time = globals_realtime()

            if time - m_last_data_update_time > 0.5 then
                client_delay_call(0.01, m_update_aim_data)
                m_last_data_update_time = time
            end
        end

        return { tick = m_check_for_data_update, get_data_ptr = function() return m_aimbot_data_table end }
    end)()

    local m_render_aim_data_ptr = m_aimbot_dataset_processor.get_data_ptr()

    local m_render_engine = (function()local a={}local b=function(c,d,e,f,g,h,i,j,k)renderer_rectangle(c+g,d,e-g*2,g,h,i,j,k)renderer_rectangle(c,d+g,g,f-g*2,h,i,j,k)renderer_rectangle(c+g,d+f-g,e-g*2,g,h,i,j,k)renderer_rectangle(c+e-g,d+g,g,f-g*2,h,i,j,k)renderer_rectangle(c+g,d+g,e-g*2,f-g*2,h,i,j,k)renderer_circle(c+g,d+g,h,i,j,k,g,180,0.25)renderer_circle(c+e-g,d+g,h,i,j,k,g,90,0.25)renderer_circle(c+g,d+f-g,h,i,j,k,g,270,0.25)renderer_circle(c+e-g,d+f-g,h,i,j,k,g,0,0.25)end;local l=function(c,d,e,f,g,h,i,j,k)renderer_rectangle(c,d+g,1,f-g*2+2,h,i,j,k)renderer_rectangle(c+e-1,d+g,1,f-g*2+1,h,i,j,k)renderer_rectangle(c+g,d,e-g*2,1,h,i,j,k)renderer_rectangle(c+g,d+f,e-g*2,1,h,i,j,k)renderer_circle_outline(c+g,d+g,h,i,j,k,g,180,0.25,1)renderer_circle_outline(c+e-g,d+g,h,i,j,k,g,270,0.25,1)renderer_circle_outline(c+g,d+f-g+1,h,i,j,k,g,90,0.25,1)renderer_circle_outline(c+e-g,d+f-g+1,h,i,j,k,g,0,0.25,1)end;local m=8;local n=45;local o=10;local p=function(c,d,e,f,g,h,i,j,k,q)renderer_rectangle(c+g,d,e-g*2,1,h,i,j,k)renderer_circle_outline(c+g,d+g,h,i,j,k,g,180,0.25,1)renderer_circle_outline(c+e-g,d+g,h,i,j,k,g,270,0.25,1)renderer_gradient(c,d+g,1,f-g*2,h,i,j,k,h,i,j,n,false)renderer_gradient(c+e-1,d+g,1,f-g*2,h,i,j,k,h,i,j,n,false)renderer_circle_outline(c+g,d+f-g,h,i,j,n,g,90,0.25,1)renderer_circle_outline(c+e-g,d+f-g,h,i,j,n,g,0,0.25,1)renderer_rectangle(c+g,d+f-1,e-g*2,1,h,i,j,n)for r=1,q do l(c-r,d-r,e+r*2,f+r*2,g,h,i,j,q-r)end end;local s,t,u,v=17,17,17,200;a.render_container=function(c,d,e,f,h,i,j,k,w)renderer_blur(c,d,e,f,100,100)b(c,d,e,f,m,s,t,u,v)p(c,d,e,f,m,h,i,j,k,o)if w then w(c+m,d+m,e-m*2,f-m*2)end end;a.render_glow_line=function(c,d,x,y,h,i,j,k,z,A,B,q)local C=vector(c,d,0)local D=vector(x,y,0)local E=({C:to(D):angles()})[2]for r=1,q do renderer_circle_outline(c,d,z,A,B,q-r,r,E+90,0.5,1)renderer_circle_outline(x,y,z,A,B,q-r,r,E-90,0.5,1)local F=vector(math_cos(math_rad(E+90)),math_sin(math_rad(E+90)),0):scaled(r*0.95)local G=vector(math_cos(math_rad(E-90)),math_sin(math_rad(E-90)),0):scaled(r*0.95)local H=F+C;local I=F+D;local J=G+C;local K=G+D;renderer_line(H.x,H.y,I.x,I.y,z,A,B,q-r)renderer_line(J.x,J.y,K.x,K.y,z,A,B,q-r)end;renderer_line(c,d,x,y,h,i,j,k)end;return a end)()

    local m_dpi_scale_reference = ui_reference("misc", "settings", "dpi scale")

    local m_scaling_multipliers = {
        ["100%"] = 1,
        ["125%"] = 1.25,
        ["150%"] = 1.5,
        ["175%"] = 1.75,
        ["200%"] = 2
    }

    local m_round_number = function(v)
        return math_floor(v + 0.5)
    end

    local m_display_sizes = {
        ["mini"] = (function()
            local m_container_callback_function = function(x, y, w, h)
                local current_dpi_scale = m_scaling_multipliers[ui_get(m_dpi_scale_reference)]
                local r, g, b = ui_get(g_accent_color_picker)

                local total_accuracy = m_render_aim_data_ptr.m_total_accuracy_rate

                renderer_text(m_round_number(x + w * 0.5), y, 255, 255, 255, 200, "dc-", 0, ("ACCURACY %.1f%%"):format(total_accuracy * 100))

                local bar_width = m_round_number(4 * current_dpi_scale); local inner_bar_width = bar_width - 2

                renderer_rectangle(m_round_number(x + w * 0.01), m_round_number(y + h * 0.1), bar_width, m_round_number(h * 0.9), 17, 17, 17, 255)
                renderer_rectangle(m_round_number(x + w * 0.01 + 1), m_round_number(m_round_number(y + h * 0.1) + 1 + h * 0.9 * (1 - total_accuracy)), inner_bar_width, m_round_number((h * 0.9 - 2) * total_accuracy), r, g, b, 200)
                renderer_rectangle(m_round_number(x + w * 0.01), m_round_number(m_round_number(y + h * 0.1) + 1 + h * 0.9 * (1 - total_accuracy)), bar_width, m_round_number(1 * current_dpi_scale), r, g, b, 255)

                do
                    local x, y, w, h = x + w * 0.15, y + h * 0.1, w * 0.85, h * 0.9

                    local m_rendered_strings = {
                        { "HEAD:", ( "%.1f%%" ):format( m_render_aim_data_ptr.m_accuracy_by_spec.head * 100 ) },
                        { "BODY:", ( "%.1f%%" ):format( m_render_aim_data_ptr.m_accuracy_by_spec.body * 100 ) },
                        { "SP:", ( "%.1f%%" ):format( m_render_aim_data_ptr.m_accuracy_by_spec.sp * 100 ) },
                        { "MOST MISSES", ( "%s" ):format( m_render_aim_data_ptr.m_most_common_reason ) }
                    }; local string_cnt = #m_rendered_strings

                    local allowed_slice = h / string_cnt

                    for i = 1, string_cnt do
                        local left, right = unpack(m_rendered_strings[i])

                        renderer_text(m_round_number(x), m_round_number(y + allowed_slice * (i - 1)), 255, 255, 255, 200, "d-", 0, left)
                        renderer_text(m_round_number(x + w * 0.95), m_round_number(y + allowed_slice * (i - 1)), 255, 255, 255, 200, "dr-", 0, right)
                    end
                end
            end

            return { m_display_width = 120, m_display_height = 65, m_last_width = 120, m_last_height = 65, m_container_callback = m_container_callback_function }
        end)(),
        ["full sized"] = (function()
            local m_chart_colors = {
                {0x4e, 0xa5, 0xd9},
                {0x2a, 0x44, 0x94},
                {0x44, 0xcf, 0xcb},
                {0x22, 0x48, 0x70},
                {0x12, 0x2c, 0x34}
            }

            local m_container_callback_function = function(x, y, w, h)
                local current_dpi_scale = m_scaling_multipliers[ui_get(m_dpi_scale_reference)]
                local r, g, b = ui_get(g_accent_color_picker)

                renderer_text(x + w * 0.5, y, 255, 255, 255, 200, "cd-", 0, "AIMBOT STATS")
                local text_size_y = ({ renderer_measure_text("d-", "AIMBOT STATS") })[2]

                renderer_text(x + w * 0.5, y + text_size_y, 255, 255, 255, 200, "cd-", 0, "TOTAL ACCURACY%")

                renderer_rectangle(m_round_number(x + w * 0.05), m_round_number(y + 16 * current_dpi_scale), m_round_number(w * 0.9), m_round_number(7 * current_dpi_scale), 17, 17, 17, 225)
                renderer_rectangle(m_round_number(x + w * 0.05 + 1), m_round_number(y + 17 * current_dpi_scale), m_round_number((w * 0.9 - 1) * m_render_aim_data_ptr.m_total_accuracy_rate), m_round_number(5 * current_dpi_scale), r, g, b, 255)
                renderer_rectangle(m_round_number(x + w * 0.05 + 1 + (w * 0.9 - 1) * m_render_aim_data_ptr.m_total_accuracy_rate), m_round_number(y + 16 * current_dpi_scale), 1, m_round_number(7 * current_dpi_scale), r, g, b, 255)
                renderer_text(m_round_number(x + w * 0.05 + 1 + (w * 0.9 - 1) * m_render_aim_data_ptr.m_total_accuracy_rate), m_round_number(y + 23 * current_dpi_scale), 255, 255, 255, 200, "cd-", 0, ("%d%%"):format(m_render_aim_data_ptr.m_total_accuracy_rate * 100))

                do
                    local left_bound_x, right_bound_x = x + w * 0.05, x + w * 0.55

                    local y = y + 27 * current_dpi_scale
                    local w = w * 0.4
                    local h = h - 27 * current_dpi_scale

                    do -- left
                        local x = left_bound_x

                        local accuracy_by_spec = m_render_aim_data_ptr.m_accuracy_by_spec

                        renderer_text(m_round_number(x), m_round_number(y), 255, 255, 255, 200, "d-", 0,
                            "HEAD: \nBODY: \nLIMBS: \nSP: \nLETHAL SHOT: "
                        )

                        local accuracy_str = ("%.1f%%\n%.1f%%\n%.1f%%\n%.1f%%\n%.1f%%"):format(
                            accuracy_by_spec.head * 100,
                            accuracy_by_spec.body * 100,
                            accuracy_by_spec.limbs * 100,
                            accuracy_by_spec.sp * 100,
                            accuracy_by_spec.lethal * 100
                        )

                        renderer_text(m_round_number(x + w * 0.95), m_round_number(y), 255, 255, 255, 200, "dr-", 0, accuracy_str)

                        local measurement_x = renderer_measure_text("d-", accuracy_str)

                        local y = y + h * 0.6

                        renderer_text(m_round_number(x), m_round_number(y), 255, 255, 255, 200, "d-", 0, "TOTAL SHOTS: \nTOTAL KILLS: \nTOTAL HS: \nTOTAL ZEUSES: ")
                        renderer_text(m_round_number(x + w * 0.95 - measurement_x), y, 255, 255, 255, 200, "d-", 0, ("%d\n%d\n%d\n%d"):format(m_render_aim_data_ptr.m_total_shots, m_render_aim_data_ptr.m_total_kills, m_render_aim_data_ptr.m_total_headshots, m_render_aim_data_ptr.m_total_zeus) )
                    end

                    do -- right
                        local x = right_bound_x
                        local target_circle_radius = h * 0.2

                        renderer_text(m_round_number(x + w * 0.5 - renderer_measure_text("d-", "MISS CHART:") * 0.5), m_round_number(y), 255, 255, 255, 200, "d-", 0, "MISS CHART:")

                        local circle_center_x, circle_center_y = m_round_number(x + w * 0.5), m_round_number(y + target_circle_radius + 14 * current_dpi_scale)
                        renderer_circle(circle_center_x, circle_center_y, 17, 17, 17, 225, m_round_number(target_circle_radius), 0, 1)

                        local ang_start = 270
                        local miss_reasons = m_render_aim_data_ptr.m_miss_reasons

                        local pie_chart_text_positions = {} -- prevent text clipping
                        local pie_chart_text_position_it = 1

                        for i = 1, #miss_reasons do
                            local t = miss_reasons[i]

                            local frac = t.m_percentage

                            if t.m_count == 0 then
                              goto continue
                            end

                            local r, g, b = unpack(m_chart_colors[i])
                            renderer_circle_outline(circle_center_x, circle_center_y, r, g, b, 225, m_round_number(target_circle_radius - 1), ang_start, t.m_percentage, m_round_number(25 * current_dpi_scale - 1))

                            if frac > 0.05 then
                                local ang = math_rad(ang_start) + (2 * math.pi * frac * 0.5)
                                local position_x, position_y = circle_center_x + math_cos(ang) * target_circle_radius * 0.6, circle_center_y + math_sin(ang) * target_circle_radius * 0.6

                                pie_chart_text_positions[pie_chart_text_position_it] = {
                                    m_name = t.m_name,
                                    m_frac = frac * 100,

                                    x = position_x,
                                    y = position_y
                                }

                                pie_chart_text_position_it = pie_chart_text_position_it + 1
                            end

                            ang_start = ang_start + math_deg((2 * math.pi * t.m_percentage))
                            ::continue::
                        end

                        for i = 1, #pie_chart_text_positions do
                            local v = pie_chart_text_positions[i]

                            renderer_text(m_round_number(v.x), m_round_number(v.y), 255, 255, 255, 225, (current_dpi_scale == 1 and "c-" or "c"), 0,
                                ("%s (%d%%)"):format(v.m_name, v.m_frac)
                            )
                        end

                        local y = y + h * 0.6

                        renderer_text(m_round_number(x), m_round_number(y), 255, 255, 255, 200, "d-", 0, "MOST COMMON: \nAVG HC: \nAVG SPREAD: \nAVG SHOTS/KILL: ")
                        renderer_text(m_round_number(x + w * 0.95), m_round_number(y), 255, 255, 255, 200, "dr-", 0,
                            ("%s\n%.1f%%\n%.2f°\n%.2f"):format(miss_reasons[1].m_full_name, m_render_aim_data_ptr.m_average_hc, m_render_aim_data_ptr.m_average_spread, m_render_aim_data_ptr.m_average_shots_per_kill)
                        )

                    end
                end
            end

            return { m_display_width = 300, m_display_height = 150, m_last_width = 300, m_last_height = 150, m_container_callback = m_container_callback_function }
        end)()
    }

    local m_render_position_funcs = {
        ["attached to player"] = (function()
            local m_inbetweening = (function()local a={}local b,c,d,e,f,g,h=math.pow,math_sin,math_cos,math.pi,math.sqrt,math.abs,math.asin;local function i(j,k,l,m)return l*j/m+k end;local function n(j,k,l,m)return l*b(j/m,2)+k end;local function o(j,k,l,m)j=j/m;return-l*j*(j-2)+k end;local function p(j,k,l,m)j=j/m*2;if j<1 then return l/2*b(j,2)+k end;return-l/2*((j-1)*(j-3)-1)+k end;local function q(j,k,l,m)if j<m/2 then return o(j*2,k,l/2,m)end;return n(j*2-m,k+l/2,l/2,m)end;local function r(j,k,l,m)return l*b(j/m,3)+k end;local function s(j,k,l,m)return l*(b(j/m-1,3)+1)+k end;local function t(j,k,l,m)j=j/m*2;if j<1 then return l/2*j*j*j+k end;j=j-2;return l/2*(j*j*j+2)+k end;local function u(j,k,l,m)if j<m/2 then return s(j*2,k,l/2,m)end;return r(j*2-m,k+l/2,l/2,m)end;local function v(j,k,l,m)return l*b(j/m,4)+k end;local function w(j,k,l,m)return-l*(b(j/m-1,4)-1)+k end;local function x(j,k,l,m)j=j/m*2;if j<1 then return l/2*b(j,4)+k end;return-l/2*(b(j-2,4)-2)+k end;local function y(j,k,l,m)if j<m/2 then return w(j*2,k,l/2,m)end;return v(j*2-m,k+l/2,l/2,m)end;local function z(j,k,l,m)return l*b(j/m,5)+k end;local function A(j,k,l,m)return l*(b(j/m-1,5)+1)+k end;local function B(j,k,l,m)j=j/m*2;if j<1 then return l/2*b(j,5)+k end;return l/2*(b(j-2,5)+2)+k end;local function C(j,k,l,m)if j<m/2 then return A(j*2,k,l/2,m)end;return z(j*2-m,k+l/2,l/2,m)end;local function D(j,k,l,m)return-l*d(j/m*e/2)+l+k end;local function E(j,k,l,m)return l*c(j/m*e/2)+k end;local function F(j,k,l,m)return-l/2*(d(e*j/m)-1)+k end;local function G(j,k,l,m)if j<m/2 then return E(j*2,k,l/2,m)end;return D(j*2-m,k+l/2,l/2,m)end;local function H(j,k,l,m)if j==0 then return k end;return l*b(2,10*(j/m-1))+k-l*0.001 end;local function I(j,k,l,m)if j==m then return k+l end;return l*1.001*(-b(2,-10*j/m)+1)+k end;local function J(j,k,l,m)if j==0 then return k end;if j==m then return k+l end;j=j/m*2;if j<1 then return l/2*b(2,10*(j-1))+k-l*0.0005 end;return l/2*1.0005*(-b(2,-10*(j-1))+2)+k end;local function K(j,k,l,m)if j<m/2 then return I(j*2,k,l/2,m)end;return H(j*2-m,k+l/2,l/2,m)end;local function L(j,k,l,m)return-l*(f(1-b(j/m,2))-1)+k end;local function M(j,k,l,m)return l*f(1-b(j/m-1,2))+k end;local function N(j,k,l,m)j=j/m*2;if j<1 then return-l/2*(f(1-j*j)-1)+k end;j=j-2;return l/2*(f(1-j*j)+1)+k end;local function O(j,k,l,m)if j<m/2 then return M(j*2,k,l/2,m)end;return L(j*2-m,k+l/2,l/2,m)end;local function P(Q,R,l,m)Q,R=Q or m*0.3,R or 0;if R<g(l)then return Q,l,Q/4 end;return Q,R,Q/(2*e)*h(l/R)end;local function S(j,k,l,m,R,Q)local T;if j==0 then return k end;j=j/m;if j==1 then return k+l end;Q,R,T=P(Q,R,l,m)j=j-1;return-(R*b(2,10*j)*c((j*m-T)*2*e/Q))+k end;local function U(j,k,l,m,R,Q)local T;if j==0 then return k end;j=j/m;if j==1 then return k+l end;Q,R,T=P(Q,R,l,m)return R*b(2,-10*j)*c((j*m-T)*2*e/Q)+l+k end;local function V(j,k,l,m,R,Q)local T;if j==0 then return k end;j=j/m*2;if j==2 then return k+l end;Q,R,T=P(Q,R,l,m)j=j-1;if j<0 then return-0.5*R*b(2,10*j)*c((j*m-T)*2*e/Q)+k end;return R*b(2,-10*j)*c((j*m-T)*2*e/Q)*0.5+l+k end;local function W(j,k,l,m,R,Q)if j<m/2 then return U(j*2,k,l/2,m,R,Q)end;return S(j*2-m,k+l/2,l/2,m,R,Q)end;local function X(j,k,l,m,T)T=T or 1.70158;j=j/m;return l*j*j*((T+1)*j-T)+k end;local function Y(j,k,l,m,T)T=T or 1.70158;j=j/m-1;return l*(j*j*((T+1)*j+T)+1)+k end;local function Z(j,k,l,m,T)T=(T or 1.70158)*1.525;j=j/m*2;if j<1 then return l/2*j*j*((T+1)*j-T)+k end;j=j-2;return l/2*(j*j*((T+1)*j+T)+2)+k end;local function _(j,k,l,m,T)if j<m/2 then return Y(j*2,k,l/2,m,T)end;return X(j*2-m,k+l/2,l/2,m,T)end;local function a0(j,k,l,m)j=j/m;if j<1/2.75 then return l*7.5625*j*j+k end;if j<2/2.75 then j=j-1.5/2.75;return l*(7.5625*j*j+0.75)+k elseif j<2.5/2.75 then j=j-2.25/2.75;return l*(7.5625*j*j+0.9375)+k end;j=j-2.625/2.75;return l*(7.5625*j*j+0.984375)+k end;local function a1(j,k,l,m)return l-a0(m-j,0,l,m)+k end;local function a2(j,k,l,m)if j<m/2 then return a1(j*2,0,l,m)*0.5+k end;return a0(j*2-m,0,l,m)*0.5+l*.5+k end;local function a3(j,k,l,m)if j<m/2 then return a0(j*2,k,l/2,m)end;return a1(j*2-m,k+l/2,l/2,m)end;a.easing={linear=i,inQuad=n,outQuad=o,inOutQuad=p,outInQuad=q,inCubic=r,outCubic=s,inOutCubic=t,outInCubic=u,inQuart=v,outQuart=w,inOutQuart=x,outInQuart=y,inQuint=z,outQuint=A,inOutQuint=B,outInQuint=C,inSine=D,outSine=E,inOutSine=F,outInSine=G,inExpo=H,outExpo=I,inOutExpo=J,outInExpo=K,inCirc=L,outCirc=M,inOutCirc=N,outInCirc=O,inElastic=S,outElastic=U,inOutElastic=V,outInElastic=W,inBack=X,outBack=Y,inOutBack=Z,outInBack=_,inBounce=a1,outBounce=a0,inOutBounce=a2,outInBounce=a3}local function a4(a5,a6,a7)a7=a7 or a6;local a8=getmetatable(a6)if a8 and getmetatable(a5)==nil then setmetatable(a5,a8)end;for a9,aa in pairs(a6)do if type(aa)=="table"then a5[a9]=a4({},aa,a7[a9])else a5[a9]=a7[a9]end end;return a5 end;local function ab(ac,ad,ae)ae=ae or{}local af,ag;for a9,ah in pairs(ad)do af,ag=type(ah),a4({},ae)table_insert(ag,tostring(a9))if af=="number"then assert(type(ac[a9])=="number","Parameter '"..table_concat(ag,"/").."' is missing from subject or isn't a number")elseif af=="table"then ab(ac[a9],ah,ag)else assert(af=="number","Parameter '"..table_concat(ag,"/").."' must be a number or table of numbers")end end end;local function ai(aj,ac,ad,ak)assert(type(aj)=="number"and aj>0,"duration must be a positive number. Was "..tostring(aj))local al=type(ac)assert(al=="table"or al=="userdata","subject must be a table or userdata. Was "..tostring(ac))assert(type(ad)=="table","target must be a table. Was "..tostring(ad))assert(type(ak)=="function","easing must be a function. Was "..tostring(ak))ab(ac,ad)end;local function am(ak)ak=ak or"linear"if type(ak)=="string"then local an=ak;ak=a.easing[an]if type(ak)~="function"then error("The easing function name '"..an.."' is invalid")end end;return ak end;local function ao(ac,ad,ap,aq,aj,ak)local j,k,l,m;for a9,aa in pairs(ad)do if type(aa)=="table"then ao(ac[a9],aa,ap[a9],aq,aj,ak)else j,k,l,m=aq,ap[a9],aa-ap[a9],aj;ac[a9]=ak(j,k,l,m)end end end;local ar={}local as={__index=ar}function ar:set(aq)assert(type(aq)=="number","clock must be a positive number or 0")self.initial=self.initial or a4({},self.target,self.subject)self.clock=aq;if self.clock<=0 then self.clock=0;a4(self.subject,self.initial)elseif self.clock>=self.duration then self.clock=self.duration;a4(self.subject,self.target)else ao(self.subject,self.target,self.initial,self.clock,self.duration,self.easing)end;return self.clock>=self.duration end;function ar:reset()return self:set(0)end;function ar:update(at)assert(type(at)=="number","dt must be a number")return self:set(self.clock+at)end;function a.new(aj,ac,ad,ak)ak=am(ak)ai(aj,ac,ad,ak)return setmetatable({duration=aj,subject=ac,target=ad,easing=ak,clock=0},as)end;return a end)()

            local m_inbetweening_worker
            local m_xy = {5, 800}
            local m_default_position = { 25, ({client_screen_size()})[2] * 0.55 }

            local icliententitylist_get_client_entity = vtable_bind("client.dll", "VClientEntityList003", 3, "void*(__thiscall*)(void*, int)")

            local c_weapon_get_muzzle_index_firstperson = vtable_thunk(468, "int(__thiscall*)(void*, void*)")
            local c_entity_get_attachment = vtable_thunk(84, "bool(__thiscall*)(void*, int, Vector&)")

            local m_thirdperson_reference, m_thirdperson_key_reference = ui_reference("visuals", "effects", "force third person (alive)")

            local m_get_muzzle_position = function(me)
                if entity_get_prop(me, "m_bIsScoped") == 1 and not ui_get(g_statistics_attach_while_scoped) then
                    return false
                end

                local active_weapon = entity_get_player_weapon(me)
                local viewmodel = entity_get_prop(me, "m_hViewModel[0]")

                if not active_weapon or not viewmodel then
                    return false
                end

                local weapon_ptr, viewmodel_ptr = icliententitylist_get_client_entity(active_weapon), icliententitylist_get_client_entity(viewmodel)

                if not weapon_ptr or not viewmodel_ptr then
                    return false
                end

                local ret = vector(0, 0, 0)

                local muzzle_attachment_idx = c_weapon_get_muzzle_index_firstperson(weapon_ptr, viewmodel_ptr)
                local succeeded = c_entity_get_attachment(viewmodel_ptr, muzzle_attachment_idx, ret)

                return succeeded, ret

            end

            local m_inversion_progress = 0
            -- I know I should use easing for this
            -- however, I will not

            return function()
                local current_display_size = m_display_sizes[ui_get(g_statistics_style)]

                if m_inbetweening_worker then
                    m_inbetweening_worker:update(globals_absoluteframetime() * 1.5)
                end

                local me = entity_get_local_player()

                if not me or not entity_is_alive(me) then
                    m_inbetweening_worker = m_inbetweening.new(0.75, m_xy, m_default_position, "linear")

                    return m_xy[1], m_xy[2]
                end

                local world_origin_position

                local is_third_person = ui_get(m_thirdperson_reference) and ui_get(m_thirdperson_key_reference)

                if not is_third_person then
                    local success, position = m_get_muzzle_position(me)

                    if success then
                        world_origin_position = position
                    end
                else
                    world_origin_position = vector(entity_hitbox_position(me, 6))
                end

                local start_position_x, start_position_y
                local position_target = m_default_position
                local should_draw_glowline = false

                local should_invert = false

                if world_origin_position then
                    should_draw_glowline = true

                    local w2s_x, w2s_y = renderer_world_to_screen(world_origin_position:unpack())

                    if w2s_x and w2s_y then
                        local m_offset_x_firstperson, m_offset_y_firstperson = ui_get(g_statistics_offset_x_firstperson), ui_get(g_statistics_offset_y_firstperson) * -1
                        local m_offset_x_thirdperson, m_offset_y_thirdperson = ui_get(g_statistics_offset_x_thirdperson), ui_get(g_statistics_offset_y_thirdperson) * -1

                        local render_offset_x, render_offset_y = unpack((is_third_person and { m_offset_x_thirdperson, m_offset_y_thirdperson } or { m_offset_x_firstperson, m_offset_y_firstperson }))

                        should_invert = m_xy[1] < w2s_x

                        if should_invert then
                            m_inversion_progress = math_min(1, m_inversion_progress + globals_absoluteframetime() * 6)
                        else
                            m_inversion_progress = math_max(0, m_inversion_progress - globals_absoluteframetime() * 6)
                        end

                        local current_scale = m_scaling_multipliers[ui_get(m_dpi_scale_reference)]
                        render_offset_x, render_offset_y = render_offset_x * current_scale, render_offset_y * current_scale

                        position_target = { w2s_x + render_offset_x, w2s_y + render_offset_y }
                        start_position_x, start_position_y = w2s_x, w2s_y
                    end
                end

                m_inbetweening_worker = m_inbetweening.new(0.75, m_xy, position_target, "linear")

                if should_draw_glowline then
                    local r, g, b = ui_get(g_accent_color_picker)
                    m_render_engine.render_glow_line(start_position_x, start_position_y, m_xy[1], m_xy[2], 255, 255, 255, 45, r, g, b, 8)
                end

                return (should_draw_glowline and m_xy[1] - current_display_size.m_last_width * m_inversion_progress or m_xy[1]), m_xy[2] - current_display_size.m_last_height * 0.5
            end
        end)(),
        ["draggable"] = (function()
            local m_drag_start_x, m_drag_start_y, m_dragging = 0, 0, false

            return function()
                local render_table_ptr = m_aimbot_data_ptr.m_renderer_data

                local mouse_down, mouse_x, mouse_y = client_key_state(1), ui_mouse_position()

                local display_sizes = m_display_sizes[ui_get(g_statistics_style)]

                local can_drag = mouse_down and not m_dragging and mouse_x > render_table_ptr.m_draggable_position_x and mouse_x < render_table_ptr.m_draggable_position_x + display_sizes.m_last_width and mouse_y > render_table_ptr.m_draggable_position_y and mouse_y < render_table_ptr.m_draggable_position_y + display_sizes.m_last_height

                -- i know this drag is shit and doesn't account for overlapping objects
                -- HOWEVER, i do not give a shit and cia operatives will taste the wrath of Allah
                -- fuck cia

                if can_drag then
                    m_dragging, m_drag_start_x, m_drag_start_y = true, mouse_x - render_table_ptr.m_draggable_position_x, mouse_y - render_table_ptr.m_draggable_position_y
                elseif mouse_down and m_dragging then
                    render_table_ptr.m_draggable_position_x, render_table_ptr.m_draggable_position_y = mouse_x - m_drag_start_x, mouse_y - m_drag_start_y
                else
                    m_dragging = false
                end

                return render_table_ptr.m_draggable_position_x, render_table_ptr.m_draggable_position_y
            end
        end)(),
        ["-"] = function() end
    }

    local m_draw_container = function(x, y)
        local r, g, b = ui_get(g_accent_color_picker)
        local display_mode = m_display_sizes[ui_get(g_statistics_style)]
        local scaling_multiplier = m_scaling_multipliers[ui_get(m_dpi_scale_reference)]

        local w, h = display_mode.m_display_width * scaling_multiplier, display_mode.m_display_height * scaling_multiplier
        display_mode.m_last_width, display_mode.m_last_height = w, h

        m_render_engine.render_container(
            m_round_number(x), m_round_number(y), m_round_number(w), m_round_number(h), r, g, b, 255, display_mode.m_container_callback
        )
    end

    local m_paint = function()
        m_aimbot_dataset_processor.tick()

        if not m_render_aim_data_ptr.m_ready then
            return
        end

        local current_container_selection = ui_get(g_statistics_display)
        local render_position_x, render_position_y = m_render_position_funcs[current_container_selection]()

        if not render_position_x then
            return
        end

        m_draw_container(render_position_x, render_position_y)
    end

    return { on_paint = m_paint }
end)()

local g_console_manager = (function()
    local m_aimbot_data_ptr = g_aimbot_worker.get_database_ptr()

    local m_command_handlers = {
        ["show"] = (function()
            local m_get_average = function(t)
                local c = #t
                local v = 0
                for i = 1, c do
                    v = v + t[i]
                end
                return v / math_max(1, c)
            end

            local show_handlers = {
                ["hits"] = function()
                    local total_shots, total_sp_shots = m_aimbot_data_ptr.m_total_fired_shots, m_aimbot_data_ptr.m_total_fired_sp_shots

                    local total_shots_safe, total_sp_shots_safe = math_max(1, total_shots), math_max(1, total_sp_shots)

                    local hits_table = m_aimbot_data_ptr.m_hits

                    local normal_hits_table = hits_table.m_basic_hits
                    local sp_hits_table = hits_table.m_sp_hits

                    local rows, headings = {
                        { "Hits",
                            ( "%d (Safe point: %d)" ):format( normal_hits_table.m_per_hitbox.head, sp_hits_table.m_per_hitbox.head ),
                            ( "%d (Safe point: %d)" ):format( normal_hits_table.m_per_hitbox.body, sp_hits_table.m_per_hitbox.body ),
                            ( "%d (Safe point: %d)" ):format( normal_hits_table.m_per_hitbox.limbs, sp_hits_table.m_per_hitbox.limbs ),
                            ( "%d (Safe point: %d)" ):format( normal_hits_table.m_count, sp_hits_table.m_count )
                        },

                        { "Aim rate",
                            ( "%.1f%% (Safe point: %.1f%%)" ):format( (m_aimbot_data_ptr.m_fired_shots_by_hitbox.head / total_shots_safe) * 100, (m_aimbot_data_ptr.m_sp_fired_shots_by_hitbox.head / total_shots_safe) * 100 ),
                            ( "%.1f%% (Safe point: %.1f%%)" ):format( (m_aimbot_data_ptr.m_fired_shots_by_hitbox.body / total_shots_safe) * 100,  (m_aimbot_data_ptr.m_sp_fired_shots_by_hitbox.body / total_shots_safe) * 100 ),
                            ( "%.1f%% (Safe point: %.1f%%)" ):format( (m_aimbot_data_ptr.m_fired_shots_by_hitbox.limbs / total_shots_safe) * 100, (m_aimbot_data_ptr.m_sp_fired_shots_by_hitbox.limbs / total_shots_safe) * 100 ),
                        "N/A" },

                        { "Accuracy",
                            ( "%.1f%% (Safe point: %.1f%%)" ):format( (normal_hits_table.m_per_hitbox.head / math_max(1, m_aimbot_data_ptr.m_fired_shots_by_hitbox.head)) * 100,  (sp_hits_table.m_per_hitbox.head / math_max(1, m_aimbot_data_ptr.m_sp_fired_shots_by_hitbox.head)) * 100 ),
                            ( "%.1f%% (Safe point: %.1f%%)" ):format( (normal_hits_table.m_per_hitbox.body / math_max(1, m_aimbot_data_ptr.m_fired_shots_by_hitbox.body)) * 100,  (sp_hits_table.m_per_hitbox.body / math_max(1, m_aimbot_data_ptr.m_sp_fired_shots_by_hitbox.body)) * 100 ),
                            ( "%.1f%% (Safe point: %.1f%%)" ):format( (normal_hits_table.m_per_hitbox.limbs / math_max(1, m_aimbot_data_ptr.m_fired_shots_by_hitbox.limbs)) * 100, (sp_hits_table.m_per_hitbox.limbs / math_max(1, m_aimbot_data_ptr.m_sp_fired_shots_by_hitbox.limbs)) * 100 ),
                            ( "%.1f%% (Safe point: %.1f%%)" ):format( (normal_hits_table.m_count / math_max(1, total_shots - total_sp_shots)) * 100, (sp_hits_table.m_count / total_sp_shots_safe) * 100 )
                        },

                        { "Mismatches",
                            ( "%d (%.1f%%) (Safe point: %d (%.1f%%) )" ):format(
                                normal_hits_table.m_mismatches_per_hitbox.head, (normal_hits_table.m_mismatches_per_hitbox.head / math_max(1, hits_table.m_total_hits)) * 100,
                                sp_hits_table.m_mismatches_per_hitbox.head, (sp_hits_table.m_mismatches_per_hitbox.head / math_max(1, hits_table.m_total_hits)) * 100
                            ),
                            ( "%d (%.1f%%) (Safe point: %d (%.1f%%) )" ):format(
                                normal_hits_table.m_mismatches_per_hitbox.body, (normal_hits_table.m_mismatches_per_hitbox.body / math_max(1, hits_table.m_total_hits)) * 100,
                                sp_hits_table.m_mismatches_per_hitbox.body, (sp_hits_table.m_mismatches_per_hitbox.body / math_max(1, hits_table.m_total_hits)) * 100
                            ),
                            ( "%d (%.1f%%) (Safe point: %d (%.1f%%) )" ):format(
                                normal_hits_table.m_mismatches_per_hitbox.limbs, (normal_hits_table.m_mismatches_per_hitbox.limbs / math_max(1, hits_table.m_total_hits)) * 100,
                                sp_hits_table.m_mismatches_per_hitbox.limbs, (sp_hits_table.m_mismatches_per_hitbox.limbs / math_max(1, hits_table.m_total_hits)) * 100
                            ),
                            ( "%d (%.1f%%) (Safe point: %d (%.1f%%) )" ):format(
                                normal_hits_table.m_mismatches, (normal_hits_table.m_mismatches / math_max(1, hits_table.m_total_hits)) * 100,
                                sp_hits_table.m_mismatches, (sp_hits_table.m_mismatches / math_max(1, hits_table.m_total_hits)) * 100
                            )
                        }
                    }, { "Case", "Head", "Body", "Limbs", "Total" }

                    client_log("\n", table_gen(rows, headings, { style = "Unicode (Single Line)" }))
                    client_log( ("Total attempted lethal shots %d (%.1f%% of total shots), successful lethal shots %d (%.1f%%, mismatches %.1f%%)"):format(
                        m_aimbot_data_ptr.m_total_lethal_shots,
                        (m_aimbot_data_ptr.m_total_lethal_shots / total_shots_safe) * 100,
                        hits_table.m_lethal_kills,
                        (hits_table.m_lethal_kills / math_max(1, hits_table.m_total_hits)) * 100,
                        (hits_table.m_lethal_mismatches / math_max(1, m_aimbot_data_ptr.m_total_lethal_shots)) * 100
                    ) )
                    client_log( ("Average lag compensation tick count: %dt"):format(
                        m_get_average(m_aimbot_data_ptr.m_additional_data.m_backtracks) -- i know i'm repeating myself, cope
                    ) )
                    client_log( ("Average aimbot hit chance: %.2f%%"):format(
                        m_get_average(m_aimbot_data_ptr.m_additional_data.m_hitchances)
                    ) )
                    client_log( ("Average bullets needed to kill an enemy: %.2f shots"):format(
                        m_aimbot_data_ptr.m_total_kills / total_shots_safe
                    ) )
                end,

                ["misses"] = function()
                    local total_shots = m_aimbot_data_ptr.m_total_fired_shots; local total_shots_safe = math_max(1, total_shots)

                    local misses_table = m_aimbot_data_ptr.m_misses

                    local total_misses, total_misses_safe = misses_table.m_total_misses, math_max(1, misses_table.m_total_misses)

                    client_log( ("Total misses: %d (Miss rate: %.1f%%)"):format(
                        misses_table.m_total_misses,
                        (total_misses / total_shots_safe) * 100
                    ) )

                    local total_head_safe, total_body_safe, total_limbs_safe = math_max(1, misses_table.m_total_misses_by_hitbox.head), math_max(1, misses_table.m_total_misses_by_hitbox.body), math_max(1, misses_table.m_total_misses_by_hitbox.limbs)

                    local m_build_miss_reason_table = function(name, t)
                        return {
                            name,
                            ( "%d misses (%.1f%%), safe point: %d (%.1f%%)" ):format(t.m_per_hitbox.head, (t.m_per_hitbox.head / total_head_safe) * 100, t.m_sp_per_hitbox.head, ( t.m_sp_per_hitbox.head / total_head_safe ) * 100),
                            ( "%d misses (%.1f%%), safe point: %d (%.1f%%)" ):format(t.m_per_hitbox.body, (t.m_per_hitbox.body / total_body_safe) * 100, t.m_sp_per_hitbox.body, ( t.m_sp_per_hitbox.body / total_body_safe ) * 100),
                            ( "%d misses (%.1f%%), safe point: %d (%.1f%%)" ):format(t.m_per_hitbox.limbs, (t.m_per_hitbox.limbs / total_limbs_safe) * 100, t.m_sp_per_hitbox.limbs, ( t.m_sp_per_hitbox.limbs / total_limbs_safe ) * 100),
                            ( "%d misses (%.1f%%), safe point: %d (%.1f%%)" ):format(t.m_count, (t.m_count / total_misses_safe) * 100, t.m_sp_count, (t.m_sp_count / total_misses_safe) * 100)
                        }
                    end

                    local rows, headings = {
                        m_build_miss_reason_table("Spread", misses_table.m_spread_misses),
                        m_build_miss_reason_table("?/Resolver", misses_table.m_unknown_misses),
                        m_build_miss_reason_table("Prediction error", misses_table.m_pred_misses)
                    }, { "Case", "Head", "Body", "Limbs", "Total" }

                    local str_out = table_gen(rows, headings, {
                        style = "Unicode (Single Line)"
                    })

                    client_log("\n", str_out)

                    local death_misses = misses_table.m_death_misses

                    client_log( ("Death misses: %d (%.1f%%), of which %.1f%% were local player deaths and %.1f%% were enemy deaths."):format(
                        death_misses.m_count, (death_misses.m_count / total_misses_safe) * 100,

                        (death_misses.m_deaths.m_local_death / math_max(1, death_misses.m_count)) * 100,
                        (death_misses.m_deaths.m_enemy_death / math_max(1, death_misses.m_count)) * 100
                    ) )

                    client_log( ("Unregistered shot misses: %d (%.1f%%)"):format(
                        misses_table.m_unreg_misses.m_count, (misses_table.m_unreg_misses.m_count / total_misses_safe) * 100
                    ) )

                    client_log( ("Average spread angle: %.3f°"):format(
                        m_get_average(m_aimbot_data_ptr.m_additional_data.m_average_spread_angles)
                    ) )
                end
            }

            return function(arg)
                if arg == "all" then
                    show_handlers["hits"]()

                    client_color_log(255, 255, 255, "\n\n")

                    show_handlers["misses"]()

                    return
                end

                if arg and show_handlers[arg] then
                    show_handlers[arg]()
                end
            end
        end)(),

        ["clear_data"] = function()
            client_log("[logger] erasing data...")

            g_database_accessor.erase_data()
        end,

        ["json"] = function()
            local json_representation = json_stringify(m_aimbot_data_ptr)

            clipboard.set(json_representation)

            client_log("[logger] json deposited to clipboard")
        end
    }

    local m_handle_console_input = function(input)
        local match_command, match_arg = input:match("%.logger%s(%g+)%s*(%g*)")

        if match_command and m_command_handlers[match_command] then
            client_delay_call(0.01, m_command_handlers[match_command], match_arg)
            return true
        end
    end

    return {
       on_console_input = m_handle_console_input
    }
end)()

local g_paint_callback = function()
    g_container_manager.on_paint()
    g_log_worker.on_paint()
end

local g_handle_visibility = function()
    local is_enabled = ui_get(g_master_switch) -- not always called from g_ui_callback

    ui_set_visible(g_event_logger, is_enabled)

    local statistics_display_selection = ui_get(g_statistics_display)

    ui_set_visible(g_statistics_display, is_enabled)
    ui_set_visible(g_statistics_style, is_enabled and statistics_display_selection ~= "-")

    local is_attached_to_player = statistics_display_selection == "attached to player"

    ui_set_visible(g_statistics_attach_while_scoped, is_enabled and is_attached_to_player)

    ui_set_visible(g_statistics_offset_label_firstperson, is_enabled and is_attached_to_player)
    ui_set_visible(g_statistics_offset_x_firstperson, is_enabled and is_attached_to_player)
    ui_set_visible(g_statistics_offset_y_firstperson, is_enabled and is_attached_to_player)

    ui_set_visible(g_statistics_offset_label_thirdperson, is_enabled and is_attached_to_player)
    ui_set_visible(g_statistics_offset_x_thirdperson, is_enabled and is_attached_to_player)
    ui_set_visible(g_statistics_offset_y_thirdperson, is_enabled and is_attached_to_player)

    ui_set_visible(g_accent_color_picker, is_enabled)
    ui_set_visible(g_erase_statistics, is_enabled)
end

local g_ui_callback = function()
    local is_enabled = ui_get(g_master_switch)

    g_handle_visibility()

    local fn = is_enabled and client_set_event_callback or client_unset_event_callback

    fn("aim_fire", g_aimbot_worker.on_aim_fire)
    fn("aim_hit", g_aimbot_worker.on_aim_hit)
    fn("aim_miss", g_aimbot_worker.on_aim_miss)

    fn("bullet_impact", g_aimbot_worker.on_bullet_impact)
    fn("console_input", g_console_manager.on_console_input)
    fn("paint", g_paint_callback)
end

for _, v in pairs({
    g_event_logger, g_statistics_display, g_statistics_style,
    g_statistics_attach_while_scoped,
    g_statistics_offset_label_firstperson, g_statistics_offset_x_firstperson, g_statistics_offset_y_firstperson, g_accent_color_picker }) do
    ui_set_callback(v, g_handle_visibility)
end

g_ui_callback()

ui_set_callback(g_master_switch, g_ui_callback)
