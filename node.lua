gl.setup(1240, 720)

node.alias("departures")

json = require "json"

util.auto_loader(_G)

local base_time = N.base_time or 0
local departures = N.departures or {}

local drawer




util.data_mapper{
    ["clock/set"] = function(time)
        base_time = tonumber(time) - sys.now()
        N.base_time = base_time
    end;
    ["update"] = function()
        schedule.update()
    end;
}

node.event("input", function(line, client)
    departures = json.decode(line)
    N.departures = departures
    print("departures update")
    schedule.update()
end)

function unixnow()
    return base_time + sys.now()
end

shader = resource.create_shader[[
    uniform sampler2D Texture;
    uniform sampler2D frame2;
    varying vec2 TexCoord;
    uniform float which;

    void main() {
        vec4 col1 = texture2D(Texture, TexCoord.st);
        vec4 col2 = texture2D(frame2, TexCoord.st);
        // gl_FragColor = vec4(mix(col1.rgb, col2.rgb, which), max(col1.a, col2.a));
        gl_FragColor = mix(col1, col2, which);
    }
]]

function draw_departures(now, frame)
    local y = 23
    local now = unixnow()
--    font:write(0, 0, now, 30, 1,1,1,0.8)
--    font:write(250,600, "Jakob, nerv' nicht!", 100, 1,1,1,1)
    for idx, dep in ipairs(departures) do

        if (dep.date > now or dep.rdate > now) then

            local remtime = ((dep.date - now) / 60)
            local remtime = ((dep.rdate - now) / 60)
            
            local remaining = math.floor(remtime)
            local time = dep.nice_date


            if remaining < 0 then
                time = "gone"
            elseif remaining < 1 then
                time = "now"
            elseif remaining < 60 then
--                time = string.format("%d min", ((dep.date - now)/60))
                time = string.format("%d min", remtime)
            end


            if remaining < 10 then
                util.draw_correct(_G[dep.icon], 10, y, 140, y+60, 0.9)
                font:write(120, y, dep.direction, 60, 1,1,1,1)
                if frame == 1 then
                    font:write(900, y, time, 60, 1,1,1,1)
                else
                    font:write(900, y, dep.nice_date, 60, 1,1,1,1)
                    if dep.realtime == "1" then
                        if dep.delay == "0" then
                            font:write(1060, y, "+" .. dep.delay, 60, 0,1,0,1)
                        else
                            font:write(1060, y, "+" .. dep.delay, 60, 1,0,0,1)
--                             font:write(400, y, "+" .. dep.delay .. " " .. dep.rdate, 50, 1,0,0,1)
                        end
                    end
                end
--                if delay != "0" then
--                    y = y + 60
--                    font:write(150, y, delay .. " min delayed", 45, 1,1,1,1)
--                end
                y = y + 20
                y = y + 60
            else
                util.draw_correct(_G[dep.icon], 10, y, 140, y+45, 0.9)
                font:write(110, y, dep.direction, 45, 1,1,1,1)
                if frame == 1 then
                    font:write(900, y, time, 45, 1,1,1,1)
                else
                    font:write(900,y, dep.nice_date, 45, 1,1,1,1)
                    if dep.realtime == "1" then
                        if dep.delay == "0" then
                            font:write(1030,y, "+" .. dep.delay, 45, 0,1,0,1)
                        else
                            font:write(1030,y, "+" .. dep.delay, 45, 1,0,0,1)
--                             font:write(400,y, "+" .. dep.delay .. " " .. dep.rdate, 45, 1,0,0,1)
                        end
                    end
                end
                y = y + 60
            end
            if y > HEIGHT - 160 then
                font:write(10,660, "Kliniken Wissenschaftsstadt", 60, 1,1,1,1)
                font:write(10,610, "Anlage im Probebetrieb. Kontakt: uulm.de/?mobil", 45, 1,0.2,0.2,1)
                break
            end
        end
    end
end

function make_schedule()
    local frame1, frame2
    local updater

    local function update_func()
        coroutine.yield()
        print("updating!")
        local now = unixnow()
        print('time is now', now)
        gl.clear(0, 0, 0, 0)
        draw_departures(now, 1)
        frame1 = resource.create_snapshot()
        coroutine.yield()
        gl.clear(0, 0, 0, 0)
        draw_departures(now, 2)
        frame2 = resource.create_snapshot()
    end

    local function update()
        updater = coroutine.wrap(update_func)
    end

    local function draw()
        if updater then
            local success = pcall(updater)
            if not success then
                updater = nil
            end
        end
        gl.clear(0, 0, 0, 0)
        if frame1 and frame2 then
            shader:use{
                frame2 = frame2;
                which = math.max(-1, math.min(2, -3 + math.sin(sys.now()) * 25.5)) * 1.5 + 0.5 ;
            }
            frame1:draw(0, 0, WIDTH, HEIGHT, 1)
            shader:deactivate()
        end
    end
    return {
        draw = draw;
        update = update;
    }
end

schedule = make_schedule()
util.set_interval(10, schedule.update)

function node.render()
    schedule.draw()
end
