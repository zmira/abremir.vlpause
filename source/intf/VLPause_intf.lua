--[[-------------- VLPause v0.7 ------------
"VLPause_ext.lua" > Put this VLC Extension Lua script file in \lua\extensions\ folder
--------------------------------------------
Requires "VLPause_ext.lua" > Put the VLC Extension Lua script file in \lua\extensions\ folder

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

INSTALLATION directory (\lua\intf\):
* Windows (all users): %ProgramFiles%\VideoLAN\VLC\lua\intf\
* Windows (current user): %APPDATA%\VLC\lua\intf\
* Linux (all users): /usr/lib/vlc/lua/intf/
* Linux (current user): ~/.local/share/vlc/lua/intf/
* Mac OS X (all users): /Applications/VLC.app/Contents/MacOS/share/lua/intf/
* Mac OS X (current user): /Users/%your_name%/Library/Application Support/org.videolan.vlc/lua/intf/
Create directory if it does not exist!
--]]----------------------------------------

os.setlocale("C", "all") -- fixes numeric locale issue on Mac

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

-- from lua-users wiki - String Recipies [http://lua-users.org/wiki/StringRecipes]
function starts_with(str, start)
    return str:sub(1, #start) == start
end

-- from https://stackoverflow.com/a/27028488/552219
function dump(o)
    if type(o) == 'table' then
        local s = '{ '
        for k, v in pairs(o) do
            if type(k) ~= 'number' then
                k = '"'..k..'"'
            end
            s = s .. '['..k..'] = ' .. dump(v) .. ','
        end
        return s .. '} '
    else
        return tostring(o)
    end
 end

function log_info(message)
    vlc.msg.info("[VLPause_intf] " .. message)
end

-- from https://luascripts.com/lua-strings
function split_string(input, separator)
    local tbl = {}
    for str in string.gmatch(input, "([^" .. separator .. "]+)") do
        table.insert(tbl, str)
    end
    return tbl
end

function get_vlpause_configuration_table()
    return split_string(string.sub(vlc.config.get(get_vlpause_bookmark()), string.len("VLPAUSE=") + 1), ":")
end

function sleep(seconds)
	vlc.misc.mwait(vlc.misc.mdate() + seconds*1000000)
end

function is_time_for_intermission(play_time_in_seconds, intermission_positions_map)
    for index = 1, #intermission_positions_map do
        if play_time_in_seconds == intermission_positions_map[index] then
            return true
        end
    end

    return false
end

function get_intermission_positions_map(number_of_intermissions)
    local item = vlc.input.item()

    if not item then
        return {}
    end

    local duration = item:duration() -- in seconds
    local positions_map = {}

    if number_of_intermissions ~= 0 then
        local slice_size = math.floor(duration / (number_of_intermissions + 1))
        local position = slice_size
        for index = 1, number_of_intermissions do
            positions_map[index] = position
            position = position + slice_size
        end
    end

    return positions_map;
end

function get_calculated_number_of_intermissions()
    local item = vlc.input.item()

    if not item then
        return 0
    end

    local duration = item:duration() -- in seconds

    -- if duration is less than 1h15m (4500 = 1.25h * 60 * 60)
    -- then use 0 else subtract 1h15m from the duration and
    -- convert to hours (3600 = 1h * 60 * 60), round up to nearest integer
    return duration < 4500 and 0 or math.ceil((duration - 4500) / 3600)
end

function looper()
    local string_to_boolean = { ["true"] = true, ["false"] = false }
    local vlpause_configuration_table = {}
    local manual_number_of_intermissions = nil
    local calculated_number_of_intermissions = nil
    local auto_apply_calculated_intermissions = nil
    local intermission_positions_map = {}
    local current_intermission_time = nil
    local current_input_uri = nil
    local display_intermission_config = false

    while true do
        if vlc.volume.get() == -256 then
            break
        end

        local vlc_status = vlc.playlist.status()

        if vlc_status == "stopped" then
            vlpause_configuration_table = {}
            manual_number_of_intermissions = nil
            calculated_number_of_intermissions = nil
            auto_apply_calculated_intermissions = nil
            intermission_positions_map = {}
            current_intermission_time = nil
            current_input_uri = nil
            display_intermission_config = true
            sleep(1)
        elseif vlc_status == "paused" then
            sleep(0.3)
        elseif vlc_status == "playing" then
            local input_uri = vlc.input.item():uri()
            if not input_uri then
                log_info("WTF??? " .. vlc.playlist.status())
                sleep(0.1)
            else
                if (input_uri ~= current_input_uri) then
                    vlpause_configuration_table = {}
                    manual_number_of_intermissions = nil
                    calculated_number_of_intermissions = nil
                    auto_apply_calculated_intermissions = nil
                    intermission_positions_map = {}
                    current_intermission_time = nil
                    current_input_uri = input_uri
                    display_intermission_config = true
                end

                if #vlpause_configuration_table == 0 then
                    vlpause_configuration_table = get_vlpause_configuration_table();
                    log_info("vlpause configuration table: " .. dump(vlpause_configuration_table))
                end

                manual_number_of_intermissions = tonumber(vlpause_configuration_table[1])
        
                if not calculated_number_of_intermissions then
                    calculated_number_of_intermissions = get_calculated_number_of_intermissions()
                    log_info("calculated number of intermissions: " .. tostring(calculated_number_of_intermissions))
                end
        
                if not auto_apply_calculated_intermissions then
                    auto_apply_calculated_intermissions = #vlpause_configuration_table > 1 and string_to_boolean[vlpause_configuration_table[2]] or false
                    log_info("auto-apply calculated # of intermissions: " .. tostring(auto_apply_calculated_intermissions))
                end

                local number_of_intermissions = auto_apply_calculated_intermissions and calculated_number_of_intermissions or manual_number_of_intermissions

                if display_intermission_config then
                    vlc.osd.message("=> " .. number_of_intermissions .. " intermissions [" .. (auto_apply_calculated_intermissions and "AUTO" or "MANUAL") .. "]", 1, "top-left", 3*1000000) -- display for 3 seconds
                    display_intermission_config = false
                    log_info("number of intermissions: " .. tostring(number_of_intermissions))
                end

                if number_of_intermissions ~= 0 then
                    if #intermission_positions_map == 0 then
                        intermission_positions_map = get_intermission_positions_map(number_of_intermissions)
                        log_info("intermission positions map: " .. dump(intermission_positions_map))
                    end

                    local input = vlc.object.input()
                    local play_time = vlc.var.get(input, "time")
                    local play_time_in_seconds = math.floor(vlc.var.get(input, "time") / 1000 / 1000) -- in seconds

                    if current_intermission_time ~= nil
                        and current_intermission_time ~= play_time_in_seconds then
                        current_intermission_time = nil
                    end

                    if current_intermission_time == nil and is_time_for_intermission(play_time_in_seconds, intermission_positions_map) then
                        current_intermission_time = play_time_in_seconds
                        log_info("INTERMISSION :: manual number of intermissions = " .. dump(manual_number_of_intermissions)
                            .. ", calculated number of intermissions = " .. dump(calculated_number_of_intermissions) 
                            .. ", automatic apply calculated # of intermissions = " .. dump(auto_apply_calculated_intermissions)
                            .. ", play time = " .. dump(play_time)
                            .. ", play time [in seconds] = " .. dump(play_time_in_seconds)
                            .. ", intermission position map = " .. dump(intermission_positions_map)
                        )
                        vlc.osd.message("-- " .. (#vlpause_configuration_table > 2 and vlpause_configuration_table[3] or "INTERMISSION") .. " --", 1, "center", 5*1000000) -- display for 5 seconds
                        vlc.playlist.pause()
                    end
                end
            end
        else
            sleep(1)
        end

        sleep(0.1)
    end
end

looper()
