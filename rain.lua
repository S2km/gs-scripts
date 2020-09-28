--  pasted from UC
--  also it crashes a lot
--  you probably should not be using it

local ffi = require("ffi")

ffi.cdef[[
    typedef void*(*create_client_class_fn)(int, int);
    typedef void*(*create_event_fn)();

    typedef struct {
        create_client_class_fn create_fn;
        create_event_fn ev_fn;
        char* network_name;
        void* recv_table;
        void* next;
        int class_id;
    } client_class_t;

    typedef struct {
        float x;
        float y;
        float z;
    } vec3_t;

    typedef void(__thiscall* pre_data_update_fn)(void*, int);
    typedef void(__thiscall* pre_data_change_fn)(void*, int);

    typedef void***(__thiscall* get_collideable_fn)(void*);
    
    typedef vec3_t*(__thiscall* get_collideable_mins_fn)(void*);
    typedef vec3_t*(__thiscall* get_collideable_maxs_fn)(void*);

    typedef void(__thiscall* post_data_change_fn)(void*, int);
    typedef void(__thiscall* post_data_update_fn)(void*, int);

    typedef void(__thiscall* release_entity_fn)(void*);

    typedef void***(__thiscall* get_client_whatever_fn)(void*);
]]

local checkbox = ui.new_checkbox("VISUALS", "Effects", "Weather")
local selected_effect = ui.new_combobox("VISUALS", "Effects", "Desired weather", {"Rain", "Snow"})

local visibility_callback = function(ref)
    ui.set_visible(selected_effect, ui.get(ref))
end

visibility_callback(checkbox)
ui.set_callback(checkbox, visibility_callback)

local client_interface = ffi.cast("void***", client.create_interface("client.dll", "VClient018"))
local entlist_interface = ffi.cast("void***", client.create_interface("client.dll", "VClientEntityList003"))

local get_all_classes_fn = ffi.cast("client_class_t*(__thiscall*)(void*)", client_interface[0][8])
local get_entity_pointer_fn = ffi.cast("void*(__thiscall*)(void*, int)", entlist_interface[0][3])

local MAX_EDICTS = 2048
local MAX_POSITION_FLT = 16384

local precipitation_handler = {
    created_rain = false,
    rain_entity_networkable = nil,
    rain_entity = nil,
    precipitation_client_class = nil,
    desired_effect = 0,

    pre_render = function(self)
        if ui.get(checkbox) and entity.get_local_player() then
            local selected_effect = ui.get(selected_effect) == "Rain" and 0 or 1
            if not self.precipitation_client_class then
                local cur_class = get_all_classes_fn(client_interface)
                while(cur_class) do
                    if cur_class.class_id ==  137 then
                        self.precipitation_client_class = cur_class
                        break
                    end
                    if not cur_class.next then break end
                    cur_class = ffi.cast("client_class_t*", cur_class.next)
                end
            end
            if not self.created_rain and self.precipitation_client_class and self.precipitation_client_class.create_fn then
                self.rain_entity_networkable = ffi.cast("void***", self.precipitation_client_class.create_fn(MAX_EDICTS - 1, 0))
                if self.rain_entity_networkable then
                    self.rain_entity = ffi.cast("void***", get_entity_pointer_fn(entlist_interface, MAX_EDICTS - 1))
                    entity.set_prop(MAX_EDICTS - 1, "m_nPrecipType", selected_effect) --Not actually too sure on this working.

                    ffi.cast("pre_data_update_fn", self.rain_entity_networkable[0][6])(self.rain_entity_networkable, 0)
                    ffi.cast("pre_data_change_fn", self.rain_entity_networkable[0][4])(self.rain_entity_networkable, 0)
                    
                    local collideable = ffi.cast("get_collideable_fn", self.rain_entity[0][3])(self.rain_entity)

                    if collideable then
                        local mins = ffi.cast("get_collideable_mins_fn", collideable[0][1])(collideable)
                        local maxs = ffi.cast("get_collideable_maxs_fn", collideable[0][2])(collideable)

                        if mins and maxs then
                            mins.x, mins.y, mins.z = -MAX_POSITION_FLT, -MAX_POSITION_FLT, -MAX_POSITION_FLT
                            maxs.x, maxs.y, maxs.z = MAX_POSITION_FLT, MAX_POSITION_FLT, MAX_POSITION_FLT
                        end
                    end

                    ffi.cast("post_data_change_fn", self.rain_entity_networkable[0][5])(self.rain_entity_networkable, 0)
                    ffi.cast("post_data_update_fn", self.rain_entity_networkable[0][7])(self.rain_entity_networkable, 0)

                    self.created_rain = true
                    self.desired_effect = selected_effect
                end
            end
            if self.created_rain and self.desired_effect ~= selected_effect then
                entity.set_prop(MAX_EDICTS - 1, "m_nPrecipType", selected_effect)
                self.desired_effect = selected_effect
            end
        else if entity.get_local_player() and not ui.get(checkbox) and self.created_rain then
            self.created_rain = false
            self.precipitation_client_class = nil

            local client_unknown = ffi.cast("get_client_whatever_fn", self.rain_entity_networkable[0][0])(self.rain_entity_networkable)
            local client_thinkable = ffi.cast("get_client_whatever_fn", client_unknown[0][8])(client_unknown)

            ffi.cast("release_entity_fn", client_thinkable[0][4])(client_thinkable)

            self.rain_entity_networkable = nil
            self.rain_entity = nil
        else
            self.created_rain = false
            self.precipitation_client_class = nil
            self.rain_entity_networkable = nil
            self.rain_entity = nil
        end
    end
    end,

    shutdown = function(self)
        if self.created_rain and self.precipitation_client_class and self.rain_entity_networkable then
            local client_unknown = ffi.cast("get_client_whatever_fn", self.rain_entity_networkable[0][0])(self.rain_entity_networkable)
            local client_thinkable = ffi.cast("get_client_whatever_fn", client_unknown[0][8])(client_unknown)

            ffi.cast("release_entity_fn", client_thinkable[0][4])(client_thinkable)
        end
    end
}

client.set_event_callback("pre_render", function()
    precipitation_handler:pre_render()
end)

client.set_event_callback("shutdown", function()
    precipitation_handler:shutdown()
end)
