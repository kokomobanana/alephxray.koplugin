--[[--
Aleph X-Ray (standalone): Aleph's own X-Ray, without the rest of Aleph.

This is a modified version of BookOrbit and is not an official BookOrbit
release. Modified 2026-11-26: Aleph's X-Ray (aleph_xr*.lua) and the parts of
Aleph it draws with, taken out of Aleph 1.3.0 (commit 9de0a4a) and renamed
(aleph_* -> axr_*) so both plugins can be installed side by side. Aleph's
settings screen is replaced by KOReader menus here. See MODIFICATIONS.md.

The names found for a book are kept next to the book (aleph_xray*.lua in its
settings folder), the same files Aleph writes: a book already read for its
names in Aleph opens here with them, and the other way round.
]]

local Dispatcher = require("dispatcher")
local InfoMessage = require("ui/widget/infomessage")
local InputDialog = require("ui/widget/inputdialog")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local logger = require("logger")
local T = require("ffi/util").template

local Prefs = require("axr_prefs")
local _ = require("axr_gettext")

local SETTING_KEYS = {
    "xray_enabled", "xray_underline", "xray_show_all", "xray_ai_provider", "xray_ai_key",
    "xray_ai_model", "xray_ai_url", "xray_ai_rich", "xray_recap_days",
}

-- The first time: Aleph's X-Ray settings (its key, provider, options) are
-- copied, so nothing has to be typed again. Aleph's own are left as they are.
local function migrateFromAleph()
    if G_reader_settings:readSetting("alephxray") ~= nil then return end
    local aleph = G_reader_settings:readSetting("aleph")
    local mine = {}
    if type(aleph) == "table" then
        for _i, key in ipairs(SETTING_KEYS) do
            if aleph[key] ~= nil then mine[key] = aleph[key] end
        end
    end
    G_reader_settings:saveSetting("alephxray", mine)
end

local function version()
    local dir = tostring(debug.getinfo(1, "S").source):match("^@(.*)/[^/]*$") or "."
    local ok, meta = pcall(dofile, dir .. "/_meta.lua")
    return ok and type(meta) == "table" and meta.version or "?"
end

