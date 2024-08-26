obs = obslua
source_name = ""
total_seconds = 0
cur_seconds = 0
last_text = ""
stop_text = ""
activated = false
short_break_duration = 300
long_break_duration = 900
pomodoro_duration = 1500
current_session = "work"
session_count = 0
custom_message = ""
break_message = ""
paused = false

-- Function to set the time text
function set_time_text()
    local seconds = math.floor(cur_seconds % 60)
    local total_minutes = math.floor(cur_seconds / 60)
    local minutes = math.floor(total_minutes % 60)
    local hours = math.floor(total_minutes / 60)
    local text = string.format("%02d:%02d", minutes, seconds)

    if cur_seconds < 1 then
        text = custom_message
        next_session()
    end

    if text ~= last_text then
        local source = obs.obs_get_source_by_name(source_name)
        if source ~= nil then
            local settings = obs.obs_data_create()
            obs.obs_data_set_string(settings, "text", text)
            obs.obs_source_update(source, settings)
            obs.obs_data_release(settings)
            obs.obs_source_release(source)
        end
    end

    last_text = text
end

function timer_callback()
    if not paused then
        cur_seconds = cur_seconds - 1
        if cur_seconds < 0 then
            obs.remove_current_callback()
            cur_seconds = 0
        end

        set_time_text()
    end
end

function activate(activating)
    if activated == activating then
        return
    end

    activated = activating

    if activating then
        cur_seconds = total_seconds
        set_time_text()
        obs.timer_add(timer_callback, 1000)
    else
        obs.timer_remove(timer_callback)
    end
end

-- Called when a source is activated/deactivated
function activate_signal(cd, activating)
    local source = obs.calldata_source(cd, "source")
    if source ~= nil then
        local name = obs.obs_source_get_name(source)
        if (name == source_name) then
            activate(activating)
        end
    end
end

function source_activated(cd)
    activate_signal(cd, true)
end

function source_deactivated(cd)
    activate_signal(cd, false)
end

function reset(pressed)
    if not pressed then
        return
    end

    activate(false)
    current_session = "work"
    session_count = 0
    total_seconds = pomodoro_duration
    custom_message = ""
    cur_seconds = total_seconds
    activate(true)
end

function next_session()
    if current_session == "work" then
        session_count = session_count + 1
        if session_count % 3 == 0 then
            current_session = "long_break"
            custom_message = break_message .. " (Long Break)"
            total_seconds = long_break_duration
        else
            current_session = "short_break"
            custom_message = break_message .. " (Short Break)"
            total_seconds = short_break_duration
        end
    elseif current_session == "short_break" or current_session == "long_break" then
        current_session = "work"
        custom_message = ""
        total_seconds = pomodoro_duration
    end

    cur_seconds = total_seconds
    activate(true)
end

function reset_button_clicked(props, p)
    reset(true)
    return false
end

function start_button_clicked(props, p)
    paused = false
    activate(true)
    return false
end

function pause_button_clicked(props, p)
    paused = true
    return false
end

-- A function named script_properties defines the properties that the user
-- can change for the entire script module itself
function script_properties()
    local props = obs.obs_properties_create()

    local p = obs.obs_properties_add_list(props, "source", "Text Source", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
    local sources = obs.obs_enum_sources()
    if sources ~= nil then
        for _, source in ipairs(sources) do
            local source_id = obs.obs_source_get_unversioned_id(source)
            if source_id == "text_gdiplus" or source_id == "text_ft2_source" then
                local name = obs.obs_source_get_name(source)
                obs.obs_property_list_add_string(p, name, name)
            end
        end
    end
    obs.source_list_release(sources)

    obs.obs_properties_add_int(props, "pomodoro_duration", "Pomodoro Duration (minutes)", 1, 100000, 1)
    obs.obs_properties_add_int(props, "short_break_duration", "Short Break Duration (minutes)", 1, 100000, 1)
    obs.obs_properties_add_int(props, "long_break_duration", "Long Break Duration (minutes)", 1, 100000, 1)

    obs.obs_properties_add_text(props, "stop_text", "Final Text", obs.OBS_TEXT_DEFAULT)
    obs.obs_properties_add_text(props, "break_message", "Break Message", obs.OBS_TEXT_DEFAULT)
    
    obs.obs_properties_add_button(props, "start_button", "Start Timer", start_button_clicked)
    obs.obs_properties_add_button(props, "pause_button", "Pause Timer", pause_button_clicked)
    obs.obs_properties_add_button(props, "reset_button", "Reset Timer", reset_button_clicked)

    return props
end

-- A function named script_description returns the description shown to
-- the user
function script_description()
    return "Pomodoro Timer with customizable break durations, long breaks after every 2 short breaks, and custom messages during breaks.\n\nMade by Ritvik"
end

-- A function named script_update will be called when settings are changed
function script_update(settings)
    activate(false)

    source_name = obs.obs_data_get_string(settings, "source")
    pomodoro_duration = obs.obs_data_get_int(settings, "pomodoro_duration") * 60
    short_break_duration = obs.obs_data_get_int(settings, "short_break_duration") * 60
    long_break_duration = obs.obs_data_get_int(settings, "long_break_duration") * 60
    stop_text = obs.obs_data_get_string(settings, "stop_text")
    break_message = obs.obs_data_get_string(settings, "break_message")

    reset(true)
end

-- A function named script_defaults will be called to set the default settings
function script_defaults(settings)
    obs.obs_data_set_default_int(settings, "pomodoro_duration", 25)
    obs.obs_data_set_default_int(settings, "short_break_duration", 5)
    obs.obs_data_set_default_int(settings, "long_break_duration", 15)
    obs.obs_data_set_default_string(settings, "stop_text", "Starting soon (tm)")
    obs.obs_data_set_default_string(settings, "break_message", "Take a break!")
end

-- A function named script_save will be called when the script is saved
function script_save(settings)
    local hotkey_save_array = obs.obs_hotkey_save(hotkey_id)
    obs.obs_data_set_array(settings, "reset_hotkey", hotkey_save_array)
    obs.obs_data_array_release(hotkey_save_array)
end

-- A function named script_load will be called on startup
function script_load(settings)
    local sh = obs.obs_get_signal_handler()
    obs.signal_handler_connect(sh, "source_activate", source_activated)
    obs.signal_handler_connect(sh, "source_deactivate", source_deactivated)

    hotkey_id = obs.obs_hotkey_register_frontend("reset_timer_thingy", "Reset Timer", reset)
    local hotkey_save_array = obs.obs_data_get_array(settings, "reset_hotkey")
    obs.obs_hotkey_load(hotkey_id, hotkey_save_array)
    obs.obs_data_array_release(hotkey_save_array)
end