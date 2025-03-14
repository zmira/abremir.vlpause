--[[-------------- VLPause v0.6 ------------
"VLPause_ext.lua" > Put this VLC Extension Lua script file in \lua\extensions\ folder
--------------------------------------------
Requires "VLPause_intf.lua" > Put the VLC Interface Lua script file in \lua\intf\ folder

Simple instructions:
1) "VLPause_ext.lua" > Copy the VLC Extension Lua script file into \lua\extensions\ folder;
2) "VLPause_intf.lua" > Copy the VLC Interface Lua script file into \lua\intf\ folder;
3) Start the Extension in VLC menu "View > VLPause" on Windows/Linux or "Vlc > Extensions > VLPause" on Mac and configure to your liking.

Alternative activation of the Interface script:
* The Interface script can be activated from the CLI (batch script or desktop shortcut icon):
vlc.exe --extraintf=luaintf --lua-intf=VLPause_intf
* VLC preferences for automatic activation of the Interface script:
Tools > Preferences > Show settings=All > Interface >
> Main interfaces: Extra interface modules [luaintf]
> Main interfaces > Lua: Lua interface [VLPause_intf]

INSTALLATION directory (\lua\extensions\):
* Windows (all users): %ProgramFiles%\VideoLAN\VLC\lua\extensions\
* Windows (current user): %APPDATA%\VLC\lua\extensions\
* Linux (all users): /usr/lib/vlc/lua/extensions/
* Linux (current user): ~/.local/share/vlc/lua/extensions/
* Mac OS X (all users): /Applications/VLC.app/Contents/MacOS/share/lua/extensions/
* Mac OS X (current user): /Users/%your_name%/Library/Application Support/org.videolan.vlc/lua/extensions/
Create directory if it does not exist!
--]]----------------------------------------

local intf_tag = "VLPause_intf"

function descriptor()
    return {
        title = "VLPause";
        version = "0.6";
        author = "José Mira [abremir]";
        url = 'https://github.com/zmira/abremir.vlpause';
        description = [[
Pause for intermission.

VLPause allows you to configure when to automatically pause play for an intermission.
(Extension script "VLPause_ext.lua" + Interface script "VLPause_intf.lua")
]];
        capabilities = { "menu" }
    }
end

function activate()
    os.setlocale("C", "all") -- fixes numeric locale issue on Mac

    local _, VLC_luaintf, _, luaintf_index = get_vlc_intf_settings()

    if not luaintf_index or VLC_luaintf ~= intf_tag then
        trigger_menu(2)
    else 
        trigger_menu(1)
    end
end

function deactivate()
    vlc.deactivate()
end

function close()
    vlc.deactivate();
end

function menu()
    return { "Control panel", "Settings" }
end

function trigger_menu(id)
    if id == 1 then -- Normal menu
        initialize_gui()
    elseif id == 2 then -- Intf settings menu
        initialize_gui_intf()
    end
end

function initialize_gui_intf()
    vlpause_dialog = vlc.dialog(descriptor().title)
    
    enable_extraintf = vlpause_dialog:add_check_box("Enable interface: ", true, 1, 1, 2, 2)
    name_luaintf = vlpause_dialog:add_text_input(intf_tag, 3, 1, 2, 2)

    vlpause_dialog:add_button("Save", click_save_settings, 3, 3, 1, 2)
    vlpause_dialog:add_button("Cancel", click_cancel_settings, 4, 3, 1, 2)

    local _, VLC_luaintf, _, luaintf_index = get_vlc_intf_settings()
    lb_message = vlpause_dialog:add_label("Current status: " .. (luaintf_index and "ENABLED" or "DISABLED") .. " " .. tostring(VLC_luaintf), 1, 5, 4, 2)

    add_copyright_to_vlpause_dialog(1, 7, 4, 2)

    vlpause_dialog:show()
end