local LEGAL = [[Aleph X-Ray (standalone)

This is a modified version of BookOrbit and is not an official BookOrbit release.
Modified 2026-11-26: Aleph's X-Ray taken out of Aleph 1.3.0 as a plugin of its own.

Powered by BookOrbit
https://github.com/bookorbit/bookorbit
Copyright (C) 2025-2026 neon.
Additional copyright is held by the respective BookOrbit contributors.
Original project: https://github.com/bookorbit/bookorbit

Aleph (modified version of BookOrbit): https://github.com/lara-2-ko/aleph.koplugin

Licensed under the GNU Affero General Public License, version 3 only, with additional terms. This software is provided without warranty. You may redistribute and modify it under those terms.

The complete source of this version is the plugin folder itself (alephxray.koplugin): every file in it is plain source code. See LICENSE, ADDITIONAL_TERMS.md, NOTICE, THIRD_PARTY_NOTICES.md and MODIFICATIONS.md there.

Icons: Lucide (ISC license). Finding mentions with KOReader's own search follows xray.koplugin by Jimmy Pautz (MIT); nothing else is taken from it.]]

-- First in Tools, in books and in the file browser.
-- KOReader keeps its menu-order tables cached and lets plugins change them
-- before a menu is built (Aleph and BookOrbit place themselves the same way).
-- A menu order saved on the device (settings/reader_menu_order.lua or
-- filemanager_menu_order.lua) replaces those lists each time a menu is built,
-- so the saved one is given the entry too, as it is read: the file itself is
-- never changed.
local MENU_ID = "alephxray"

local function placeFirst(order)
    if type(order) ~= "table" or type(order.tools) ~= "table" then return false end
    for _key, list in pairs(order) do
        if type(list) == "table" then
            for i = #list, 1, -1 do
                if list[i] == MENU_ID then table.remove(list, i) end
            end
        end
    end
    table.insert(order.tools, 1, MENU_ID)
    return true
end

local pinned = false
local function pinToTools()
    if pinned then return end
    pinned = true
    for _i, module in ipairs({ "ui/elements/reader_menu_order", "ui/elements/filemanager_menu_order" }) do
        local ok, order = pcall(require, module)
        if not (ok and placeFirst(order)) then
            logger.warn("Aleph X-Ray: cannot place the menu entry in Tools of", module)
        end
    end
    local ok_ms, MenuSorter = pcall(require, "ui/menusorter")
    if ok_ms and type(MenuSorter) == "table" and type(MenuSorter.readMSSettings) == "function"
            and not rawget(MenuSorter, "_alephxray_wrapped") then
        MenuSorter._alephxray_wrapped = true
        local read = MenuSorter.readMSSettings
        MenuSorter.readMSSettings = function(self, config_prefix, ...)
            local user = read(self, config_prefix, ...)
            if config_prefix == "reader" or config_prefix == "filemanager" then
                pcall(placeFirst, user)
            end
            return user
        end
    end
end

local AlephXray = WidgetContainer:extend{
    name = "alephxray",
    is_doc_only = false,
}

function AlephXray:init()
    migrateFromAleph()
    Dispatcher:registerAction("alephxray_open", { category = "none", event = "ShowAlephXrayStandalone",
        title = _("X-Ray (Aleph): open"), reader = true })
    pcall(pinToTools)
    self.ui.menu:registerToMainMenu(self)
    if self.ui.document then self:attach() end
end

-- X-Ray for the open book, when it is on and the book can have one.
function AlephXray:attach()
    if not Prefs.is("xray_enabled") or not self.ui.document then return end
    local ok, err = pcall(function()
        local XR = require("axr_xr")
        XR.install()
        XR.attach(self.ui)
    end)
    if not ok then logger.warn("Aleph X-Ray: could not start:", err) end
end

function AlephXray:detach()
    local XR = package.loaded["axr_xr"]
    if XR then pcall(XR.detach, self.ui) end
    if self.ui.highlight and self.ui.highlight.removeFromHighlightDialog then
        pcall(function() self.ui.highlight:removeFromHighlightDialog("14_axr_xray") end)
    end
end

function AlephXray:supported()
    local ok, yes = pcall(function() return require("axr_xr").supported(self.ui) end)
    return ok and yes
end

function AlephXray:openXray()
    if not self.ui.document then return false end
    if not Prefs.is("xray_enabled") then
        UIManager:show(InfoMessage:new{ text = _("X-Ray is off. Turn it on in Tools > X-Ray (Aleph) > Settings."), timeout = 4 })
        return true
    end
    if not self:supported() then
        UIManager:show(InfoMessage:new{ text = _("X-Ray works with books KOReader lays out itself (EPUB, FB2, MOBI and the like), not with PDFs or comics."), timeout = 5 })
        return true
    end
    local ok, err = pcall(function()
        local XR = require("axr_xr")
        XR.install()
        XR.attach(self.ui)
        XR.open(self.ui)
    end)
    if not ok then
        logger.warn("Aleph X-Ray: failed to open:", err)
        UIManager:show(InfoMessage:new{ text = T(_("X-Ray could not open:\n%1"), tostring(err)) })
    end
    return true
end

function AlephXray:onShowAlephXrayStandalone()
    return self:openXray()
end

function AlephXray:onCloseDocument()
    local XR = package.loaded["axr_xr"]
    if XR then pcall(XR.detach, self.ui) end
end

-- ------------------------------------------------------------------ menus

local function toggle(key, text, help, after)
    return {
        text = text,
        help_text = help,
        checked_func = function() return Prefs.is(key) end,
        callback = function()
            Prefs.set(key, not Prefs.is(key) or nil)
            if after then after(Prefs.is(key)) end
        end,
    }
end

local function input(title, key, current, hint)
    local dialog
    dialog = InputDialog:new{
        title = title,
        input = current or "",
        input_hint = hint,
        buttons = { {
            { text = _("Cancel"), id = "close", callback = function() UIManager:close(dialog) end },
            { text = _("Save"), is_enter_default = true, callback = function()
                local v = tostring(dialog:getInputText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
                Prefs.set(key, v ~= "" and v or nil)
                UIManager:close(dialog)
            end },
        } },
    }
    UIManager:show(dialog)
    dialog:onShowKeyboard()
end

function AlephXray:aiMenu()
    local AI = require("axr_xr_ai")
    local items = {}
    for _i, p in ipairs(AI.PROVIDERS) do
        table.insert(items, {
            text = _(p.label),
            radio = true,
            checked_func = function() return AI.config().provider == p.id end,
            callback = function()
                if Prefs.get().xray_ai_provider ~= p.id then
                    Prefs.set("xray_ai_provider", p.id)
                    Prefs.set("xray_ai_model", nil)
                end
            end,
        })
    end
    items[#items].separator = true
    table.insert(items, {
        text_func = function()
            local key = AI.config().key
            return key ~= "" and T(_("Key: saved · ends in %1"), key:sub(-4)) or _("Key: not set")
        end,
        keep_menu_open = true,
        callback = function() input(_("Provider key"), "xray_ai_key", Prefs.get().xray_ai_key) end,
    })
    table.insert(items, {
        text_func = function()
            local model = AI.config().model
            return T(_("Model: %1"), model ~= "" and model or _("Not set"))
        end,
        keep_menu_open = true,
        callback = function() input(_("Model"), "xray_ai_model", Prefs.get().xray_ai_model or AI.config().model) end,
    })
    table.insert(items, {
        text_func = function()
            local url = AI.config().url
            return T(_("Address (Other only): %1"), url ~= "" and url or _("Not set"))
        end,
        enabled_func = function() return AI.config().provider == "custom" end,
        keep_menu_open = true,
        callback = function() input(_("Address"), "xray_ai_url", Prefs.get().xray_ai_url, "https://…/v1/chat/completions") end,
    })
    table.insert(items, toggle("xray_ai_rich", _("Detailed descriptions"),
        _("Main characters in 3–4 sentences, from longer passages and the chapter summaries. Uses several times more of your AI allowance.")))
    local recap = {}
    for _i, d in ipairs({ 0, 7, 14, 30 }) do
        table.insert(recap, {
            text = ({ [0] = _("Never"), [7] = _("1 week"), [14] = _("2 weeks"), [30] = _("1 month") })[d],
            radio = true,
            checked_func = function() return (tonumber(Prefs.get().xray_recap_days) or 14) == d end,
            callback = function() Prefs.set("xray_recap_days", d) end,
        })
    end
    table.insert(items, { text = _("Offer a recap after a break"), sub_item_table = recap })
    return items
end

function AlephXray:addToMainMenu(menu_items)
    menu_items.alephxray = {
        text = _("X-Ray (Aleph)"),
        -- In Tools (KOReader puts an entry it has no place for in the first
        -- tab, as "NEW: ...", without this).
        sorting_hint = "tools",
        sub_item_table_func = function()
            local items = {}
            if self.ui.document then
                table.insert(items, {
                    text = _("Open X-Ray"),
                    enabled_func = function() return Prefs.is("xray_enabled") end,
                    callback = function(touchmenu)
                        if touchmenu then touchmenu:closeMenu() end
                        UIManager:nextTick(function() self:openXray() end)
                    end,
                    separator = true,
                })
            end
            table.insert(items, toggle("xray_enabled", _("X-Ray on"),
                _("The people and places of a book and where they were mentioned so far. Off: nothing of it is loaded."),
                function(on)
                    if not self.ui.document then return end
                    if on then self:attach() else self:detach() end
                end))
            table.insert(items, toggle("xray_underline", _("Underline names"),
                _("A thin line under each name; tap one to open it. Turn off if pages turn slower. Takes effect when a book is opened.")))
            table.insert(items, toggle("xray_show_all", _("Show the whole book"),
                _("Names and mentions from pages not read yet too. Off: only up to the page you are on.")))
            table.insert(items, {
                text = _("Descriptions with AI (optional)"),
                help_text = _("Asked from a book's X-Ray, never by itself, with your own key. Names: sends the book's title and a few words around each name. Story: sends the text of the chapters you have read. Never a page not read yet."),
                sub_item_table_func = function() return self:aiMenu() end,
                separator = true,
            })
            table.insert(items, {
                text = _("About / Legal notices"),
                keep_menu_open = true,
                callback = function() UIManager:show(InfoMessage:new{ text = T(_("Version %1"), version()) .. "\n\n" .. LEGAL }) end,
            })
            return items
        end,
    }
end

return AlephXray
