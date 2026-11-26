-- Aleph X-Ray standalone, 2026-11-26: the bottom sheet's layout, taken from
-- Aleph's library view (aleph_library_view.lua). Only ListView.sheet and the
-- helpers it uses; the library itself is not part of this plugin. Outside
-- Aleph's library screen there are no rows to take back (env is nil).

local BoardMetrics = require("axr_board_metrics")
local BoardUI = require("axr_board_ui")

local INK = BoardMetrics.INK
local px = BoardMetrics.px
local vstack, hstack, space = BoardUI.vstack, BoardUI.hstack, BoardUI.space

local ListView = {}

local env = nil

local function hOf(widget) return widget:getSize().h end

local function screenW()
    return BoardMetrics.layoutW()
end

function ListView.mx()
    local W = screenW()
    return px(W >= 900 and 28 or W >= 700 and 24 or W >= 560 and 20 or 16)
end

local function sheetLayers(body, header_bottom, mx, o, pad, pad_x, pw, screen_h, screen_w, wide)
    local line = math.max(1, px(1.5))
    local r = px(16)
    local layers, x, y, ph
    if wide then
        ph = hOf(body) + 2 * pad
        local content = vstack({ w = pw - 2 * line, pad = { pad - line, pad - line, pad - line, pad - line } }, { body })
        local panel = BoardUI.box({ w = pw, h = ph, radius = r, border = line, border_col = INK.black, bg = INK.white }, content)
        x = o.kind == "top" and (screen_w - mx - pw) or math.floor((screen_w - pw) / 2)
        y = o.kind == "top" and (o.top or px(112)) or (screen_h - px(56) - ph)
        -- On a short screen a tall sheet rises toward the header rather than
        -- run off the bottom, and over it when it must.
        if y + ph > screen_h - px(8) then
            local lowest = screen_h - px(8) - ph
            y = lowest >= header_bottom and lowest or math.max(px(8), lowest)
        end
        layers = { { widget = panel, x = x, y = y } }
    else
        local pad_t = o.kind == "top" and px(10) or pad
        local pad_b = o.kind == "top" and pad or px(14)
        ph = pad_t + hOf(body) + pad_b
        local content = vstack({ w = pw, pad = { pad_t, pad_x, pad_b, pad_x } }, { body })
        x = 0
        if o.kind == "top" then
            y = 0
            -- Square at the top edge, rounded at the bottom with a black rule along it.
            layers = {
                { widget = BoardUI.rect(pw, ph + line, INK.black, r), x = 0, y = 0 },
                { widget = BoardUI.rect(pw, r, INK.black), x = 0, y = 0 },
                { widget = BoardUI.rect(pw, ph, INK.white, r), x = 0, y = 0 },
                { widget = BoardUI.rect(pw, r, INK.white), x = 0, y = 0 },
                { widget = content, x = 0, y = 0 },
            }
        else
            y = screen_h - ph
            layers = {
                { widget = BoardUI.rect(pw, ph + line, INK.black, r), x = 0, y = y - line },
                { widget = BoardUI.rect(pw, r, INK.black), x = 0, y = screen_h - r },
                { widget = BoardUI.rect(pw, ph, INK.white, r), x = 0, y = y },
                { widget = BoardUI.rect(pw, r, INK.white), x = 0, y = screen_h - r },
                { widget = content, x = 0, y = y },
            }
        end
    end
    return layers, ph, x, y
end

function ListView.sheet(screen_w, screen_h, o)
    local mx = ListView.mx()
    local pad = px(16)
    local wide = screenW() >= 760
    local pw = wide and math.min(px(o.pop_w or 460), screen_w - 2 * mx) or screen_w
    local pad_x = wide and pad or mx
    local inner = pw - 2 * pad_x
    -- The tallest body that fits between the header and the bottom edge.
    local header_bottom = px(6) + px(64)
    local max_body = screen_h - header_bottom - px(8) - 2 * pad
    local gap = px(14)
    local function stack(items, width)
        local spaced = {}
        for _i, item in ipairs(items) do
            if item then
                if #spaced > 0 then table.insert(spaced, space(nil, gap)) end
                table.insert(spaced, item)
            end
        end
        return vstack({ w = width }, spaced)
    end
    -- What the build registers, so a draft can be taken back.
    local hit_mark = BoardUI.hitMark()
    local rows_mark = {}
    if env then for key, list in pairs(env.rows) do rows_mark[key] = #list end end
    local row_list_mark = env and #env.row_list or 0
    local body = stack(o.build(inner, max_body), inner)
    local function takeBack()
        BoardUI.hitTrim(hit_mark)
        if env then
            for key, list in pairs(env.rows) do
                for i = #list, (rows_mark[key] or 0) + 1, -1 do table.remove(list, i) end
                if #list == 0 and not rows_mark[key] then env.rows[key] = nil; env.row_seen[key] = nil end
            end
            for i = #env.row_list, row_list_mark + 1, -1 do table.remove(env.row_list, i) end
        end
    end
    local col_gap = px(24)
    local pw2 = math.min(2 * px(o.pop_w or 460) + col_gap, screen_w - 2 * mx)
    local col_w = math.floor((pw2 - 2 * pad - col_gap) / 2)
    -- The two columns, split where they come out most even; nil when
    -- something in them would be cut.
    local function columns(checked)
        local function draft()
            local items = {}
            for _i, item in ipairs(o.build(col_w, max_body)) do if item then table.insert(items, item) end end
            local heights, total = {}, 0
            for i, item in ipairs(items) do heights[i] = hOf(item); total = total + heights[i] end
            local best, best_h, run = #items, math.huge, 0
            for k = 1, #items - 1 do
                run = run + heights[k]
                local tallest = math.max(run + (k - 1) * gap, total - run + (#items - k - 1) * gap)
                if tallest < best_h then best, best_h = k, tallest end
            end
            local left, right = {}, {}
            for i, item in ipairs(items) do table.insert(i <= best and left or right, item) end
            return hstack({ w = pw2 - 2 * pad, gap = col_gap, valign = "top" }, { stack(left, col_w), stack(right, col_w) })
        end
        if checked then
            local clean, probe = BoardUI.fits(function() return BoardUI.collectHits(draft) end)
            if probe and probe.free then probe:free() end
            if not clean then return nil end
        end
        return draft()
    end
    -- A wide, short screen (landscape) sets a sheet too tall for it in two
    -- columns. Narrower columns are tried too when one column would not fit
    -- even raised to the header, as long as nothing in them is cut.
    local raised_max = screen_h - px(8) - header_bottom - 2 * pad
    if wide and hOf(body) > max_body and (col_w >= px(300) or (hOf(body) > raised_max and col_w >= px(220))) then
        body:free()
        takeBack()
        local split = columns(col_w < px(300))
        if split then
            pw = pw2
            body = split
        else
            body = stack(o.build(inner, max_body), inner)
        end
    end
    local layers, ph, x, y = sheetLayers(body, header_bottom, mx, o, pad, pad_x, pw, screen_h, screen_w, wide)
    return layers, { x = x, y = y, w = pw, h = ph }
end

return ListView
