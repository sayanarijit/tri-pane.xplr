---@diagnostic disable
local xplr = xplr
---@diagnostic enable

local state = {
  listings = {},
}
local function quote(str)
  return "'" .. string.gsub(str, "'", [['"'"']]) .. "'"
end

local function invert(text)
  return "\x1b[1;7m " .. text .. " \x1b[0m"
end

local function stat(node)
  return { node.mime_essence }
end

local function read(path, height)
  local p = io.open(path)

  if p == nil then
    return stat(path)
  end

  local i = 0
  local lines = {}
  for line in p:lines() do
    table.insert(lines, line)
    if i == height then
      break
    end
    i = i + 1
  end
  p:close()

  return lines
end

local function dirname(filepath)
  local is_changed = false
  local result = filepath:gsub("/([^/]+)$", function()
    is_changed = true
    return ""
  end)
  return result, is_changed
end

local function offset(listing, height)
  local h = height - 3
  local start = (listing.focus - (listing.focus % h))
  local result = {}
  for i = start + 1, start + h, 1 do
    table.insert(result, listing.files[i])
  end
  return result
end

local function list(path)
  if state.listings[path] == nil then
    local files = {}
    local pfile = assert(io.popen("ls -a " .. quote(path)))
    local i = 1
    for file in pfile:lines() do
      if i > 2 then
        table.insert(files, file)
      else
        i = i + 1
      end
    end
    pfile:close()

    state.listings[path] = { files = files, focus = 0 }
  end
  return state.listings[path]
end

local function render_parent(ctx)
  local parent, _ = dirname(ctx.app.pwd)
  local listing = { focus = 0, files = {} }
  if parent == "/" then
    -- Empty
  elseif parent == "" then
    listing = state.listings["/"] or list("/")
  else
    listing = state.listings[parent] or list(parent)
  end
  return offset(listing, ctx.layout_size.height)
end

local function render_focus(ctx)
  local n = ctx.app.focused_node

  if n and n.canonical then
    n = n.canonical
  end

  if n then
    if n.is_file then
      return read(n.absolute_path, ctx.layout_size.height)
    elseif n.is_dir then
      return offset(
        state.listings[n.absolute_path] or list(n.absolute_path),
        ctx.layout_size.height
      )
    else
      return stat(n)
    end
  else
    return {}
  end
end

local parent = {
  CustomContent = {
    body = {
      DynamicList = {
        render = "custom.tri_pane.render_parent",
      },
    },
  },
}

local focus = {
  CustomContent = {
    body = {
      DynamicList = {
        render = "custom.tri_pane.render_focus",
      },
    },
  },
}

local layout = {
  Horizontal = {
    config = {
      constraints = {
        { Percentage = 30 },
        { Percentage = 40 },
        { Percentage = 30 },
      },
    },
    splits = {
      parent,
      "Table",
      focus,
    },
  },
}

local full_layout = {
  Vertical = {
    config = {
      constraints = {
        { Length = 3 },
        { Min = 1 },
        { Length = 3 },
      },
    },
    splits = {
      "SortAndFilter",
      layout,
      "InputAndLogs",
    },
  },
}

local function capture(app)
  local files = {}
  for i, node in ipairs(app.directory_buffer.nodes) do
    local path = node.relative_path
    if i == app.directory_buffer.focus + 1 then
      path = invert(path)
    end
    table.insert(files, path)
  end

  state.listings[app.pwd] = { files = files, focus = app.directory_buffer.focus }
end

local function enter(app)
  capture(app)
  return {
    "Enter",
  }
end

local function back(app)
  capture(app)
  return {
    "Back",
  }
end

local function setup(args)
  args = args or {}
  if args.as_default_layout == nil then
    args.as_default_layout = true
  end

  xplr.fn.custom.tri_pane = {}
  xplr.fn.custom.tri_pane.render_parent = render_parent
  xplr.fn.custom.tri_pane.render_focus = render_focus
  xplr.fn.custom.tri_pane.enter = enter
  xplr.fn.custom.tri_pane.back = back

  xplr.config.layouts.custom.tri_pane = full_layout

  if args.as_default_layout then
    xplr.config.layouts.builtin.default = full_layout
  else
    xplr.config.layouts.custom.tri_pane = full_layout
    xplr.config.modes.builtin.switch_layout.key_bindings.on_key.T = {
      help = "tri pane",
      messages = {
        "PopMode",
        { SwitchLayoutCustom = "tri_pane" },
      },
    }
  end

  xplr.config.modes.builtin.default.key_bindings.on_key.right.messages = {
    { CallLuaSilently = "custom.tri_pane.enter" },
  }

  xplr.config.modes.builtin.default.key_bindings.on_key.left.messages = {
    { CallLuaSilently = "custom.tri_pane.back" },
  }
end

return { setup = setup }
