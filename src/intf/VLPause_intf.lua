--[[-------------- VLPause v0.3 ------------
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

local intermission_percentages_map = {}

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

    if string.len(vlpause_bookmark) > 0 then
        return vlpause_bookmark
    else
        return temp_vlpause_bookmark
    end
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

function get_vlpause_option(bookmark)
    return tonumber(string.sub(vlc.config.get(bookmark), string.len("VLPAUSE=") + 1))
end

function sleep(seconds)
	vlc.misc.mwait(vlc.misc.mdate() + seconds*1000000)
end

function need_to_pause(vlpause_selected_option, position, normalized_position, intermission_position)
    local intermission_percentages = intermission_percentages_map[vlpause_selected_option - 1]

    -- 0 intermissions
    if vlpause_selected_option == 1 then
        return false
    elseif (intermission_position[normalized_position] == nil or intermission_position[normalized_position] == position)
        and is_position_in_intermission_percentages(normalized_position, intermission_percentages) then
        return true
    end
end

function is_position_in_intermission_percentages(normalized_position, intermission_percentages)
    for index = 1, #intermission_percentages do
        if normalized_position == intermission_percentages[index] then
            return true
        end
    end

    return false
end

function initialize_intermission_percentages_map()
    for index = 1, 5 do
        intermission_percentages_map[index] = get_intermission_percentages(index)
    end
end

function get_intermission_percentages(number_of_intermissions)
    local percentage = 100 / (number_of_intermissions + 1)
    local total = percentage
    local intermission_percentages = {}

    repeat
        table.insert(intermission_percentages, math.floor(total))
        total = total + percentage
    until math.ceil(total) >= 100
    
    return intermission_percentages
end

function looper()
    local bookmark = nil
    local intermission_position = {}
    local vlpause_selected_option = nil

    initialize_intermission_percentages_map()

    while true do
        if vlc.volume.get() == -256 then
            break
        end

        if not bookmark then
            bookmark = get_vlpause_bookmark();
        end

        if vlc.playlist.status()=="stopped" then
            intermission_position = {}
            sleep(1)
        else
            vlpause_selected_option = get_vlpause_option(bookmark)

            if vlpause_selected_option ~= 1 then -- option 1 is never pause
                local current_input_uri = nil
			    if vlc.input.item() then
                    current_input_uri = vlc.input.item():uri()
                end

                if not current_input_uri then
                    log_info("WTF??? " .. vlc.playlist.status())
                    sleep(0.1)
                else
                    if vlc.playlist.status() == "playing" then
                        local input = vlc.object.input()
                        local position = vlc.var.get(input, "position")
                        local normalized_position = math.floor(position * 100)

                        if intermission_position[normalized_position]
                            and position < intermission_position[normalized_position] then
                            intermission_position[normalized_position] = nil
                        end

                        if need_to_pause(vlpause_selected_option, position, normalized_position, intermission_position) then
                            vlc.osd.message("-- INTERMISSION --", 1, "center", 5*1000000) -- display for 5 seconds
                            vlc.playlist.pause()
                            intermission_position[normalized_position] = position
                        end
                    elseif vlc.playlist.status() == "paused" then
                        sleep(0.3)
                    else
                        sleep(1)
                    end

                    sleep(0.1)
                end
            end
        end
        
        sleep(0.1)
    end
end

looper()
