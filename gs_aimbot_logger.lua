local bit = require 'bit'
local ffi = require 'ffi'
local vector = require 'vector'

-- local variables for API functions. any changes to the line below will be lost on re-generation
local client_fire_event, client_error_log, client_unix_time, entity_get_esp_data, entity_get_game_rules, globals_tickinterval, ipairs, bit_band, bit_lshift, client_real_latency, client_get_cvar, client_color_log, client_delay_call, client_eye_position, client_key_state, client_log, client_screen_size, client_set_event_callback, client_unset_event_callback, client_userid_to_entindex, database_read, database_write, entity_get_local_player, entity_get_player_name, entity_get_player_weapon, entity_get_prop, entity_hitbox_position, entity_is_alive, globals_chokedcommands, globals_lastoutgoingcommand, globals_realtime, globals_tickcount, plist_get, renderer_measure_text, renderer_text, require, table_concat, table_remove, ui_get, ui_new_button, ui_new_checkbox, ui_new_color_picker, ui_new_combobox, ui_new_multiselect, pairs, error, globals_absoluteframetime, json_stringify, math_cos, math_deg, math_floor, math_max, math_rad, math_sin, renderer_blur, renderer_circle, renderer_circle_outline, renderer_gradient, renderer_line, renderer_rectangle, renderer_world_to_screen, table_insert, table_sort, tostring, getmetatable, setmetatable, type, assert, ui_mouse_position, ui_reference, ui_set, ui_set_callback,
      ui_set_visible, unpack, ui_new_slider, ui_new_label, vtable_bind, vtable_thunk, math_min, math_abs = client.fire_event, client.error_log, client.unix_time, entity.get_esp_data, entity.get_game_rules, globals.tickinterval, ipairs, bit.band, bit.lshift, client.real_latency, client.get_cvar, client.color_log, client.delay_call, client.eye_position, client.key_state, client.log, client.screen_size, client.set_event_callback, client.unset_event_callback, client.userid_to_entindex, database.read, database.write, entity.get_local_player, entity.get_player_name, entity.get_player_weapon, entity.get_prop, entity.hitbox_position, entity.is_alive, globals.chokedcommands, globals.lastoutgoingcommand, globals.realtime, globals.tickcount, plist.get, renderer.measure_text, renderer.text, require, table.concat, table.remove, ui.get, ui.new_button, ui.new_checkbox, ui.new_color_picker, ui.new_combobox, ui.new_multiselect, pairs, error, globals.absoluteframetime, json.stringify, math.cos, math.deg, math.floor, math.max, math.rad, math.sin, renderer.blur, renderer.circle, renderer.circle_outline, renderer.gradient, renderer.line, renderer.rectangle, renderer.world_to_screen, table.insert, table.sort, tostring,
                                                                                                           getmetatable, setmetatable, type, assert, ui.mouse_position, ui.reference, ui.set, ui.set_callback, ui.set_visible, unpack, ui.new_slider, ui.new_label, vtable_bind, vtable_thunk, math.min, math.abs

local clipboard = require 'gamesense/clipboard'
local csgo_weapons = require 'gamesense/csgo_weapons'
local easing = require 'gamesense/easing'
local pretty_json = require 'gamesense/pretty_json'
local table_gen = require 'gamesense/table_gen'

local G_SCRIPT_VERSION = 'v1.0.3' -- used to recreate database

local g_database_accessor = (function()
	local m_table, m_default_table, m_db_key = {}, {}, ''
	local m_set_default_table = function( t ) m_default_table = t end
	local m_set_db_key = function( key ) m_db_key = key end
	local m_read_table = function()
		local t = database_read( m_db_key )
		m_table = t or m_default_table
		return m_table
	end
	local m_erase_data = function()
		database_write( m_db_key, nil )
		m_table = m_default_table
		client_delay_call( 0.05, client.reload_active_scripts )
	end
	client_set_event_callback( 'shutdown', function() database_write( m_db_key, m_table ) end )
	return { set_default_table = m_set_default_table, set_db_key = m_set_db_key, read_table = m_read_table, erase_data = m_erase_data }
end)()

g_database_accessor.set_default_table { m_shot_array = {}, m_renderer_data = { m_draggable_position_x = 15, m_draggable_position_y = ({ client_screen_size() })[2] * 0.55 } }

g_database_accessor.set_db_key( ('gs-shot-data-stats-%s'):format( G_SCRIPT_VERSION ) )

local g_master_switch = ui_new_checkbox( 'lua', 'b', 'Aimbot shot collector' )
local g_event_logger = ui_new_multiselect( 'lua', 'b', 'Send aimbot events to', { 'Display', 'Console' } )
local g_statistics_display = ui_new_combobox( 'lua', 'b', 'Display statistics', { '-', 'Attached to player', 'Draggable' } )
local g_accent_color_picker = ui_new_color_picker( 'lua', 'b', 'Accent color picker', 170, 0, 125, 255 )
local g_statistics_style = ui_new_combobox( 'lua', 'b', '\nstatistics style', { 'Mini', 'Full-sized' } )
local g_statistics_attach_while_scoped = ui_new_checkbox( 'lua', 'b', 'Attach statistics while scoped' )
local g_statistics_offset_label_firstperson = ui_new_label( 'lua', 'b', 'Offsets (first person)' )
local g_statistics_offset_x_firstperson, g_statistics_offset_y_firstperson = ui_new_slider( 'lua', 'b', '\nstat_offset_x_fp', -200, 200, 0, false ), ui_new_slider( 'lua', 'b', '\nstat_offset_y_fp', -200, 200, 100, false )
local g_statistics_offset_label_thirdperson = ui_new_label( 'lua', 'b', 'Offsets (third person)' )
local g_statistics_offset_x_thirdperson, g_statistics_offset_y_thirdperson = ui_new_slider( 'lua', 'b', '\nstat_offset_x_tp', -200, 200, 0, false ), ui_new_slider( 'lua', 'b', '\nstat_offset_y_tp', -200, 200, 100, false )
local g_erase_statistics = ui_new_button( 'lua', 'b', 'Erase shot stats', g_database_accessor.erase_data )

local g_contains = function( t, val )
	for k, v in pairs( t ) do
		if v == val then
			return true
		end
	end
	return false
end