function click_save_settings()
    local _, _, intf_table, luaintf_index = get_vlc_intf_settings()

    if enable_extraintf:get_checked() then
        if not luaintf_index then
            table.insert(intf_table, "luaintf")
        end
        vlc.config.set("lua-intf", name_luaintf:get_text())
    else
        if luaintf_index then
            table.remove(intf_table, luaintf_index)
        end
    end
    vlc.config.set("extraintf", table.concat(intf_table, ":"))
    lb_message:set_text("Please restart VLC for changes to take effect!")
end

function click_cancel_settings()
    vlpause_dialog:delete()
    trigger_menu(1)
end

function get_vlc_intf_settings()
    local VLC_extraintf = vlc.config.get("extraintf") -- enabled VLC interfaces
    local VLC_luaintf = vlc.config.get("lua-intf") -- Lua Interface
    local intf_table = {}
    local luaintf_index = false
    if VLC_extraintf then
        intf_table = split_string(VLC_extraintf, ":")
        for index, value in ipairs(intf_table) do
            if value == "luaintf" then
                luaintf_index = index
                break
            end
        end
    end
    return VLC_extraintf, VLC_luaintf, intf_table, luaintf_index
end

function split_string(s, d)
    local t = {}
    local i = 1
    local ss, j, k
    local b = true
    while b do
        j,k = string.find(s,d,i)
        if j then
            ss = string.sub(s,i,j-1)
            i = k+1
        else
            ss = string.sub(s,i)
            b = false
        end
        table.insert(t, ss)
    end
    return t
end

function initialize_gui()
    local saved_number_of_intermissions = nil
    local auto_apply_calculated_intermissions_option = false
    local bookmark = get_vlpause_bookmark()
    local string_to_boolean = { ["true"] = true, ["false"] = false }

    if string.len(bookmark or "") > 0 then
        local bookmark_value = vlc.config.get(bookmark) or ""
        if starts_with(bookmark_value, "VLPAUSE=") then
            local vlpause_configuration = string.sub(bookmark_value, string.len("VLPAUSE=") + 1)
            local splitter_position = string.find(vlpause_configuration, ":")

            if splitter_position then
                saved_number_of_intermissions = string.sub(vlpause_configuration, 1, splitter_position - 1)
                auto_apply_calculated_intermissions_option = string_to_boolean[string.sub(vlpause_configuration, splitter_position + 1)]
            else
                saved_number_of_intermissions = vlpause_configuration
            end
        end
    end

    vlpause_dialog = vlc.dialog(descriptor().title)

    vlpause_dialog:add_label("Total time:", 1, 1, 4, 2)
    vlpause_dialog:add_label(get_formatted_duration(), 5, 1, 4, 2)

    vlpause_dialog:add_label("Calculated # of intermissions:", 1, 3, 4, 2)
    vlpause_dialog:add_label(get_calculated_number_of_intermissions(), 5, 3, 4, 2)

    auto_apply_calculated_intermissions = vlpause_dialog:add_check_box("Auto-apply calculated # of intermissions", auto_apply_calculated_intermissions_option, 1, 5, 8, 2)

    vlpause_dialog:add_label("# of intermissions:", 1, 7, 4, 2)
    vlpause_text_input = vlpause_dialog:add_text_input(saved_number_of_intermissions or "", 5, 7, 4, 2)

    vlpause_dialog:add_button("Apply", click_apply, 5, 9, 2, 2)
    vlpause_dialog:add_button("Cancel", click_cancel, 7, 9, 2, 2)

    add_copyright_to_vlpause_dialog(1, 11, 8, 2)

    vlpause_dialog:show()
end

function add_copyright_to_vlpause_dialog(column, row, hspan, vspan)
    vlpause_dialog:add_label("", column, row, hspan, vspan)
    vlpause_dialog:add_label(descriptor().title .. " v" .. descriptor().version .. " Copyright (c) 2024-" .. os.date("%Y") .. " " .. descriptor().author, column, row + 2, hspan, vspan)
