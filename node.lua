gl.setup(1124, 768)

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
    font:write(0, 0, now, 30, 1,1,1,1)
    for idx, dep in ipairs(departures) do


        if dep.date > now then
            local time = dep.nice_date

            local remaining = math.floor((dep.date - now) / 60)
            local append = ""

            if remaining < 0 then
                time = "gone"
            elseif remaining < 1 then
                time = "now"
            elseif remaining < 60 then
                time = string.format("%d min", ((dep.date - now)/60))
            end


            if remaining < 15 then
                util.draw_correct(_G[dep.icon], 10, y, 140, y+60, 0.9)
                font:write(120, y, dep.direction, 60, 1,1,1,1)
                if frame == 1 then
                    font:write(800, y, time, 60, 1,1,1,1)
                else
                    font:write(800, y, dep.nice_date, 60, 1,1,1,1)
                    if dep.realtime == "1" then
                        if dep.delay == "0" then
                            font:write(950, y, "+" .. dep.delay, 60, 0,1,0,1)
                        else
                            font:write(950, y, "+" .. dep.delay, 60, 1,0,0,1)
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
                    font:write(800, y, time, 45, 1,1,1,1)
                else
                    font:write(800,y, dep.nice_date, 45, 1,1,1,1)
                    if dep.realtime == "1" then
                        if dep.delay == "0" then
                            font:write(920,y, "+" .. dep.delay, 45, 0,1,0,1)
                        else
                            font:write(920,y, "+" .. dep.delay, 45, 1,0,0,1)
                        end
                    end
                end
                y = y + 60
            end
            if y > HEIGHT - 120 then
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
                which = math.max(-1, math.min(1, -3 + math.sin(sys.now()) * 5.5)) * 0.5 + 0.5;
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
