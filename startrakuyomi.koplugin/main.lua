local InputContainer = require("ui/widget/container/inputcontainer")
local UIManager = require("ui/uimanager")
local Event = require("ui/event")
local T = require("ffi/util").template
local _ = require("gettext")

---@diagnostic disable: undefined-global -- G_reader_settings is a KOReader runtime global

local AutoRakuyomi = InputContainer:extend({
  name = "startrakuyomi",
})

function AutoRakuyomi:init()
  -- self.ui.name is "ReaderUI" in the reader context, nil in the FM context.
  -- FileManager does not set a name field on the class, so we guard by
  -- checking for the ReaderUI case and bailing out; everything else is FM.
  if self.ui.name == "ReaderUI" then
    return
  end

  -- ---------------------------------------------------------------------------
  -- "Start with Rakuyomi" menu entry
  -- Injects the Rakuyomi radio item into KOReader's Start With submenu.
  -- Patched once per session; a flag on the class prevents double-patching.
  -- ---------------------------------------------------------------------------
  local ok_fmm, FileManagerMenu = pcall(require, "apps/filemanager/filemanagermenu")
  if ok_fmm and FileManagerMenu and not FileManagerMenu._startrakuyomi_patched then
    local orig_fn = FileManagerMenu.getStartWithMenuTable
    if orig_fn then
      FileManagerMenu._startrakuyomi_patched = true
      FileManagerMenu._startrakuyomi_orig    = orig_fn

      --- Overrides the default Start With menu table to inject a Rakuyomi option.
      --- @param fmm_self table The FileManagerMenu instance.
      --- @return table result The modified menu table with the Rakuyomi entry added.
      FileManagerMenu.getStartWithMenuTable = function(fmm_self)
        local result = orig_fn(fmm_self)
        local sub    = result.sub_item_table
        if type(sub) ~= "table" then return result end

        -- Add the entry only if it is not already present.
        local rakuyomi_label = _("Rakuyomi")
        local found = false
        for _, item in ipairs(sub) do
          if item.text == rakuyomi_label and item.radio then found = true; break end
        end
        if not found then
          table.insert(sub, math.max(1, #sub), {
            text         = rakuyomi_label,
            checked_func = function()
              return G_reader_settings:readSetting("start_with") == "startrakuyomi"
            end,
            callback = function()
              G_reader_settings:saveSetting("start_with", "startrakuyomi")
            end,
            radio = true,
          })
        end

        -- Update the parent item label when Rakuyomi is the active choice.
        -- Use the same T(_("Start with: %1"), ...) format as KOReader's own
        -- entries so the translated string is found correctly.
        local orig_text_func = result.text_func
        result.text_func = function()
          if G_reader_settings:readSetting("start_with") == "startrakuyomi" then
            return T(_("Start with: %1"), rakuyomi_label)
          end
          return orig_text_func and orig_text_func() or _("Start with")
        end

        return result
      end
    end
  end
end

-- Received when UIManager:show(file_manager) fires the Show event.
-- WidgetContainer:handleEvent propagates Show to all registered child
-- plugins before calling the FM's own onShow, so this fires reliably.
function AutoRakuyomi:onShow()
  if self._started then return end
  self._started = true
  if G_reader_settings:readSetting("start_with") == "startrakuyomi" then
    UIManager:scheduleIn(0, function()
      UIManager:broadcastEvent(Event:new("StartLibraryView"))
    end)
  end
end

return AutoRakuyomi

