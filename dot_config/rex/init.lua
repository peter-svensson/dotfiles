-- Port of ~/.tmux.conf to Rex. Prefix stays ctrl+space.
local P = "ctrl+space>"

-- prefix twice (or prefix a, as in tmux) sends ctrl+space to the program
rex.bind(P .. "ctrl+space", "pane.send_key", { key = "ctrl+space" })
rex.bind(P .. "a", "pane.send_key", { key = "ctrl+space" })

-- splits: | and - (Rex starts splits in the pane's cwd when the shell reports it)
-- Keys follow the keyboard layout: on Swedish, | is alt+7 and [ is alt+8
rex.bind(P .. "alt+7", "pane.split", { direction = "right" })
rex.bind(P .. "-", "pane.split", { direction = "down" })

-- tmux defaults that muscle memory relies on
rex.bind(P .. "c", "client.tab.new")
rex.bind(P .. "n", "client.tab.next")
rex.bind(P .. "p", "client.tab.previous")
rex.bind(P .. ",", "client.tab.rename")
rex.bind(P .. "x", "pane.close")
rex.bind(P .. "z", "pane.zoom")
rex.bind(P .. "s", "session.switch")
rex.bind(P .. "d", "client.close")
rex.bind(P .. "r", "client.config.reload")
rex.bind(P .. "alt+8", "client.find.open")
for i = 1, 9 do
  rex.bind(P .. i, "client.tab.goto", { index = i })
end

-- alt+arrows switch panes without prefix
rex.bind("alt+left", "pane.focus.left")
rex.bind("alt+right", "pane.focus.right")
rex.bind("alt+up", "pane.focus.up")
rex.bind("alt+down", "pane.focus.down")

-- prefix C-l: pass ctrl+l through (Rex has no clear-history action)
rex.bind(P .. "ctrl+l", "pane.send_key", { key = "ctrl+l" })

-- Claude Code newline, was ghostty keybind shift+enter=text:\x1b\r
rex.bind("shift+enter", "pane.send_key", { key = "alt+enter" })

-- prefix b: focus the next terminal whose program reports done/blocked/error
-- (replaces tmux-jump-bell + the @bell/@agent markers)
local ATTENTION = { done = true, blocked = true, error = true }
local TERMINAL = "com.superlogical.terminal"

local function needs_attention(block_id)
  local r = rex.block.call(TERMINAL, "program_status", { block_id = block_id })
  for _, rec in ipairs((r and r.records) or {}) do
    if ATTENTION[rec.state] then return true end
  end
  return false
end

rex.action{
  name  = "jump_attention",
  title = "Jump to Terminal Needing Attention",
  run   = function(ctx, args)
    local view, err = rex.session.view{}
    if err ~= nil then error(err, 0) end
    for _, w in ipairs(view.windows or {}) do
      for _, layer in ipairs(w.layers or {}) do
        for _, b in ipairs(layer.blocks or {}) do
          if b.block_id ~= ctx.block_id and b.creator_name == TERMINAL
              and needs_attention(b.block_id) then
            rex.session.focus_block{ block_id = b.block_id }
            return
          end
        end
      end
    end
  end,
}
rex.bind(P .. "b", "jump_attention")
