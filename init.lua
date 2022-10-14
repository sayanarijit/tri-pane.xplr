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

local function datetime(num)
  return tostring(os.date("%a %b %d %H:%M:%S %Y", num / 1000000000))
end

local function stat(node)
  return node.absolute_path
      .. "\n Type: "
      .. node.mime_essence
      .. "\n Size: "
      .. node.human_size
      .. "\n Created: "
      .. datetime(node.created)
      .. "\n Modified: "
      .. datetime(node.last_modified)
      .. "\n Owner: "
      .. string.format("%s:%s", node.uid, node.gid)
end

local function read(path, height)
  local p = io.open(path)

  if p == nil then
    return nil
  end

  local i = 0
  local res = ""
  for line in p:lines() do
    if line:match("[^ -~\n\t]") then
      return
    end

    res = res .. line .. "\n"
    if i == height then
      break
    end
    i = i + 1
  end
  p:close()

  return res
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

local function list(path, height)
  if state.listings[path] == nil then
    local files = {}
    local tmpfile = os.tmpname()

    assert(io.popen("ls -a " .. quote(path) .. " > " .. tmpfile .. " 2> /dev/null ")):close()

    local pfile = assert(io.open(tmpfile))
    local i = 1
    for file in pfile:lines() do
      if i > height + 1 then
        break
      elseif i > 2 then
        table.insert(files, file)
      else
        i = i + 1
      end
    end
    pfile:close()
    os.remove(tmpfile)

    state.listings[path] = { files = files, focus = 0 }
  end
  return state.listings[path]
end

local function render_left_pane(ctx)
  local parent, _ = dirname(ctx.app.pwd)
  local listing = { focus = 0, files = {} }
  if parent == "/" then
    -- Empty
  elseif parent == "" then
    listing = state.listings["/"] or list("/", ctx.layout_size.height)
  else
    listing = state.listings[parent] or list(parent, ctx.layout_size.height)
  end
  return offset(listing, ctx.layout_size.height)
end

local function render_right_pane(ctx)
  local n = ctx.app.focused_node

  if n then
    if n.is_file then
      local success, res = pcall(read, n.absolute_path, ctx.layout_size.height)
      if success and res ~= nil then
        return res
      else
        return stat(n)
      end
    elseif n.is_dir then
      local res = offset(
        state.listings[n.absolute_path] or list(n.absolute_path, ctx.layout_size.height),
        ctx.layout_size.height
      )
      return table.concat(res, "\n")
    else
      return stat(n)
    end
  else
    return {}
  end
end

local left_pane = {
  CustomContent = {
    body = {
      DynamicList = {
        render = "custom.tri_pane.render_left_pane",
      },
    },
  },
}

local right_pane = {
  CustomContent = {
    body = {
      DynamicParagraph = {
        render = "custom.tri_pane.render_right_pane",
      },
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

  args.layout_key = args.layout_key or "T"

  args.left_pane_width = args.left_pane_width or { Percentage = 20 }
  args.middle_pane_width = args.middle_pane_width or { Percentage = 50 }
  args.right_pane_width = args.right_pane_width or { Percentage = 30 }

  args.left_pane_renderer = args.left_pane_renderer or render_left_pane
  args.right_pane_renderer = args.right_pane_renderer or render_right_pane

  xplr.fn.custom.tri_pane = {}
  xplr.fn.custom.tri_pane.render_left_pane = args.left_pane_renderer
  xplr.fn.custom.tri_pane.render_right_pane = args.right_pane_renderer
  xplr.fn.custom.tri_pane.enter = enter
  xplr.fn.custom.tri_pane.back = back

  local layout = {
    Horizontal = {
      config = {
        constraints = {
          args.left_pane_width,
          args.middle_pane_width,
          args.right_pane_width,
        },
      },
      splits = {
        left_pane,
        "Table",
        right_pane,
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

  xplr.config.layouts.custom.tri_pane = full_layout

  if args.as_default_layout then
    xplr.config.layouts.builtin.default = full_layout
  else
    xplr.config.layouts.custom.tri_pane = full_layout
    xplr.config.modes.builtin.switch_layout.key_bindings.on_key[args.layout_key] = {
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
