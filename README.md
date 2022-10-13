# tri-pane.xplr

xplr plugin that implements ranger-like three pane layout support.

https://user-images.githubusercontent.com/11632726/195410250-51cfe26d-5ca3-472d-9d89-16a8a86e8f36.mp4

## Installation

### Install manually

- Add the following line in `~/.config/xplr/init.lua`

  ```lua
  local home = os.getenv("HOME")
  package.path = home
  .. "/.config/xplr/plugins/?/init.lua;"
  .. home
  .. "/.config/xplr/plugins/?.lua;"
  .. package.path
  ```

- Clone the plugin

  ```bash
  mkdir -p ~/.config/xplr/plugins

  git clone https://github.com/sayanarijit/tri-pane.xplr ~/.config/xplr/plugins/tri-pane
  ```

- Require the module in `~/.config/xplr/init.lua`

  ```lua
  require("tri-pane").setup()

  -- or

  require("tri-pane").setup({
    layout_key = "T", -- In switch_layout mode
    as_default_layout = true,
    left_pane_width = { Percentage = 20 },
    middle_pane_width = { Percentage = 50 },
    right_pane_width = { Percentage = 30 },
  })
  ```

## Usage

If you have set `as_default_layout = false`, you need to switch to this mode manually by
pressing `ctrl-w` and then `T`.