local g_get_avg_from_table = function( tbl )
	local val = 0
	for iter, v in ipairs( tbl ) do
		val = val + v
	end
	return val / math_max( 1, #tbl )
end

local g_log_worker = (function()
	local m_on_output = function() end

	client_set_event_callback( 'shutdown', function() client_unset_event_callback( 'output', m_on_output ) end )

	local m_log_track_list, m_colors = {}, { red = { 255, 0, 0 }, green = { 173, 250, 47 } }

	local m_process_string_colors = function( ... )
		local t, t_it = {}, 1
		for iter, data in ipairs( { ... } ) do
			local s
			if type( data ) == 'string' then
				s = data
			else
				local r, g, b = unpack( m_colors[data.rgb] )
				s = ('\a%02x%02x%02xFF%s\aFFFFFFFF'):format( r, g, b, data.text )
			end
			t[t_it] = s
			t_it = t_it + 1
		end
		return table_concat( t, '' )
	end

	local m_print_multicolor_text = function( allow_output, ... )
		if allow_output then
			client_color_log( m_colors.green[1], m_colors.green[2], m_colors.green[3], '[gamesense] \0' );
		else
			client_set_event_callback( 'output', m_on_output );
			client_color_log( m_colors.green[1], m_colors.green[2], m_colors.green[3], '[gamesense] \0' );
			client_unset_event_callback( 'output', m_on_output )
		end
		for iter, printable in ipairs( { ... } ) do
			if type( printable ) == 'string' then
				client_color_log( 255, 255, 255, printable, '\0' )
			else
				local r, g, b = unpack( m_colors[printable.rgb] )
				client_color_log( r, g, b, printable.text, '\0' )
			end
		end
		client_color_log( 255, 255, 255, ' ' )
	end

	local m_add_event_to_log = function( ... )
		local selections = ui_get( g_event_logger )
		if #selections == 0 then
			return
		end

		local is_console = g_contains( selections, 'Console' )
		local is_display = g_contains( selections, 'Display' )

		if is_console then
			m_print_multicolor_text( not is_display, ... )
		end

		if is_display then
			m_log_track_list[#m_log_track_list + 1] = { m_time = globals_realtime() + 5, m_string = m_process_string_colors( ... ) }
			if #m_log_track_list > 5 then
				for i = 1, #m_log_track_list - 5 do
					m_log_track_list[i].m_time = globals_realtime() + 0.1
				end
			end
		end
	end

	local m_think = function()
		if #m_log_track_list == 0 then
			return
		end

		local time = globals_realtime()

		for iter, tracked in ipairs( m_log_track_list ) do
			if time > tracked.m_time then
				table_remove( m_log_track_list, iter )
			end
		end

		local screen_width, screen_height = client_screen_size()
		local render_position_x, render_position_y = screen_width * 0.5, screen_height * 0.15

		for i = #m_log_track_list, 1, -1 do
			local rec = m_log_track_list[i]
			local time_delta = rec.m_time - time
			local is_coming_in, is_fading_away = time_delta > 4.5, time_delta < 0.5
			local position_x_offset, position_y_offset = is_coming_in and easing.quad_in( 5 - time_delta, 0, 1, 0.5 ) or 1, is_fading_away and easing.quad_out( time_delta, 0, 1, 0.5 ) or 1
			local alpha = is_fading_away and time_delta * 100 or 255
			local str = rec.m_string:gsub( '\a(%x%x)(%x%x)(%x%x)(%x%x)', ('\a%%1%%2%%3%02x'):format( alpha ) )
			renderer_text( render_position_x * position_x_offset, render_position_y * position_y_offset, 255, 255, 255, alpha, 'dc', 0, str )
			render_position_y = render_position_y - ({ renderer_measure_text( 'd', str ) })[2] - 3
		end
	end

	return { add_event_to_log = m_add_event_to_log, on_paint = m_think }
end)()

local g_aimbot_worker = (function()
	local m_global_history_table, m_aimbot_shot_tracklist, m_bullet_impact_tracklist = g_database_accessor.read_table(), {}, {}
	local m_aimbot_history_table = m_global_history_table.m_shot_array
	local m_aimbot_data_out = { m_total_fired_shots = 0, m_total_fired_sp_shots = 0, m_total_lethal_shots = 0, m_total_kills = 0, m_total_zeus_kills = 0, m_fired_shots_by_hitbox = { head = 0, body = 0, limbs = 0 }, m_hits = { m_total_hits = 0, m_lethal_kills = 0, m_basic_hits = { m_count = 0, m_per_hitbox = { head = 0, body = 0, limbs = 0 } }, m_sp_hits = { m_count = 0, m_per_hitbox = { head = 0, body = 0, limbs = 0 } } }, m_misses = { m_total_misses = 0, m_total_misses_by_hitbox = { head = 0, body = 0, limbs = 0 }, m_spread_misses = { m_count = 0, m_sp_count = 0, m_per_hitbox = { head = 0, body = 0, limbs = 0 }, m_sp_per_hitbox = { head = 0, body = 0, limbs = 0 } }, m_unknown_misses = { m_count = 0, m_sp_count = 0, m_per_hitbox = { head = 0, body = 0, limbs = 0 }, m_sp_per_hitbox = { head = 0, body = 0, limbs = 0 } }, m_pred_misses = { m_count = 0, m_sp_count = 0, m_per_hitbox = { head = 0, body = 0, limbs = 0 }, m_sp_per_hitbox = { head = 0, body = 0, limbs = 0 } }, m_death_misses = { m_count = 0, m_deaths = { m_local_death = 0, m_enemy_death = 0 } }, m_unreg_misses = { m_count = 0 } }, m_additional_data = { m_hitchances = {}, m_backtracks = {}, m_average_spread_angles = {} } }

	local m_analyze_aimbot_shot = (function()
		local m_add_var_to_buffer = function( var, buf, upper )
			local c = #buf + 1;
			buf[c] = var;
			if c > upper then
				table_remove( buf, 1 )
			end
		end
		local m_processor_functions = {
			['hit'] = function( aimbot_shot, is_safepoint, is_lethal, hitgroup_class, specific_data )
				m_aimbot_data_out.m_hits.m_total_hits = m_aimbot_data_out.m_hits.m_total_hits + 1
				if specific_data.m_killed_target then
					m_aimbot_data_out.m_total_kills = m_aimbot_data_out.m_total_kills + 1
					if is_lethal then
						m_aimbot_data_out.m_hits.m_lethal_kills = m_aimbot_data_out.m_hits.m_lethal_kills + 1
					end
					if aimbot_shot.m_used_weapon == 'Zeus x27' then
						m_aimbot_data_out.m_total_zeus_kills = m_aimbot_data_out.m_total_zeus_kills + 1
					end
				end
				local t = is_safepoint and m_aimbot_data_out.m_hits.m_sp_hits or m_aimbot_data_out.m_hits.m_basic_hits
				t.m_count = t.m_count + 1
				t.m_per_hitbox[hitgroup_class] = t.m_per_hitbox[hitgroup_class] + 1
			end,

			['miss'] = (function()
				local m_miss_tables = { ['spread'] = m_aimbot_data_out.m_misses.m_spread_misses, ['?'] = m_aimbot_data_out.m_misses.m_unknown_misses, ['prediction error'] = m_aimbot_data_out.m_misses.m_pred_misses, ['death'] = m_aimbot_data_out.m_misses.m_death_misses, ['unregistered shot'] = m_aimbot_data_out.m_misses.m_unreg_misses }
				return function( aimbot_shot, is_safepoint, is_lethal, hitgroup_class, specific_data )
					m_aimbot_data_out.m_misses.m_total_misses = m_aimbot_data_out.m_misses.m_total_misses + 1
					m_aimbot_data_out.m_misses.m_total_misses_by_hitbox[hitgroup_class] = m_aimbot_data_out.m_misses.m_total_misses_by_hitbox[hitgroup_class] + 1
					local miss_table = m_miss_tables[specific_data.m_miss_reason]
					if miss_table.m_sp_count then
						if is_safepoint then
							miss_table.m_sp_count = miss_table.m_sp_count + 1
							miss_table.m_sp_per_hitbox[hitgroup_class] = miss_table.m_sp_per_hitbox[hitgroup_class] + 1
						else
							miss_table.m_count = miss_table.m_count + 1
							miss_table.m_per_hitbox[hitgroup_class] = miss_table.m_per_hitbox[hitgroup_class] + 1
						end
					else
						miss_table.m_count = miss_table.m_count + 1
						if specific_data.m_miss_reason == 'death' then
							local miss_specific_data = specific_data.m_miss_specific_data
							if miss_specific_data[1] then
								miss_table.m_deaths.m_enemy_death = miss_table.m_deaths.m_enemy_death + 1
							else
								miss_table.m_deaths.m_local_death = miss_table.m_deaths.m_local_death + 1
							end
						end
					end
				end
			end)()
		}

		return function( aimbot_shot )
			local is_safepoint = g_contains( aimbot_shot.m_flags, 'Safe point' )
			local is_lethal = g_contains( aimbot_shot.m_flags, 'Lethal' )
			local hitgroup_class = aimbot_shot.m_hitgroup_class
			m_aimbot_data_out.m_total_fired_shots = m_aimbot_data_out.m_total_fired_shots + 1
			m_aimbot_data_out.m_fired_shots_by_hitbox[hitgroup_class] = m_aimbot_data_out.m_fired_shots_by_hitbox[hitgroup_class] + 1
			m_add_var_to_buffer( aimbot_shot.m_hitchance, m_aimbot_data_out.m_additional_data.m_hitchances, 255 )
			m_add_var_to_buffer( aimbot_shot.m_backtrack, m_aimbot_data_out.m_additional_data.m_backtracks, 255 )
			if aimbot_shot.m_spread_angle then
				m_add_var_to_buffer( aimbot_shot.m_spread_angle, m_aimbot_data_out.m_additional_data.m_average_spread_angles, 255 )
			end
			if is_safepoint then
				m_aimbot_data_out.m_total_fired_sp_shots = m_aimbot_data_out.m_total_fired_sp_shots + 1
			end
			if is_lethal then
				m_aimbot_data_out.m_total_lethal_shots = m_aimbot_data_out.m_total_lethal_shots + 1
			end
			local specific_data = aimbot_shot.m_result_specific_data[aimbot_shot.m_result]
			m_processor_functions[aimbot_shot.m_result]( aimbot_shot, is_safepoint, is_lethal, hitgroup_class, specific_data )
		end
	end)()

	local m_last_shot_id = (function()
		local last_id = 0
		for iter, shot in pairs( m_aimbot_history_table ) do -- the same bug as i had with the menu thing
			last_id = last_id + 1
			m_analyze_aimbot_shot( shot )
		end
		return last_id + 1
	end)( )

	local m_trim_shot_for_storage = ( function( )
		local m_unnecessary_fields = ( function( keys )
			local ret = { }
			for iter, key in ipairs( keys ) do
				ret[ key ] = true
			end
			return ret
		end )( {
			'm_aim_position',
			'm_shot_vec',
			'm_minimum_damage',
			'm_predicted_damage',
			'm_flag_string',
			'm_latency',
			'm_velocity_modifier_shot',
			'm_velocity_modifier_registered'
		} )

		return function( shot_data )
			local ret = { }

			for key, value in pairs( shot_data ) do
				if not m_unnecessary_fields[ key ] then
					ret[ key ] = value
				end
			end

			return ret
		end
	end )( )

	local m_safepoint_reference, m_avoid_unsafe_hitboxes_reference, m_mindamage_reference = ui_reference( 'rage', 'aimbot', 'force safe point' ), ui_reference( 'rage', 'aimbot', 'avoid unsafe hitboxes' ), ui_reference( 'rage', 'aimbot', 'minimum damage' )

	local m_get_hitgroup_class = function( hitgroup )
		if hitgroup == 1 then
			return 'head'
		elseif hitgroup > 1 and hitgroup <= 3 then
			return 'body'
		elseif hitgroup > 3 and hitgroup <= 7 then
			return 'limbs'
		end
		return 'body'
	end

	local m_ticks_to_time = function( t ) return t * globals_tickinterval() end

	local cl_lagcompensation = cvar.cl_lagcompensation

	local m_build_shot_flags = (function()
		local m_fl_tickbaseshift = bit_lshift( 1, 13 )
		local m_fl_defensive = bit_lshift( 1, 17 )

		local m_shot_flag_processors = {
			{ 'Lethal', 'Lethal', function( ev ) return ev.damage >= entity.get_prop( ev.target, 'm_iHealth' ) end }, { 'High', 'High priority', function( ev ) return ev.high_priority end }, { 'Anti-exploit', 'Anti-exploit', function() return cl_lagcompensation:get_int() == 0 end }, {
				'Exploit', 'Shifting tickbase', function( ev )
					local esp_flags = entity_get_esp_data( ev.target ).flags or 0
					return bit_band( esp_flags, m_fl_tickbaseshift ) ~= 0
				end
			}, {
				'Defensive', 'Defensive DT', function( ev )
					local esp_flags = entity_get_esp_data( ev.target ).flags or 0
					return bit_band( esp_flags, m_fl_defensive ) ~= 0
				end
			}, {
				'Safe', 'Safe point', (function()
					local m_hitgroup_indices = { ['Head'] = { 1 }, ['Chest'] = { 2 }, ['Stomach'] = { 3 }, ['Arms'] = { 4, 5 }, ['Legs'] = { 6, 7 }, ['Feet'] = { 6, 7 } }
					return function( ev )
						if ui_get( m_safepoint_reference ) then
							return true
						end
						local plist_state = plist_get( ev.target, 'Override safe point' )
						if plist_state ~= '-' then
							return plist_state == 'On'
						end
						for iter, group in ipairs( ui_get( m_avoid_unsafe_hitboxes_reference ) ) do
							for iter2, idx in ipairs( m_hitgroup_indices[group] ) do
								if idx == ev.hitgroup then
									return true
								end
							end
						end
						return false
					end
				end)()
			}, {
				'First', 'First shot', (function()
					local m_aimbot_shot_times = {}
					return function( ev )
						local time, last_time = globals_tickcount(), m_aimbot_shot_times[ev.target] or 0
						m_aimbot_shot_times[ev.target] = time
						return time - last_time > (10 / globals_tickinterval()), client_delay_call( 5, table_remove, m_aimbot_shot_times, ev.target )
					end
				end)()
			}
		}
		return function( ev )
			local short_flags, long_flags, table_it = {}, {}, 1
			for iter, v in ipairs( m_shot_flag_processors ) do
				local short, long, fn = unpack( v );
				local should_output, custom_short = fn( ev )
				if should_output then
					short_flags[table_it], long_flags[table_it] = custom_short or short, long
					table_it = table_it + 1
				end
			end
			return table_concat( short_flags, ', ' ), long_flags
		end
	end)()

	local m_build_shot_filters = (function()
		local m_processor_functions = { { 'c', function() return client_get_cvar( 'sv_cheats' ) == '1' end }, { 'x', function() return cl_lagcompensation:get_int() == 0 end }, { 'w', function() return entity_get_prop( entity_get_game_rules(), 'm_bWarmupPeriod' ) == 1 end }, { 'b', function( ev ) return bit_band( entity_get_prop( ev.target, 'm_fFlags' ), 0x200 ) == 0x200 end } }
		return function( ev )
			local t, t_it = {}, 1
			for iter, v in ipairs( m_processor_functions ) do
				local f, fn = unpack( v )
				if fn( ev ) then
					t[t_it] = f;
					t_it = t_it + 1
				end
			end
			return table_concat( t, '' )
		end
	end)()

	local m_handle_aim_fire = function( ev )
		local me, aim_data_struct = entity.get_local_player(), {
			m_identifier = m_last_shot_id,
			m_unixtime = client.unix_time(),
			m_filters = m_build_shot_filters( ev ),
			m_aim_position = vector( client_eye_position() ),
			m_shot_vec = vector( ev.x, ev.y, ev.z ), 
			m_hitgroup = ev.hitgroup,
			m_hitgroup_class = 'body',
			m_hitchance = ev.hit_chance,
			m_minimum_damage = ui_get( m_mindamage_reference ),
			m_predicted_damage = ev.damage, m_backtrack = math_max( 0, m_ticks_to_time( globals_tickcount() - ev.tick ) ),
			m_flag_string = '', m_flags = {}, m_latency = client_real_latency(),
			m_velocity_modifier_shot = 0, m_velocity_modifier_registered = 0, m_used_weapon = '',
			m_spread_angle = nil,
			m_result = '',
			m_result_specific_data = {}
		}

		aim_data_struct.m_flag_string, aim_data_struct.m_flags = m_build_shot_flags( ev )
		aim_data_struct.m_velocity_modifier_shot = entity_get_prop( me, 'm_flVelocityModifier' )
		aim_data_struct.m_used_weapon = csgo_weapons[entity_get_prop( entity_get_player_weapon( me ), 'm_iItemDefinitionIndex' )].name
		m_last_shot_id = m_last_shot_id + 1
		m_aimbot_shot_tracklist[ev.id] = aim_data_struct
	end

	local m_handle_bullet_impact = function( ev )
		if not ev then
			return
		end
		if client_userid_to_entindex( ev.userid ) ~= entity_get_local_player() then
			return
		end
		local seq_num = globals_lastoutgoingcommand() + globals_chokedcommands()
		if not m_bullet_impact_tracklist[seq_num] then
			m_bullet_impact_tracklist[seq_num] = vector( ev.x, ev.y, ev.z )
			return client_delay_call( 5, table_remove, m_bullet_impact_tracklist, seq_num )
		end
	end

	local m_get_spread = function( shot_id )
		local aim_data, impact_vector = m_aimbot_shot_tracklist[shot_id], m_bullet_impact_tracklist[globals_lastoutgoingcommand() + globals_chokedcommands()]
		if not aim_data or not impact_vector then
			return
		end
		local shoot_pos = aim_data.m_aim_position;
		local ideal_dir = vector( shoot_pos:to( aim_data.m_shot_vec ):angles() )
		local dist = ideal_dir:dist2d( vector( shoot_pos:to( impact_vector ):angles() ) )
		while dist > 180 do
			dist = dist - 360
		end
		while dist < -180 do
			dist = dist + 360
		end
		return math_abs( dist )
	end

	local m_hitgroups = setmetatable( { 'head', 'chest', 'stomach', 'left arm', 'right arm', 'left leg', 'right leg', 'neck' }, { __index = function() return 'body' end } )

	local m_output_result = function( aim_data, ev )
		if #ui_get( g_event_logger ) == 0 then
			return
		end

		local clr, specific = unpack( ({ ['hit'] = { 'green', { ('[%d] Hit '):format( ev.id ), { rgb = 'green', text = entity_get_player_name( ev.target ) }, '\'s ', { rgb = 'green', text = m_hitgroups[ev.hitgroup] }, ' (', { rgb = 'green', text = m_hitgroups[aim_data.m_hitgroup] }, ') for ', { rgb = 'green', text = ev.damage or 0 }, ' HP (', { rgb = 'green', text = entity_get_prop( ev.target, 'm_iHealth' ) }, ' remaining)' } }, ['miss'] = { 'red', { ('[%d] Missed '):format( ev.id ), { rgb = 'red', text = entity_get_player_name( ev.target ) }, '\'s ', { rgb = 'red', text = m_hitgroups[ev.hitgroup] }, ' due to ', { rgb = 'red', text = ev.reason } } } })[aim_data.m_result] )
		local shared = { ' (spread: ', { rgb = clr, text = ('%s'):format( aim_data.m_spread_angle and ('%.3f°'):format( aim_data.m_spread_angle ) or 'lost track of shot' ) }, ') - (damage: ', { rgb = clr, text = ('%d'):format( aim_data.m_predicted_damage ) }, '/', { rgb = clr, text = ('%d'):format( aim_data.m_minimum_damage ) }, ' | Hitchance: ', { rgb = clr, text = ('%d%%'):format( ev.hit_chance ) }, ' | Bt: ', { rgb = clr, text = ('%d'):format( aim_data.m_backtrack * 1000 ) }, 'ms | Ping: ', { rgb = clr, text = ('%d'):format( aim_data.m_latency * 1000 ) }, 'ms | Slowdown: ', { rgb = clr, text = ('%d%%->%d%%'):format( aim_data.m_velocity_modifier_shot * 100, aim_data.m_velocity_modifier_registered * 100 ) }, ') (Flags: ', { rgb = clr, text = (#aim_data.m_flag_string == 0 and 'None' or aim_data.m_flag_string) }, ')' }
		local spec_len = #specific

		for iter, s in ipairs( shared ) do
			specific[spec_len + iter] = s
		end

		g_log_worker.add_event_to_log( unpack( specific ) )
	end

	local m_finalize_shot_recording = function( ev, aim_data )
		aim_data.m_velocity_modifier_registered = entity_get_prop( entity_get_local_player(), 'm_flVelocityModifier' )
		aim_data.m_spread_angle = m_get_spread( ev.id )

		m_analyze_aimbot_shot( aim_data )
		m_output_result( aim_data, ev )

		client_fire_event( 'aimbot_logger_finalize', aim_data )

		m_aimbot_history_table[ aim_data.m_identifier ] = m_trim_shot_for_storage( aim_data )
	end

	local m_handle_aim_hit = function( ev )
		local aim_data = m_aimbot_shot_tracklist[ev.id]
		if not aim_data then
			return
		end
		aim_data.m_result, aim_data.m_hitgroup_class = 'hit', m_get_hitgroup_class( ev.hitgroup )
		aim_data.m_result_specific_data['hit'] = { m_dealt_damage = ev.damage, m_mismatch_hitbox = ev.hitgroup ~= aim_data.m_hitgroup, m_mismatch_damage = ev.damage < aim_data.m_predicted_damage, m_killed_target = not entity_is_alive( ev.target ) }
		m_finalize_shot_recording( ev, aim_data )
	end

	local m_handle_aim_miss = function( ev )
		local aim_data = m_aimbot_shot_tracklist[ev.id]
		if not aim_data then
			return
		end
		aim_data.m_result, aim_data.m_hitgroup_class = 'miss', m_get_hitgroup_class( ev.hitgroup )
		local specific_data = { m_miss_reason = ev.reason, m_miss_specific_data = {} }
		if ev.reason == 'death' then
			specific_data.m_miss_specific_data = { entity_is_alive( entity_get_local_player() ), entity_is_alive( ev.target ) }
		end
		aim_data.m_result_specific_data['miss'] = specific_data
		m_finalize_shot_recording( ev, aim_data )
	end

	return { on_aim_fire = m_handle_aim_fire, on_bullet_impact = m_handle_bullet_impact, on_aim_hit = m_handle_aim_hit, on_aim_miss = m_handle_aim_miss, get_database_ptr = function() return m_global_history_table, m_aimbot_data_out, m_aimbot_history_table end }
end)()

local g_container_manager = (function()
	local m_global_data_ptr, m_aimbot_data_ptr = g_aimbot_worker.get_database_ptr()
	local m_aimbot_dataset_processor = (function()
		local m_aimbot_data_table = { m_ready = false, m_total_accuracy_rate = 0, m_accuracy_by_spec = { head = 0, body = 0, limbs = 0, sp = 0, lethal = 0 }, m_total_shots = 0, m_total_kills = 0, m_total_headshots = 0, m_total_zeus = 0, m_average_hc = 0, m_average_spread = 0, m_average_shots_per_kill = 0, m_miss_reasons = { { m_refer_table = 'm_unknown_misses', m_name = 'CRR', m_full_name = 'CORRECT', m_count = 0, m_percentage = 0 }, { m_refer_table = 'm_spread_misses', m_name = 'SPR', m_full_name = 'SPREAD', m_count = 0, m_percentage = 0 }, { m_refer_table = 'm_pred_misses', m_name = 'PRED', m_full_name = 'PRED', m_count = 0, m_percentage = 0 }, { m_refer_table = 'm_death_misses', m_name = 'DTH', m_full_name = 'DEATH', m_count = 0, m_percentage = 0 }, { m_refer_table = 'm_unreg_misses', m_name = 'UNR', m_full_name = 'UNREG', m_count = 0, m_percentage = 0 } }, m_most_common_reason = '' }
		local m_calculate_head_body_limb_accuracy = function()
			local total_shots_by_hitbox = m_aimbot_data_ptr.m_fired_shots_by_hitbox
			local tables = { m_aimbot_data_ptr.m_hits.m_basic_hits, m_aimbot_data_ptr.m_hits.m_sp_hits }
			local new_tbl = { head = 0, body = 0, limbs = 0 }
			for i = 1, 2 do
				local t = tables[i]
				new_tbl.head = new_tbl.head + t.m_per_hitbox.head;
				new_tbl.body = new_tbl.body + t.m_per_hitbox.body;
				new_tbl.limbs = new_tbl.limbs + t.m_per_hitbox.limbs
			end
			for k, v in pairs( new_tbl ) do
				m_aimbot_data_table.m_accuracy_by_spec[k] = v / math_max( 1, total_shots_by_hitbox[k] )
			end
		end
		local m_miss_table_compare = function( a, b ) return a.m_count > b.m_count end
		local m_calculate_miss_chart = function()
			local misses = m_aimbot_data_ptr.m_misses
			local total_misses = misses.m_total_misses
			for i = 1, 5 do
				local it = m_aimbot_data_table.m_miss_reasons[i]
				local corresponding_table = misses[it.m_refer_table]
				it.m_count = corresponding_table.m_count + (corresponding_table.m_sp_count or 0)
				it.m_percentage = it.m_count / math_max( 1, total_misses )
			end
			table_sort( m_aimbot_data_table.m_miss_reasons, m_miss_table_compare )
		end
		local m_update_aim_data = function()
			if m_aimbot_data_ptr.m_total_fired_shots < 5 then
				m_aimbot_data_table.m_ready = false
				return
			end
			m_aimbot_data_table.m_total_accuracy_rate = m_aimbot_data_ptr.m_hits.m_total_hits / m_aimbot_data_ptr.m_total_fired_shots
			m_aimbot_data_table.m_accuracy_by_spec.sp = m_aimbot_data_ptr.m_hits.m_sp_hits.m_count / math_max( 1, m_aimbot_data_ptr.m_total_fired_sp_shots )
			m_aimbot_data_table.m_accuracy_by_spec.lethal = m_aimbot_data_ptr.m_hits.m_lethal_kills / math_max( 1, m_aimbot_data_ptr.m_total_lethal_shots )
			m_calculate_head_body_limb_accuracy()
			m_aimbot_data_table.m_total_shots, m_aimbot_data_table.m_total_kills, m_aimbot_data_table.m_total_zeus = m_aimbot_data_ptr.m_total_fired_shots, m_aimbot_data_ptr.m_total_kills, m_aimbot_data_ptr.m_total_zeus_kills
			m_aimbot_data_table.m_total_headshots = m_aimbot_data_ptr.m_hits.m_basic_hits.m_per_hitbox.head + m_aimbot_data_ptr.m_hits.m_sp_hits.m_per_hitbox.head
			m_calculate_miss_chart()
			if m_aimbot_data_table.m_total_accuracy_rate == 1 then
				m_aimbot_data_table.m_most_common_reason = 'NONE'
			else
				m_aimbot_data_table.m_most_common_reason = m_aimbot_data_table.m_miss_reasons[1].m_full_name
			end
			m_aimbot_data_table.m_average_hc = g_get_avg_from_table( m_aimbot_data_ptr.m_additional_data.m_hitchances )
			m_aimbot_data_table.m_average_spread = g_get_avg_from_table( m_aimbot_data_ptr.m_additional_data.m_average_spread_angles )
			m_aimbot_data_table.m_average_shots_per_kill = m_aimbot_data_table.m_total_shots / math_max( 1, m_aimbot_data_table.m_total_kills )
			m_aimbot_data_table.m_ready = true
		end

		m_update_aim_data()
		client_set_event_callback( 'aimbot_logger_finalize', m_update_aim_data )

		return { get_data_ptr = function() return m_aimbot_data_table end }
	end)()

	local m_render_aim_data_ptr = m_aimbot_dataset_processor.get_data_ptr()

	local m_render_engine = (function()
		local a={}local b=function(c,d,e,f,g,h,i,j,k)renderer_rectangle(c+g,d,e-g*2,g,h,i,j,k)renderer_rectangle(c,d+g,g,f-g*2,h,i,j,k)renderer_rectangle(c+g,d+f-g,e-g*2,g,h,i,j,k)renderer_rectangle(c+e-g,d+g,g,f-g*2,h,i,j,k)renderer_rectangle(c+g,d+g,e-g*2,f-g*2,h,i,j,k)renderer_circle(c+g,d+g,h,i,j,k,g,180,0.25)renderer_circle(c+e-g,d+g,h,i,j,k,g,90,0.25)renderer_circle(c+g,d+f-g,h,i,j,k,g,270,0.25)renderer_circle(c+e-g,d+f-g,h,i,j,k,g,0,0.25)end;local l=function(c,d,e,f,g,h,i,j,k)renderer_rectangle(c,d+g,1,f-g*2+2,h,i,j,k)renderer_rectangle(c+e-1,d+g,1,f-g*2+1,h,i,j,k)renderer_rectangle(c+g,d,e-g*2,1,h,i,j,k)renderer_rectangle(c+g,d+f,e-g*2,1,h,i,j,k)renderer_circle_outline(c+g,d+g,h,i,j,k,g,180,0.25,1)renderer_circle_outline(c+e-g,d+g,h,i,j,k,g,270,0.25,1)renderer_circle_outline(c+g,d+f-g+1,h,i,j,k,g,90,0.25,1)renderer_circle_outline(c+e-g,d+f-g+1,h,i,j,k,g,0,0.25,1)end;local m=8;local n=45;local o=10;local p=function(c,d,e,f,g,h,i,j,k,q)renderer_rectangle(c+g,d,e-g*2,1,h,i,j,k)renderer_circle_outline(c+g,d+g,h,i,j,k,g,180,0.25,1)renderer_circle_outline(c+e-g,d+g,h,i,j,k,g,270,0.25,1)renderer_gradient(c,d+g,1,f-g*2,h,i,j,k,h,i,j,n,false)renderer_gradient(c+e-1,d+g,1,f-g*2,h,i,j,k,h,i,j,n,false)renderer_circle_outline(c+g,d+f-g,h,i,j,n,g,90,0.25,1)renderer_circle_outline(c+e-g,d+f-g,h,i,j,n,g,0,0.25,1)renderer_rectangle(c+g,d+f-1,e-g*2,1,h,i,j,n)for r=1,q do l(c-r,d-r,e+r*2,f+r*2,g,h,i,j,q-r)end end;local s,t,u,v=17,17,17,200;a.render_container=function(c,d,e,f,h,i,j,k,w)renderer_blur(c,d,e,f,100,100)b(c,d,e,f,m,s,t,u,v)p(c,d,e,f,m,h,i,j,k,o)if w then w(c+m,d+m,e-m*2,f-m*2)end end;a.render_glow_line=function(c,d,x,y,h,i,j,k,z,A,B,q)local C=vector(c,d,0)local D=vector(x,y,0)local E=({C:to(D):angles()})[2]for r=1,q do renderer_circle_outline(c,d,z,A,B,q-r,r,E+90,0.5,1)renderer_circle_outline(x,y,z,A,B,q-r,r,E-90,0.5,1)local F=vector(math_cos(math_rad(E+90)),math_sin(math_rad(E+90)),0):scaled(r*0.95)local G=vector(math_cos(math_rad(E-90)),math_sin(math_rad(E-90)),0):scaled(r*0.95)local H=F+C;local I=F+D;local J=G+C;local K=G+D;renderer_line(H.x,H.y,I.x,I.y,z,A,B,q-r)renderer_line(J.x,J.y,K.x,K.y,z,A,B,q-r)end;renderer_line(c,d,x,y,h,i,j,k)end;return a
	end)()

	local m_dpi_scale_reference = ui_reference( 'misc', 'settings', 'dpi scale' )
	local m_scaling_multipliers = { ['100%'] = 1, ['125%'] = 1.25, ['150%'] = 1.5, ['175%'] = 1.75, ['200%'] = 2 }
	local m_round_number = function( v ) return math_floor( v + 0.5 ) end

	local m_display_sizes = {
		['Mini'] = (function()
			local m_container_callback_function = function( x, y, w, h )
				local current_dpi_scale = m_scaling_multipliers[ui_get( m_dpi_scale_reference )]
				local r, g, b = ui_get( g_accent_color_picker )
				local total_accuracy = m_render_aim_data_ptr.m_total_accuracy_rate
				renderer_text( m_round_number( x + w * 0.5 ), y, 255, 255, 255, 200, 'dc-', 0, ('ACCURACY %.1f%%'):format( total_accuracy * 100 ) )
				local bar_width = m_round_number( 4 * current_dpi_scale );
				local inner_bar_width = bar_width - 2
				renderer_rectangle( m_round_number( x + w * 0.01 ), m_round_number( y + h * 0.1 ), bar_width, m_round_number( h * 0.9 ), 17, 17, 17, 255 )
				renderer_rectangle( m_round_number( x + w * 0.01 + 1 ), m_round_number( m_round_number( y + h * 0.1 ) + 1 + h * 0.9 * (1 - total_accuracy) ), inner_bar_width, m_round_number( (h * 0.9 - 2) * total_accuracy ), r, g, b, 200 )
				renderer_rectangle( m_round_number( x + w * 0.01 ), m_round_number( m_round_number( y + h * 0.1 ) + 1 + h * 0.9 * (1 - total_accuracy) ), bar_width, m_round_number( 1 * current_dpi_scale ), r, g, b, 255 )
				do
					local x, y, w, h = x + w * 0.15, y + h * 0.1, w * 0.85, h * 0.9
					local m_rendered_strings = { { 'HEAD:', ('%.1f%%'):format( m_render_aim_data_ptr.m_accuracy_by_spec.head * 100 ) }, { 'BODY:', ('%.1f%%'):format( m_render_aim_data_ptr.m_accuracy_by_spec.body * 100 ) }, { 'SP:', ('%.1f%%'):format( m_render_aim_data_ptr.m_accuracy_by_spec.sp * 100 ) }, { 'MOST MISSES', ('%s'):format( m_render_aim_data_ptr.m_most_common_reason ) } };
					local string_cnt = #m_rendered_strings
					local allowed_slice = h / string_cnt
					for i = 1, string_cnt do
						local left, right = unpack( m_rendered_strings[i] )
						renderer_text( m_round_number( x ), m_round_number( y + allowed_slice * (i - 1) ), 255, 255, 255, 200, 'd-', 0, left )
						renderer_text( m_round_number( x + w * 0.95 ), m_round_number( y + allowed_slice * (i - 1) ), 255, 255, 255, 200, 'dr-', 0, right )
					end
				end
			end
			return { m_display_width = 120, m_display_height = 65, m_last_width = 120, m_last_height = 65, m_container_callback = m_container_callback_function }
		end)(),
		['Full-sized'] = (function()
			local m_chart_colors = { { 0x4e, 0xa5, 0xd9 }, { 0x2a, 0x44, 0x94 }, { 0x44, 0xcf, 0xcb }, { 0x22, 0x48, 0x70 }, { 0x12, 0x2c, 0x34 } }
			local m_container_callback_function = function( x, y, w, h )
				local current_dpi_scale = m_scaling_multipliers[ui_get( m_dpi_scale_reference )]
				local r, g, b = ui_get( g_accent_color_picker )
				renderer_text( x + w * 0.5, y, 255, 255, 255, 200, 'cd-', 0, 'AIMBOT STATS' )
				local text_size_y = ({ renderer_measure_text( 'd-', 'AIMBOT STATS' ) })[2]
				renderer_text( x + w * 0.5, y + text_size_y, 255, 255, 255, 200, 'cd-', 0, 'TOTAL ACCURACY%' )
				renderer_rectangle( m_round_number( x + w * 0.05 ), m_round_number( y + 16 * current_dpi_scale ), m_round_number( w * 0.9 ), m_round_number( 7 * current_dpi_scale ), 17, 17, 17, 225 )
				renderer_rectangle( m_round_number( x + w * 0.05 + 1 ), m_round_number( y + 17 * current_dpi_scale ), m_round_number( (w * 0.9 - 1) * m_render_aim_data_ptr.m_total_accuracy_rate ), m_round_number( 5 * current_dpi_scale ), r, g, b, 255 )
				renderer_rectangle( m_round_number( x + w * 0.05 + 1 + (w * 0.9 - 1) * m_render_aim_data_ptr.m_total_accuracy_rate ), m_round_number( y + 16 * current_dpi_scale ), 1, m_round_number( 7 * current_dpi_scale ), r, g, b, 255 )
				renderer_text( m_round_number( x + w * 0.05 + 1 + (w * 0.9 - 1) * m_render_aim_data_ptr.m_total_accuracy_rate ), m_round_number( y + 23 * current_dpi_scale ), 255, 255, 255, 200, 'cd-', 0, ('%d%%'):format( m_render_aim_data_ptr.m_total_accuracy_rate * 100 ) )
				do
					local left_bound_x, right_bound_x = x + w * 0.05, x + w * 0.55
					local y = y + 27 * current_dpi_scale
					local w = w * 0.4
					local h = h - 27 * current_dpi_scale
					do -- left
						local x = left_bound_x
						local accuracy_by_spec = m_render_aim_data_ptr.m_accuracy_by_spec
						renderer_text( m_round_number( x ), m_round_number( y ), 255, 255, 255, 200, 'd-', 0, 'HEAD: \nBODY: \nLIMBS: \nSP: \nLETHAL SHOT: ' )
						local accuracy_str = ('%.1f%%\n%.1f%%\n%.1f%%\n%.1f%%\n%.1f%%'):format( accuracy_by_spec.head * 100, accuracy_by_spec.body * 100, accuracy_by_spec.limbs * 100, accuracy_by_spec.sp * 100, accuracy_by_spec.lethal * 100 )
						renderer_text( m_round_number( x + w * 0.95 ), m_round_number( y ), 255, 255, 255, 200, 'dr-', 0, accuracy_str )
						local measurement_x = renderer_measure_text( 'd-', accuracy_str )
						local y = y + h * 0.6
						renderer_text( m_round_number( x ), m_round_number( y ), 255, 255, 255, 200, 'd-', 0, 'TOTAL SHOTS: \nTOTAL KILLS: \nTOTAL HS: \nTOTAL ZEUSES: ' )
						renderer_text( m_round_number( x + w * 0.95 - measurement_x ), y, 255, 255, 255, 200, 'd-', 0, ('%d\n%d\n%d\n%d'):format( m_render_aim_data_ptr.m_total_shots, m_render_aim_data_ptr.m_total_kills, m_render_aim_data_ptr.m_total_headshots, m_render_aim_data_ptr.m_total_zeus ) )
					end
					do -- right
						local x = right_bound_x
						local target_circle_radius = h * 0.2
						renderer_text( m_round_number( x + w * 0.5 - renderer_measure_text( 'd-', 'MISS CHART:' ) * 0.5 ), m_round_number( y ), 255, 255, 255, 200, 'd-', 0, 'MISS CHART:' )
						local circle_center_x, circle_center_y = m_round_number( x + w * 0.5 ), m_round_number( y + target_circle_radius + 14 * current_dpi_scale )
						renderer_circle( circle_center_x, circle_center_y, 17, 17, 17, 225, m_round_number( target_circle_radius ), 0, 1 )
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
							local r, g, b = unpack( m_chart_colors[i] )
							renderer_circle_outline( circle_center_x, circle_center_y, r, g, b, 225, m_round_number( target_circle_radius - 1 ), ang_start, t.m_percentage, m_round_number( 25 * current_dpi_scale - 1 ) )
							if frac > 0.05 then
								local ang = math_rad( ang_start ) + (2 * math.pi * frac * 0.5)
								local position_x, position_y = circle_center_x + math_cos( ang ) * target_circle_radius * 0.6, circle_center_y + math_sin( ang ) * target_circle_radius * 0.6
								pie_chart_text_positions[pie_chart_text_position_it] = { m_name = t.m_name, m_frac = frac * 100, x = position_x, y = position_y }
								pie_chart_text_position_it = pie_chart_text_position_it + 1
							end
							ang_start = ang_start + math_deg( (2 * math.pi * t.m_percentage) )
							::continue::
						end
						for i = 1, #pie_chart_text_positions do
							local v = pie_chart_text_positions[i]
							renderer_text( m_round_number( v.x ), m_round_number( v.y ), 255, 255, 255, 225, (current_dpi_scale == 1 and 'c-' or 'c'), 0, ('%s (%d%%)'):format( v.m_name, v.m_frac ) )
						end
						local y = y + h * 0.6
						renderer_text( m_round_number( x ), m_round_number( y ), 255, 255, 255, 200, 'd-', 0, 'MOST COMMON: \nAVG HC: \nAVG SPREAD: \nAVG SHOTS/KILL: ' )
						renderer_text( m_round_number( x + w * 0.95 ), m_round_number( y ), 255, 255, 255, 200, 'dr-', 0, ('%s\n%.1f%%\n%.2f°\n%.2f'):format( miss_reasons[1].m_full_name, m_render_aim_data_ptr.m_average_hc, m_render_aim_data_ptr.m_average_spread, m_render_aim_data_ptr.m_average_shots_per_kill ) )
					end
				end
			end

			return { m_display_width = 300, m_display_height = 150, m_last_width = 300, m_last_height = 150, m_container_callback = m_container_callback_function }
		end)()
	}

	local m_render_position_funcs = {
		['Attached to player'] = (function()
			local m_inbetweening = (function()
				local a={}local b,c,d,e,f,g,h=math.pow,math_sin,math_cos,math.pi,math.sqrt,math.abs,math.asin;local function i(j,k,l,m)return l*j/m+k end;local function n(j,k,l,m)return l*b(j/m,2)+k end;local function o(j,k,l,m)j=j/m;return-l*j*(j-2)+k end;local function p(j,k,l,m)j=j/m*2;if j<1 then return l/2*b(j,2)+k end;return-l/2*((j-1)*(j-3)-1)+k end;local function q(j,k,l,m)if j<m/2 then return o(j*2,k,l/2,m)end;return n(j*2-m,k+l/2,l/2,m)end;local function r(j,k,l,m)return l*b(j/m,3)+k end;local function s(j,k,l,m)return l*(b(j/m-1,3)+1)+k end;local function t(j,k,l,m)j=j/m*2;if j<1 then return l/2*j*j*j+k end;j=j-2;return l/2*(j*j*j+2)+k end;local function u(j,k,l,m)if j<m/2 then return s(j*2,k,l/2,m)end;return r(j*2-m,k+l/2,l/2,m)end;local function v(j,k,l,m)return l*b(j/m,4)+k end;local function w(j,k,l,m)return-l*(b(j/m-1,4)-1)+k end;local function x(j,k,l,m)j=j/m*2;if j<1 then return l/2*b(j,4)+k end;return-l/2*(b(j-2,4)-2)+k end;local function y(j,k,l,m)if j<m/2 then return w(j*2,k,l/2,m)end;return v(j*2-m,k+l/2,l/2,m)end;local function z(j,k,l,m)return l*b(j/m,5)+k end;local function A(j,k,l,m)return l*(b(j/m-1,5)+1)+k end;local function B(j,k,l,m)j=j/m*2;if j<1 then return l/2*b(j,5)+k end;return l/2*(b(j-2,5)+2)+k end;local function C(j,k,l,m)if j<m/2 then return A(j*2,k,l/2,m)end;return z(j*2-m,k+l/2,l/2,m)end;local function D(j,k,l,m)return-l*d(j/m*e/2)+l+k end;local function E(j,k,l,m)return l*c(j/m*e/2)+k end;local function F(j,k,l,m)return-l/2*(d(e*j/m)-1)+k end;local function G(j,k,l,m)if j<m/2 then return E(j*2,k,l/2,m)end;return D(j*2-m,k+l/2,l/2,m)end;local function H(j,k,l,m)if j==0 then return k end;return l*b(2,10*(j/m-1))+k-l*0.001 end;local function I(j,k,l,m)if j==m then return k+l end;return l*1.001*(-b(2,-10*j/m)+1)+k end;local function J(j,k,l,m)if j==0 then return k end;if j==m then return k+l end;j=j/m*2;if j<1 then return l/2*b(2,10*(j-1))+k-l*0.0005 end;return l/2*1.0005*(-b(2,-10*(j-1))+2)+k end;local function K(j,k,l,m)if j<m/2 then return I(j*2,k,l/2,m)end;return H(j*2-m,k+l/2,l/2,m)end;local function L(j,k,l,m)return-l*(f(1-b(j/m,2))-1)+k end;local function M(j,k,l,m)return l*f(1-b(j/m-1,2))+k end;local function N(j,k,l,m)j=j/m*2;if j<1 then return-l/2*(f(1-j*j)-1)+k end;j=j-2;return l/2*(f(1-j*j)+1)+k end;local function O(j,k,l,m)if j<m/2 then return M(j*2,k,l/2,m)end;return L(j*2-m,k+l/2,l/2,m)end;local function P(Q,R,l,m)Q,R=Q or m*0.3,R or 0;if R<g(l)then return Q,l,Q/4 end;return Q,R,Q/(2*e)*h(l/R)end;local function S(j,k,l,m,R,Q)local T;if j==0 then return k end;j=j/m;if j==1 then return k+l end;Q,R,T=P(Q,R,l,m)j=j-1;return-(R*b(2,10*j)*c((j*m-T)*2*e/Q))+k end;local function U(j,k,l,m,R,Q)local T;if j==0 then return k end;j=j/m;if j==1 then return k+l end;Q,R,T=P(Q,R,l,m)return R*b(2,-10*j)*c((j*m-T)*2*e/Q)+l+k end;local function V(j,k,l,m,R,Q)local T;if j==0 then return k end;j=j/m*2;if j==2 then return k+l end;Q,R,T=P(Q,R,l,m)j=j-1;if j<0 then return-0.5*R*b(2,10*j)*c((j*m-T)*2*e/Q)+k end;return R*b(2,-10*j)*c((j*m-T)*2*e/Q)*0.5+l+k end;local function W(j,k,l,m,R,Q)if j<m/2 then return U(j*2,k,l/2,m,R,Q)end;return S(j*2-m,k+l/2,l/2,m,R,Q)end;local function X(j,k,l,m,T)T=T or 1.70158;j=j/m;return l*j*j*((T+1)*j-T)+k end;local function Y(j,k,l,m,T)T=T or 1.70158;j=j/m-1;return l*(j*j*((T+1)*j+T)+1)+k end;local function Z(j,k,l,m,T)T=(T or 1.70158)*1.525;j=j/m*2;if j<1 then return l/2*j*j*((T+1)*j-T)+k end;j=j-2;return l/2*(j*j*((T+1)*j+T)+2)+k end;local function _(j,k,l,m,T)if j<m/2 then return Y(j*2,k,l/2,m,T)end;return X(j*2-m,k+l/2,l/2,m,T)end;local function a0(j,k,l,m)j=j/m;if j<1/2.75 then return l*7.5625*j*j+k end;if j<2/2.75 then j=j-1.5/2.75;return l*(7.5625*j*j+0.75)+k elseif j<2.5/2.75 then j=j-2.25/2.75;return l*(7.5625*j*j+0.9375)+k end;j=j-2.625/2.75;return l*(7.5625*j*j+0.984375)+k end;local function a1(j,k,l,m)return l-a0(m-j,0,l,m)+k end;local function a2(j,k,l,m)if j<m/2 then return a1(j*2,0,l,m)*0.5+k end;return a0(j*2-m,0,l,m)*0.5+l*.5+k end;local function a3(j,k,l,m)if j<m/2 then return a0(j*2,k,l/2,m)end;return a1(j*2-m,k+l/2,l/2,m)end;a.easing={linear=i,inQuad=n,outQuad=o,inOutQuad=p,outInQuad=q,inCubic=r,outCubic=s,inOutCubic=t,outInCubic=u,inQuart=v,outQuart=w,inOutQuart=x,outInQuart=y,inQuint=z,outQuint=A,inOutQuint=B,outInQuint=C,inSine=D,outSine=E,inOutSine=F,outInSine=G,inExpo=H,outExpo=I,inOutExpo=J,outInExpo=K,inCirc=L,outCirc=M,inOutCirc=N,outInCirc=O,inElastic=S,outElastic=U,inOutElastic=V,outInElastic=W,inBack=X,outBack=Y,inOutBack=Z,outInBack=_,inBounce=a1,outBounce=a0,inOutBounce=a2,outInBounce=a3}local function a4(a5,a6,a7)a7=a7 or a6;local a8=getmetatable(a6)if a8 and getmetatable(a5)==nil then setmetatable(a5,a8)end;for a9,aa in pairs(a6)do if type(aa)=='table'then a5[a9]=a4({},aa,a7[a9])else a5[a9]=a7[a9]end end;return a5 end;local function ab(ac,ad,ae)ae=ae or{}local af,ag;for a9,ah in pairs(ad)do af,ag=type(ah),a4({},ae)table_insert(ag,tostring(a9))if af=='number'then assert(type(ac[a9])=='number','Parameter \''..table_concat(ag,'/')..'\' is missing from subject or isn\'t a number')elseif af=='table'then ab(ac[a9],ah,ag)else assert(af=='number','Parameter \''..table_concat(ag,'/')..'\' must be a number or table of numbers')end end end;local function ai(aj,ac,ad,ak)assert(type(aj)=='number'and aj>0,'duration must be a positive number. Was '..tostring(aj))local al=type(ac)assert(al=='table'or al=='userdata','subject must be a table or userdata. Was '..tostring(ac))assert(type(ad)=='table','target must be a table. Was '..tostring(ad))assert(type(ak)=='function','easing must be a function. Was '..tostring(ak))ab(ac,ad)end;local function am(ak)ak=ak or'linear'if type(ak)=='string'then local an=ak;ak=a.easing[an]if type(ak)~='function'then error('The easing function name \''..an..'\' is invalid')end end;return ak end;local function ao(ac,ad,ap,aq,aj,ak)local j,k,l,m;for a9,aa in pairs(ad)do if type(aa)=='table'then ao(ac[a9],aa,ap[a9],aq,aj,ak)else j,k,l,m=aq,ap[a9],aa-ap[a9],aj;ac[a9]=ak(j,k,l,m)end end end;local ar={}local as={__index=ar}function ar:set(aq)assert(type(aq)=='number','clock must be a positive number or 0')self.initial=self.initial or a4({},self.target,self.subject)self.clock=aq;if self.clock<=0 then self.clock=0;a4(self.subject,self.initial)elseif self.clock>=self.duration then self.clock=self.duration;a4(self.subject,self.target)else ao(self.subject,self.target,self.initial,self.clock,self.duration,self.easing)end;return self.clock>=self.duration end;function ar:reset()return self:set(0)end;function ar:update(at)assert(type(at)=='number','dt must be a number')return self:set(self.clock+at)end;function a.new(aj,ac,ad,ak)ak=am(ak)ai(aj,ac,ad,ak)return setmetatable({duration=aj,subject=ac,target=ad,easing=ak,clock=0},as)end;return a
			end)()

			local m_inbetweening_worker
			local m_xy = { 5, 800 }
			local m_default_position = { 25, ({ client_screen_size() })[2] * 0.55 }

			local icliententitylist_get_client_entity = vtable_bind( 'client.dll', 'VClientEntityList003', 3, 'void*(__thiscall*)(void*, int)' )
			local c_weapon_get_muzzle_index_firstperson = vtable_thunk( 468, 'int(__thiscall*)(void*, void*)' )
			local c_entity_get_attachment = vtable_thunk( 84, 'bool(__thiscall*)(void*, int, Vector&)' )

			local m_thirdperson_reference, m_thirdperson_key_reference = ui_reference( 'visuals', 'effects', 'force third person (alive)' )

			local m_get_muzzle_position = function( me )
				if entity_get_prop( me, 'm_bIsScoped' ) == 1 and not ui_get( g_statistics_attach_while_scoped ) then
					return false
				end
				local active_weapon = entity_get_player_weapon( me )
				local viewmodel = entity_get_prop( me, 'm_hViewModel[0]' )
				if not active_weapon or not viewmodel then
					return false
				end
				local weapon_ptr, viewmodel_ptr = icliententitylist_get_client_entity( active_weapon ), icliententitylist_get_client_entity( viewmodel )
				if not weapon_ptr or not viewmodel_ptr then
					return false
				end
				local ret = vector( 0, 0, 0 )
				local muzzle_attachment_idx = c_weapon_get_muzzle_index_firstperson( weapon_ptr, viewmodel_ptr )
				local succeeded = c_entity_get_attachment( viewmodel_ptr, muzzle_attachment_idx, ret )
				return succeeded, ret
			end

			local m_inversion_progress = 0 -- I know I should use easing for this, however I will not

			return function()
				local current_display_size = m_display_sizes[ui_get( g_statistics_style )]
				if m_inbetweening_worker then
					m_inbetweening_worker:update( globals_absoluteframetime() * 1.5 )
				end
				local me = entity_get_local_player()
				if not me or not entity_is_alive( me ) then
					m_inbetweening_worker = m_inbetweening.new( 0.75, m_xy, m_default_position, 'linear' )
					return m_xy[1], m_xy[2]
				end
				local world_origin_position
				local is_third_person = ui_get( m_thirdperson_reference ) and ui_get( m_thirdperson_key_reference )
				if not is_third_person then
					local success, position = m_get_muzzle_position( me )
					if success then
						world_origin_position = position
					end
				else
					world_origin_position = vector( entity_hitbox_position( me, 6 ) )
				end
				local start_position_x, start_position_y
				local position_target = m_default_position
				local should_draw_glowline = false
				local should_invert = false
				if world_origin_position then
					should_draw_glowline = true
					local w2s_x, w2s_y = renderer_world_to_screen( world_origin_position:unpack() )
					if w2s_x and w2s_y then
						local m_offset_x_firstperson, m_offset_y_firstperson = ui_get( g_statistics_offset_x_firstperson ), ui_get( g_statistics_offset_y_firstperson ) * -1
						local m_offset_x_thirdperson, m_offset_y_thirdperson = ui_get( g_statistics_offset_x_thirdperson ), ui_get( g_statistics_offset_y_thirdperson ) * -1
						local render_offset_x, render_offset_y = unpack( (is_third_person and { m_offset_x_thirdperson, m_offset_y_thirdperson } or { m_offset_x_firstperson, m_offset_y_firstperson }) )
						should_invert = m_xy[1] < w2s_x
						if should_invert then
							m_inversion_progress = math_min( 1, m_inversion_progress + globals_absoluteframetime() * 6 )
						else
							m_inversion_progress = math_max( 0, m_inversion_progress - globals_absoluteframetime() * 6 )
						end
						local current_scale = m_scaling_multipliers[ui_get( m_dpi_scale_reference )]
						render_offset_x, render_offset_y = render_offset_x * current_scale, render_offset_y * current_scale
						position_target = { w2s_x + render_offset_x, w2s_y + render_offset_y }
						start_position_x, start_position_y = w2s_x, w2s_y
					end
				end
				m_inbetweening_worker = m_inbetweening.new( 0.75, m_xy, position_target, 'linear' )
				if should_draw_glowline then
					local r, g, b = ui_get( g_accent_color_picker )
					m_render_engine.render_glow_line( start_position_x, start_position_y, m_xy[1], m_xy[2], 255, 255, 255, 45, r, g, b, 8 )
				end
				return (should_draw_glowline and m_xy[1] - current_display_size.m_last_width * m_inversion_progress or m_xy[1]), m_xy[2] - current_display_size.m_last_height * 0.5
			end
		end)(),
		['Draggable'] = (function()
			local m_drag_start_x, m_drag_start_y, m_dragging = 0, 0, false
			return function()
				local render_table_ptr = m_global_data_ptr.m_renderer_data
				local mouse_down, mouse_x, mouse_y = client_key_state( 1 ), ui_mouse_position()
				local display_sizes = m_display_sizes[ui_get( g_statistics_style )]
				local can_drag = mouse_down and not m_dragging and mouse_x > render_table_ptr.m_draggable_position_x and mouse_x < render_table_ptr.m_draggable_position_x + display_sizes.m_last_width and mouse_y > render_table_ptr.m_draggable_position_y and mouse_y < render_table_ptr.m_draggable_position_y + display_sizes.m_last_height
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
		['-'] = function() end
	}

	local m_draw_container = function( x, y )
		local r, g, b = ui_get( g_accent_color_picker )
		local display_mode = m_display_sizes[ui_get( g_statistics_style )]
		local scaling_multiplier = m_scaling_multipliers[ui_get( m_dpi_scale_reference )]
		local w, h = display_mode.m_display_width * scaling_multiplier, display_mode.m_display_height * scaling_multiplier
		display_mode.m_last_width, display_mode.m_last_height = w, h
		m_render_engine.render_container( m_round_number( x ), m_round_number( y ), m_round_number( w ), m_round_number( h ), r, g, b, 255, display_mode.m_container_callback )
	end

	local m_paint = function()
		if not m_render_aim_data_ptr.m_ready then
			return
		end
		local current_container_selection = ui_get( g_statistics_display )
		local render_position_x, render_position_y = m_render_position_funcs[current_container_selection]()
		if not render_position_x then
			return
		end
		m_draw_container( render_position_x, render_position_y )
	end

	return { on_paint = m_paint }
end)()

local g_statistic_console = (function()
	local m_aimbot_data_out, m_aimbot_database = select( 2, g_aimbot_worker.get_database_ptr( ) )

	local m_flag_names = { 'First shot', 'Lethal', 'High priority', 'Anti-exploit', 'Shifting tickbase', 'Defensive DT', 'Safe point' }
	local m_time_lookup_table = { 'Last 30 min', 'Last hour', 'Last 3 hours', 'Last 24 hours', 'Last week', 'All time' }

	local m_label_most_common_weapon = ui_new_label( 'rage', 'other', 'Most used weapon: N/A' )
	local m_label_aim_accuracy = ui_new_label( 'rage', 'other', 'Aimbot accuracy: N/A' )
	local m_label_average_hit_chance = ui_new_label( 'rage', 'other', 'Average hit chance: N/A' )
	local m_label_average_backtrack = ui_new_label( 'rage', 'other', 'Average backtrack: N/A' )
	local m_label_average_shots_per_kill = ui_new_label( 'rage', 'other', 'Average shots taken per kill: N/A' )

	local m_visibility_switch = ui_new_checkbox( 'rage', 'other', 'Show aimbot statistics' )
	local m_filters = ui_new_multiselect( 'rage', 'other', 'Filter out', { 'Warmup', 'Bot', 'No lag compensation', 'sv_cheats 1' } )

	local m_flags = ui_new_multiselect( 'rage', 'other', 'Highlight shot flags', m_flag_names )

	local m_time_since_shot = ui_new_slider( 'rage', 'other', 'Select shots from', 1, 6, 6, true, '', 6, m_time_lookup_table )
	local m_displayed_data = ui_new_combobox( 'rage', 'other', 'Displayed statistics', { 'Hits', 'Misses' } )
	local m_correction_only = ui_new_checkbox( 'rage', 'other', 'Correction statistics only' )
	local m_output_to_console = ui_new_button( 'rage', 'other', 'Display statistics', function( ) end )
	local m_export_json = ui_new_button( 'rage', 'other', 'Export to clipboard', function( ) end )

	local m_table_filter = function( tbl, fn )
		local ret, ret_it = {}, 1;
		for k, v in pairs( tbl ) do
			if fn( v ) then
				ret[ret_it] = v;
				ret_it = ret_it + 1;
			end
		end
		return ret
	end

	local m_table_transform = function( t, t2 )
		local ret, ret_it = {}, 1;
		for iter, v in ipairs( t ) do
			if t2[v] then
				ret[ret_it] = t2[v]
				ret_it = ret_it + 1
			end
		end
		return ret
	end

	local m_find_aimbot_shots = function( time_since_shot, selected_filters, selected_flags, correction_only )
		if #m_aimbot_database == 0 then
			return {}, 'Aimbot data table empty!'
		end
		local unixtime = client_unix_time()
		local unixtime_lookup = ({ unixtime - 1800, unixtime - 3600, unixtime - 10800, unixtime - 86400, unixtime - 604800, 0 })[time_since_shot]

		local filters = m_table_transform( selected_filters, { ['Warmup'] = 'w', ['Bot'] = 'b', ['No lag compensation'] = 'x', ['sv_cheats 1'] = 'c' } )

		local filter_aimbot_shot_fn = function( shot_data )
			if shot_data.m_unixtime < unixtime_lookup then
				return false
			end
			for iter, v in ipairs( filters ) do
				if shot_data.m_filters:match( v ) then
					return false
				end
			end
			if correction_only then
				return (shot_data.m_result == 'hit' or shot_data.m_result_specific_data['miss'].m_miss_reason == '?')
			end
			return true
		end

		local new_table = m_table_filter( m_aimbot_database, filter_aimbot_shot_fn )
		if #new_table == 0 then
			return {}, 'No shots found matching criteria!'
		end
		local ret = { m_shots = {} }
		local flag_table = {};
		for iter, name in ipairs( m_flag_names ) do
			flag_table[name] = false
		end
		for iter, fl in ipairs( selected_flags ) do
			flag_table[fl] = true
		end
		for iter, shot_data in ipairs( new_table ) do
			for iter2, shot_flag in ipairs( shot_data.m_flags ) do
				if flag_table[shot_flag] then
					if not ret[shot_flag] then
						ret[shot_flag] = {}
					end
					ret[shot_flag][#ret[shot_flag] + 1] = shot_data
				end
			end
			ret.m_shots[#ret.m_shots + 1] = shot_data
		end
		return ret
	end

	local m_get_sorted_keys = function( t, excluded_key ) -- i could make it work with several excluded keys but i don't give a shit
		local ret, ret_it = {}, 1
		for k in pairs( t ) do
			if not excluded_key or k ~= excluded_key then
				ret[ret_it] = k
				ret_it = ret_it + 1
			end
		end
		table_sort( ret )
		return ret
	end

	local m_generate_hit_unicode_table = function( shot_table )
		local keys = m_get_sorted_keys( shot_table, 'm_shots' );
		keys[#keys + 1] = 'Total' -- i know this is dirty

		local gen_str = function( shots, hits, group ) -- stolen :)
			if shots[group] == 0 and hits[group] == 0 then
				return 'No data'
			end
			return ('%.1f%% (%d/%d)'):format( (hits[group] / math_max( 1, shots[group] )) * 100, hits[group], shots[group] )
		end

		local process_category = function( key )
			local shots_tbl, hits_tbl = { head = 0, body = 0, limbs = 0, total = 0 }, { head = 0, body = 0, limbs = 0, total = 0 }
			for iter, shot_data in ipairs( shot_table[key] or shot_table['m_shots'] ) do
				shots_tbl.total = shots_tbl.total + 1
				shots_tbl[shot_data.m_hitgroup_class] = shots_tbl[shot_data.m_hitgroup_class] + 1
				if shot_data.m_result == 'hit' then
					hits_tbl.total = hits_tbl.total + 1
					hits_tbl[shot_data.m_hitgroup_class] = hits_tbl[shot_data.m_hitgroup_class] + 1
				end
			end
			return hits_tbl, shots_tbl
		end
		local rows, headings = {}, { 'Case', 'Head', 'Body', 'Limbs', 'Total accuracy' }
		for iter, key in ipairs( keys ) do
			local hit_counts, shot_counts = process_category( key )
			rows[#rows + 1] = { key, gen_str( shot_counts, hit_counts, 'head' ), gen_str( shot_counts, hit_counts, 'body' ), gen_str( shot_counts, hit_counts, 'limbs' ), gen_str( shot_counts, hit_counts, 'total' ) }
		end
		return rows, headings
	end

	local m_generate_miss_unicode_table = function( shot_table )
		local keys = m_get_sorted_keys( shot_table, 'm_shots' );
		keys[#keys + 1] = 'Total' -- i know this is dirty

		local gen_str = function( misses, group, total_shots )
			local total_misses = misses.total
			if misses[group] == 0 or total_misses == 0 then
				return 'No data'
			end
			if group == 'total' then
				return ('%.1f%% (%d/%d)'):format( (total_misses / math_max( 1, total_shots )) * 100, total_misses, total_shots )
			end
			return ('%.1f%% (%d/%d)'):format( (misses[group] / math_max( 1, total_misses )) * 100, misses[group], total_misses )
		end

		local process_category = function( key )
			local miss_tbl, total_shots = { ['spread'] = 0, ['?'] = 0, ['prediction error'] = 0, ['unregistered shot'] = 0, ['death'] = 0, total = 0 }, 0
			for iter, shot_data in ipairs( shot_table[key] or shot_table['m_shots'] ) do
				total_shots = total_shots + 1
				if shot_data.m_result == 'miss' then
					miss_tbl.total = miss_tbl.total + 1
					miss_tbl[shot_data.m_result_specific_data['miss'].m_miss_reason] = miss_tbl[shot_data.m_result_specific_data['miss'].m_miss_reason] + 1
				end
			end

			return miss_tbl, total_shots
		end
		local rows, headings = {}, { 'Case', 'Spread', '?', 'Pred. error', 'Unreg. shot', 'Death', 'Total' }
		for iter, key in ipairs( keys ) do
			local tbl, total_shots = process_category( key )
			rows[#rows + 1] = { key, gen_str( tbl, 'spread' ), gen_str( tbl, '?' ), gen_str( tbl, 'prediction error' ), gen_str( tbl, 'unregistered shot' ), gen_str( tbl, 'death' ), gen_str( tbl, 'total', total_shots ) }
		end
		return rows, headings
	end

	local m_poll_aim_data_update = (function()
		local m_weapon_shot_counters = {}
		return function( aim_data )
			if not aim_data then
				for iter, shot in pairs( m_aimbot_database ) do -- bit of a bug i had here, my fault, however i cant be fucked to reset my own shot table
					m_weapon_shot_counters[shot.m_used_weapon] = (m_weapon_shot_counters[shot.m_used_weapon] or 0) + 1
				end
			else
				m_weapon_shot_counters[aim_data.m_used_weapon] = (m_weapon_shot_counters[aim_data.m_used_weapon] or 0) + 1
			end
			local most_used_weapon, usecount = 'N/A', 0
			for name, count in pairs( m_weapon_shot_counters ) do
				if usecount < count then
					most_used_weapon = name
					usecount = count
				end
			end
			for iter, v in ipairs( { { m_label_most_common_weapon, 'Most common weapon: %s (%d shots taken)', { most_used_weapon, usecount } }, { m_label_aim_accuracy, 'Total accuracy: %.1f%% (%d/%d)', { (m_aimbot_data_out.m_hits.m_total_hits / math_max( 1, m_aimbot_data_out.m_total_fired_shots )) * 100, m_aimbot_data_out.m_hits.m_total_hits, m_aimbot_data_out.m_total_fired_shots } }, { m_label_average_backtrack, 'Average backtrack: %dms', { g_get_avg_from_table( m_aimbot_data_out.m_additional_data.m_backtracks ) * 1000 } }, { m_label_average_hit_chance, 'Average hit chance: %d%%', { g_get_avg_from_table( m_aimbot_data_out.m_additional_data.m_hitchances ) } }, { m_label_average_shots_per_kill, 'Average shots per kill: %.1f shots', { m_aimbot_data_out.m_total_fired_shots / math_max( 1, m_aimbot_data_out.m_total_kills ) } } } ) do
				local ref, str, args = unpack( v )
				ui_set( ref, str:format( unpack( args ) ) )
			end
		end
	end)()

	m_poll_aim_data_update()

	client_set_event_callback( 'aimbot_logger_finalize', m_poll_aim_data_update )

	local m_display_aimbot_data = function()
		local time_since_shot = ui_get( m_time_since_shot )
		local selected_filters = ui_get( m_filters )
		local selected_flags = ui_get( m_flags )
		local displayed_data = ui_get( m_displayed_data )
		local is_correction_only = ui_get( m_correction_only )

		if displayed_data == 'Misses' and is_correction_only then
			client_error_log( 'Correction statistics cannot show miss data!' )
			return
		end

		local shot_table, error_str = m_find_aimbot_shots( time_since_shot, selected_filters, selected_flags, is_correction_only )

		if error_str then
			client_error_log( error_str )
			return
		end

		local rows, headings = ({ ['Hits'] = m_generate_hit_unicode_table, ['Misses'] = m_generate_miss_unicode_table })[displayed_data]( shot_table, is_correction_only )

		client_log( ('Displaying %d shots from: %s%s%s'):format( #shot_table.m_shots, m_time_lookup_table[time_since_shot], (#selected_filters > 0 and (' (Filtered out: %s)'):format( table_concat( selected_filters, ', ' ) ) or ''), (#selected_flags > 0 and (' (Flags: %s)'):format( table_concat( selected_flags, ', ' ) ) or '') ) )

		if is_correction_only then
			client_log( 'Used correction statistics mode for analysis!' )
		end

		client_log( '\n', table_gen( rows, headings, 'Unicode (Single Line)' ) )
	end

	local m_visibility = function()
		local state = ui_get( m_visibility_switch )

		for iter, item in ipairs( { m_filters, m_flags, m_time_since_shot, m_displayed_data, m_correction_only, m_output_to_console, m_export_json } ) do
			ui_set_visible( item, state )
		end
	end

	local m_export_json_fn = function( )
		local success, str = pcall( pretty_json.stringify, m_aimbot_database )

		if not success then
			client_error_log( ( 'Failed to export, error %s' ):format( str ) )
			return
		end

		clipboard.set( str )
	end

	m_visibility( )

	ui_set_callback( m_visibility_switch, m_visibility )
	ui_set_callback( m_output_to_console, m_display_aimbot_data )
	ui_set_callback( m_export_json, m_export_json_fn )
end)()

local g_paint_callback = function()
	g_container_manager.on_paint()
	g_log_worker.on_paint()
end

local g_handle_visibility = function()
	local is_enabled = ui_get( g_master_switch ) -- not always called from g_ui_callback
	local statistics_display_selection = ui_get( g_statistics_display )
	local is_attached_to_player = statistics_display_selection == 'Attached to player'

	for iter, data in ipairs( { { g_event_logger, is_enabled }, { g_statistics_display, is_enabled }, { g_statistics_style, is_enabled and statistics_display_selection ~= '-' }, { g_accent_color_picker, is_enabled }, { g_erase_statistics, is_enabled }, { g_statistics_attach_while_scoped, is_enabled and is_attached_to_player }, { g_statistics_offset_label_firstperson, is_enabled and is_attached_to_player }, { g_statistics_offset_x_firstperson, is_enabled and is_attached_to_player }, { g_statistics_offset_y_firstperson, is_enabled and is_attached_to_player }, { g_statistics_offset_label_thirdperson, is_enabled and is_attached_to_player }, { g_statistics_offset_x_thirdperson, is_enabled and is_attached_to_player }, { g_statistics_offset_y_thirdperson, is_enabled and is_attached_to_player } } ) do
		ui_set_visible( unpack( data ) )
	end
end

local g_ui_callback = function()
	g_handle_visibility()

	local fn = client[('%sset_event_callback'):format( ui_get( g_master_switch ) and '' or 'un' )]
	for iter, callback_data in ipairs( { { 'aim_fire', g_aimbot_worker.on_aim_fire }, { 'aim_hit', g_aimbot_worker.on_aim_hit }, { 'aim_miss', g_aimbot_worker.on_aim_miss }, { 'bullet_impact', g_aimbot_worker.on_bullet_impact }, { 'paint', g_paint_callback } } ) do
		fn( unpack( callback_data ) )
	end
end

for iter, item in ipairs( { g_event_logger, g_statistics_display, g_statistics_style, g_statistics_attach_while_scoped, g_statistics_offset_label_firstperson, g_statistics_offset_x_firstperson, g_statistics_offset_y_firstperson, g_accent_color_picker } ) do
	ui_set_callback( item, g_handle_visibility )
end

g_ui_callback()
ui_set_callback( g_master_switch, g_ui_callback )