end

function get_calculated_number_of_intermissions()
    local item = vlc.input.item()

    if not item then
        return "---"
    end

    local duration = item:duration() -- in seconds

    -- if duration is less than 1h15m (4500 = 1.25h * 60 * 60)
    -- then use 0 else subtract 1h15m from the duration and
    -- convert to hours (3600 = 1h * 60 * 60), round up to nearest integer
    return duration < 4500 and 0 or math.ceil((duration - 4500) / 3600)
end

function get_formatted_duration()
    local duration = "--:--:--"
    local item = vlc.input.item()

    if not item then
        return duration
    end

    local duration = item:duration() -- in seconds
    if duration > 0 then
        duration = time_to_string(duration)	
    end

    return duration
end

function click_cancel()
    vlpause_dialog:delete()
end

function click_apply()
    local manual_number_of_intermissions = tonumber(vlpause_text_input:get_text(), 10)

    if manual_number_of_intermissions == nil or manual_number_of_intermissions < 0 then
        manual_number_of_intermissions = 0
        vlpause_text_input:set_text("0")
    end

    local bookmark = get_vlpause_bookmark()

    if string.len(bookmark or "") > 0 then
        vlc.config.set(bookmark, "VLPAUSE=" .. manual_number_of_intermissions .. ":" .. tostring(auto_apply_calculated_intermissions:get_checked()))
    end
end

function get_vlpause_bookmark()
    local vlpause_bookmark = ""
    local temp_vlpause_bookmark = ""

    for index = 1, 10 do
        local bookmark = "bookmark" .. index
        local bookmark_value = vlc.config.get(bookmark)

        if string.len(temp_vlpause_bookmark) == 0
            and string.len(bookmark_value or "") == 0 then
            temp_vlpause_bookmark = bookmark
        end

        if string.len(bookmark_value or "") > 0
            and starts_with(bookmark_value, "VLPAUSE=") then
            vlpause_bookmark = bookmark
            break
        end
    end

    return string.len(vlpause_bookmark) > 0 and vlpause_bookmark or temp_vlpause_bookmark
end

function log_info(message)
    vlc.msg.info("[VLPause_ext] " .. message)
end

-- from Time v3.2 (c) lubozle [https://addons.videolan.org/p/1154032/]
function time_to_string(timestamp, timeformat, ms, hm) -- seconds, 0/1/2/3/4, true/false, true/false
    if not timeformat then
        timeformat = 0
    end

    local msp = (ms and "%06.3f" or "%02d") -- seconds.milliseconds formatting pattern
    if timeformat == 0 then
        if timestamp/60 < 1 then
            timeformat = 1
        elseif timestamp/3600 < 1 then
            timeformat = 2
        elseif timestamp/86400 < 1 then
            timeformat = 3
        else
            timeformat = 4
        end
    end

    if hm then
        msp = ""
        if timeformat < 3 then
            timeformat = 3
        end
    end

    if timeformat == 3 then -- H:m:s,ms
        return string.format("%02d:%02d:" .. msp, math.floor(timestamp/3600), math.floor(timestamp/60)%60, timestamp%60):gsub("%.",","):gsub(":$","")
    elseif timeformat == 2 then -- M:s,ms
        return string.format("%02d:" .. msp, math.floor(timestamp/60), timestamp%60):gsub("%.",",")
    elseif timeformat == 1 then -- S,ms
        return string.format(msp, timestamp):gsub("%.",",")
    elseif timeformat == 4 then -- D/h:m:s,ms
        return string.format("%d/%02d:%02d:" .. msp, math.floor(timestamp/(24*60*60)), math.floor(timestamp/(60*60))%24, math.floor(timestamp/60)%60, timestamp%60):gsub("%.",","):gsub(":$","")
    end
end

-- from lua-users wiki - String Recipies [http://lua-users.org/wiki/StringRecipes]
function starts_with(str, start)
    return str:sub(1, #start) == start
end
