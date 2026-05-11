--[[
    KOReader userpatch: force Zen UI's library pagination to use the
    built-in-style arrow/page-number footer instead of the dot strip.

    Install this file in KOReader's "patches" directory, then restart KOReader:

        koreader/patches/2-zenui-arrow-pagination.lua
--]]

local logger = require("logger")

local PATCH_ID = "__oneui_zenui_arrow_pagination"

if not rawget(_G, PATCH_ID) then
    rawset(_G, PATCH_ID, true)

    local original_require = require
    local menu_zones_patched = false

    local function normalize_zen_scroll_bar(config)
        if type(config) ~= "table" then
            return false
        end

        if type(config.zen_scroll_bar) ~= "table" then
            config.zen_scroll_bar = {}
        end

        local changed = false
        if config.zen_scroll_bar.style == nil or config.zen_scroll_bar.style == "dots" then
            config.zen_scroll_bar.style = "page_number"
            changed = true
        end

        if config.zen_scroll_bar.page_number_format == nil then
            config.zen_scroll_bar.page_number_format = "total"
            changed = true
        end

        if config.zen_scroll_bar.hold_skip == nil then
            config.zen_scroll_bar.hold_skip = "ends"
            changed = true
        end

        return changed
    end

    local function patch_menu_first_last_zones(pager)
        if menu_zones_patched then
            return
        end

        local ok_menu, Menu = pcall(original_require, "ui/widget/menu")
        local ok_device, Device = pcall(original_require, "device")
        if not ok_menu or not ok_device or type(Menu) ~= "table" or type(Menu.init) ~= "function" then
            return
        end

        menu_zones_patched = true
        local Screen = Device.screen
        local original_init = Menu.init
        local target_menus = {
            filemanager = true,
            history = true,
            collections = true,
            library_view = true,
        }

        Menu.init = function(self, ...)
            local result = original_init(self, ...)

            local is_bookmarks_menu = self.is_borderless
                and self.title_bar_fm_style
                and self.title_bar_left_icon == "appbar.menu"

            if pager.getStyle() ~= "page_number"
                or self._oneui_arrow_pager_zones
                or not self.dimen
                or not self.page_info
                or not self.page_info_text
                or (not target_menus[self.name]
                    and not (self.covers_fullscreen and self.is_borderless and self.title_bar_fm_style)
                    and not is_bookmarks_menu) then
                return result
            end

            self._oneui_arrow_pager_zones = true

            local scr_w = Screen:getWidth()
            local scr_h = Screen:getHeight()
            local bar_w = math.floor(scr_w * 0.92)
            local bar_x = math.floor((scr_w - bar_w) / 2)
            local foot_h = pager.PN_FOOTER_H or pager.FOOTER_H
            local tap_w = pager.ONEUI_TAP_W or pager.CHEV_W
            local chev_w = pager.CHEV_W
            local gap = Screen:scaleBySize(12)
            local draw_w = chev_w
            local footer_y = self.dimen.y + self.dimen.h - foot_h
            local menu_x = self.dimen.x
            local rz_y = footer_y / scr_h
            local rz_h = foot_h / scr_h

            local function zone_x(offset)
                return (menu_x + bar_x + offset) / scr_w
            end

            local function page_text(cur_page, total_pages)
                return "Page " .. tostring(cur_page) .. " of " .. tostring(total_pages)
            end

            local text_w
            do
                local ok_font, Font = pcall(original_require, "ui/font")
                local ok_render, RenderText = pcall(original_require, "ui/rendertext")
                if ok_font and ok_render then
                    local face = Font:getFace("smallinfofont")
                    text_w = RenderText:sizeUtf8Text(0, 9999, face,
                        page_text(self.page or 1, self.page_num or 1), true, false).x
                else
                    text_w = Screen:scaleBySize(110)
                end
            end

            local group_w = draw_w * 4 + gap * 4 + text_w
            local group_x = math.floor(math.max(0, bar_w - group_w) / 2)
            local first_x = group_x
            local prev_x = first_x + draw_w + gap
            local text_x = prev_x + draw_w + gap * 2
            local next_x = text_x + text_w + gap * 2
            local last_x = next_x + draw_w + gap
            local tap_inset = math.floor((tap_w - draw_w) / 2)

            local function icon_zone_x(draw_x)
                return zone_x(math.max(0, draw_x - tap_inset))
            end

            local function goto_page(page)
                if page and self.onGotoPage then
                    self:onGotoPage(page)
                end
                return true
            end

            self:registerTouchZones({
                {
                    id = "zen_pn_first_tap",
                    ges = "tap",
                    screen_zone = { ratio_x = icon_zone_x(first_x), ratio_y = rz_y, ratio_w = tap_w / scr_w, ratio_h = rz_h },
                    handler = function()
                        if pager.getStyle() ~= "page_number" then return end
                        return goto_page(1)
                    end,
                },
                {
                    id = "zen_pn_left_tap",
                    ges = "tap",
                    screen_zone = { ratio_x = icon_zone_x(prev_x), ratio_y = rz_y, ratio_w = tap_w / scr_w, ratio_h = rz_h },
                    handler = function()
                        if pager.getStyle() ~= "page_number" then return end
                        return goto_page(math.max(1, (self.page or 1) - 1))
                    end,
                },
                {
                    id = "zen_pn_center_tap",
                    ges = "tap",
                    screen_zone = {
                        ratio_x = zone_x(text_x - gap),
                        ratio_y = rz_y,
                        ratio_w = math.max(0, text_w + gap * 2) / scr_w,
                        ratio_h = rz_h,
                    },
                    handler = function()
                        if pager.getStyle() ~= "page_number" then return end
                        if self.page_info_text and self.page_info_text.onInput and self.page_info_text.hold_input then
                            self.page_info_text:onInput(self.page_info_text.hold_input)
                        end
                        return true
                    end,
                },
                {
                    id = "zen_pn_right_tap",
                    ges = "tap",
                    screen_zone = { ratio_x = icon_zone_x(next_x), ratio_y = rz_y, ratio_w = tap_w / scr_w, ratio_h = rz_h },
                    handler = function()
                        if pager.getStyle() ~= "page_number" then return end
                        return goto_page(math.min(self.page_num or 1, (self.page or 1) + 1))
                    end,
                },
                {
                    id = "zen_pn_last_tap",
                    ges = "tap",
                    screen_zone = { ratio_x = icon_zone_x(last_x), ratio_y = rz_y, ratio_w = tap_w / scr_w, ratio_h = rz_h },
                    handler = function()
                        if pager.getStyle() ~= "page_number" then return end
                        return goto_page(self.page_num or 1)
                    end,
                },
            })

            return result
        end
    end

    local function patch_config_manager(manager)
        if type(manager) ~= "table" or manager._oneui_arrow_pagination_patched then
            return
        end
        if type(manager.load) ~= "function" then
            return
        end

        manager._oneui_arrow_pagination_patched = true
        local original_load = manager.load

        manager.load = function(...)
            local config = original_load(...)
            if normalize_zen_scroll_bar(config) then
                if type(manager.save) == "function" then
                    pcall(manager.save, config)
                end
                if G_reader_settings and G_reader_settings.flush then
                    pcall(G_reader_settings.flush, G_reader_settings)
                end
                logger.info("OneUI patch: Zen UI pagination changed from dots to page_number")
            end
            return config
        end
    end

    local function patch_pager(pager)
        if type(pager) ~= "table" or pager._oneui_arrow_pagination_patched then
            return
        end
        if type(pager.getStyle) ~= "function" then
            return
        end

        pager._oneui_arrow_pagination_patched = true
        local original_get_style = pager.getStyle
        local original_paint = pager.paint

        pager.getStyle = function(...)
            local style = original_get_style(...)
            if style == nil or style == "dots" then
                return "page_number"
            end
            return style
        end

        local ok_device, Device = pcall(original_require, "device")
        local ok_font, Font = pcall(original_require, "ui/font")
        local ok_icon, IconWidget = pcall(original_require, "ui/widget/iconwidget")
        local ok_render, RenderText = pcall(original_require, "ui/rendertext")
        local ok_gettext, gettext = pcall(original_require, "gettext")
        local ok_template, template = pcall(original_require, "ffi/util")

        if ok_device and ok_font and ok_icon and ok_render then
            local Screen = Device.screen
            pager.CHEV_W = Screen:scaleBySize(42)
            pager.ONEUI_TAP_W = Screen:scaleBySize(56)
            pager.PN_ICON_SZ = Screen:scaleBySize(38)
            pager.PN_FOOTER_H = math.max(pager.FOOTER_H, pager.PN_ICON_SZ + Screen:scaleBySize(12))

            local face = Font:getFace("smallinfofont")
            local icons = {}

            local function icon(name)
                if not icons[name] then
                    icons[name] = IconWidget:new{
                        icon = name,
                        width = pager.PN_ICON_SZ,
                        height = pager.PN_ICON_SZ,
                    }
                end
                return icons[name]
            end

            local function paint_icon(bb, name, x, y, enabled)
                local widget = icon(name)
                local old_dim = widget.dim
                widget.dim = not enabled
                widget:paintTo(bb, x, y)
                widget.dim = old_dim
            end

            local function page_text(cur_page, total_pages)
                if ok_gettext and ok_template and template.template then
                    return template.template(gettext("Page %1 of %2"), cur_page, total_pages)
                end
                return "Page " .. tostring(cur_page) .. " of " .. tostring(total_pages)
            end

            pager.paint = function(bb, x, y, w, h, cur_page, total_pages)
                if total_pages <= 1 or pager.getStyle() ~= "page_number" then
                    return original_paint(bb, x, y, w, h, cur_page, total_pages)
                end

                local chev_w = pager.CHEV_W
                local gap = Screen:scaleBySize(12)
                local icon_sz = pager.PN_ICON_SZ
                local icon_y = y + math.floor((h - icon_sz) / 2)
                local icon_x_pad = math.floor((chev_w - icon_sz) / 2)
                local text = page_text(cur_page, total_pages)
                local text_w = RenderText:sizeUtf8Text(0, 9999, face, text, true, false).x
                local face_h = face.bb_size or face.size or Screen:scaleBySize(16)
                local base_y = y + math.floor(h / 2 + face_h * 0.25)
                local group_w = chev_w * 4 + gap * 4 + text_w
                local group_x = x + math.floor(math.max(0, w - group_w) / 2)
                local first_x = group_x
                local prev_x = first_x + chev_w + gap
                local text_x = prev_x + chev_w + gap * 2
                local next_x = text_x + text_w + gap * 2
                local last_x = next_x + chev_w + gap
                local can_go_left = cur_page > 1
                local can_go_right = cur_page < total_pages

                paint_icon(bb, "chevron.first", first_x + icon_x_pad, icon_y, can_go_left)
                paint_icon(bb, "chevron.left", prev_x + icon_x_pad, icon_y, can_go_left)
                RenderText:renderUtf8Text(bb, text_x, base_y, face, text, false, false)
                paint_icon(bb, "chevron.right", next_x + icon_x_pad, icon_y, can_go_right)
                paint_icon(bb, "chevron.last", last_x + icon_x_pad, icon_y, can_go_right)
            end
        end
    end

    local function patch_zen_scroll_bar(apply_fn)
        if type(apply_fn) ~= "function" or rawget(_G, "__oneui_zenui_scrollbar_wrapped") then
            return apply_fn
        end

        rawset(_G, "__oneui_zenui_scrollbar_wrapped", true)

        return function(...)
            local result = apply_fn(...)
            local pager = package.loaded["common/zen_pager"]
            if pager then
                patch_pager(pager)
                patch_menu_first_last_zones(pager)
            end
            return result
        end
    end

    function require(module_name)
        local module = original_require(module_name)
        if module_name == "config/manager" then
            patch_config_manager(module)
        elseif module_name == "common/zen_pager" then
            patch_pager(module)
        elseif module_name == "common/zen_scroll_bar"
            or module_name == "modules/filebrowser/patches/zen_scroll_bar" then
            module = patch_zen_scroll_bar(module)
            package.loaded[module_name] = module
        end
        return module
    end

    local loaded_config_manager = package.loaded["config/manager"]
    if loaded_config_manager then
        patch_config_manager(loaded_config_manager)
    end

    local loaded_pager = package.loaded["common/zen_pager"]
    if loaded_pager then
        patch_pager(loaded_pager)
    end
end
