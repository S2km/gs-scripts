-- local variables for API functions. any changes to the line below will be lost on re-generation
local client_delay_call, client_set_event_callback, client_unset_event_callback, client_log, client_color_log, client_userid_to_entindex, entity_get_local_player, entity_get_player_name, globals_chokedcommands, globals_lastoutgoingcommand, globals_tickinterval, ui_get, ui_new_checkbox, ui_set_callback, type, unpack, setmetatable = client.delay_call, client.set_event_callback, client.unset_event_callback, client.log, client.color_log, client.userid_to_entindex, entity.get_local_player, entity.get_player_name, globals.chokedcommands, globals.lastoutgoingcommand, globals.tickinterval, ui.get, ui.new_checkbox, ui.set_callback, type, unpack, setmetatable

local g_aim_hit_commands = { }

local g_aim_hit = function( ev )
    local command_number = globals_lastoutgoingcommand( ) + globals_chokedcommands( ) + 1

    g_aim_hit_commands[ command_number ] = true

    client_delay_call( 0.2, table.remove, g_aim_hit_commands, command_number )
end

local g_verbs = setmetatable( { ["hegrenade"] = "Naded", ["inferno"] = "Burnt", ["knife"] = "Shanked" }, { __index = function( ) return "Hit" end } )
local g_hitgroups = setmetatable( { 'head', 'chest', 'stomach', 'left arm', 'right arm', 'left leg', 'right leg', 'neck' }, { __index = function( ) return "body" end } ) -- yes, metatables are slow. cope. i WILL do it this way and there is nothing you can do to stop me.
local g_palette = { [ "red" ] = { 255, 0, 0 }, [ "green" ] = { 173, 250, 47 } }

local g_output = function( ) end
client_set_event_callback( "shutdown", function( ) client_unset_event_callback( "output", g_output ) end )

local g_emit_multicolored_text = function( ... )
    client_set_event_callback( "output", g_output )
    client_color_log( g_palette[ "green" ][ 1 ], g_palette[ "green" ][ 2 ], g_palette[ "green" ][ 3 ], "[gamesense] \0" )
    client_unset_event_callback( "output", g_output )

    for iter, printable in ipairs( { ... } ) do
        if type( printable ) == "string" then
            client_color_log( 255, 255, 255, printable, "\0" )
        else
            local r, g, b = unpack( g_palette[ printable.rgb ] )
            client_color_log( r, g, b, printable.text, "\0" )
        end
    end
    client_color_log( 255, 255, 255, " " )
end

local g_player_hurt_impl = function( ev, command_number )
    if g_aim_hit_commands[ command_number ] then
        return
    end

    local attacker, userid = client_userid_to_entindex( ev.attacker ), client_userid_to_entindex( ev.userid )
    local verb, hitgroup = g_verbs[ ev.weapon ], g_hitgroups[ ev.hitgroup ]

    local t = ( {
        [ attacker ] = {
            { rgb = "green", text = ( "%s %s" ):format( verb, entity_get_player_name( userid ) ) }, "'s ",
            { rgb = "green", text = hitgroup }, " for ",
            { rgb = "green", text = ev.dmg_health }, " HP (",
            { rgb = "green", text = ev.health }, " HP remaining)" },
        [ userid ] = { "Got ",
            { rgb = "red", text = verb:lower( ) }, " by ",
            { rgb = "red", text = ( attacker == 0 and "world" or entity_get_player_name( attacker ) ) }, " into ",
            { rgb = "red", text = hitgroup }, " for ",
            { rgb = "red", text = ev.dmg_health }, " HP (",
            { rgb = "red", text = ev.health }, " HP remaining)"
        }
    } )[ entity_get_local_player( ) ]

    if t then
        g_emit_multicolored_text( unpack( t ) )
    end
end

local g_player_hurt = function( ev )
    client_delay_call( globals_tickinterval( ), g_player_hurt_impl, ev, globals_lastoutgoingcommand( ) + globals_chokedcommands( ) + 1 ) -- player_hurt gets called before aim_hit - we need to delay the call to player_hurt for a bit of time
end

local g_master_switch = ui_new_checkbox( "lua", "a", "Log damage dealt ( better :) )" )

local g_ui_callback = function( )
    local fn = client[ ( "%sset_event_callback" ):format( ui_get( g_master_switch ) and "" or "un" ) ]

    fn( "aim_hit", g_aim_hit )
    fn( "player_hurt", g_player_hurt )
end

g_ui_callback( )
ui_set_callback( g_master_switch, g_ui_callback )