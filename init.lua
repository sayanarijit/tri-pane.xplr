---@diagnostic disable
local xplr = xplr
---@diagnostic enable

local no_color = os.getenv("NO_COLOR")

local function green(x)
  if no_color == nil then
    return "\x1b[32m" .. x .. "\x1b[0m"
  else
    return x
  end
end

local function yellow(x)
  if no_color == nil then
    return "\x1b[33m" .. x .. "\x1b[0m"
  else
    return x
  end
end

local function red(x)
  if no_color == nil then
    return "\x1b[31m" .. x .. "\x1b[0m"
  else
    return x
  end
end

local function bit(x, color, cond)
  if cond then
    return color(x)
  else
    return color("-")
  end
end

local function datetime(num)
  return tostring(os.date("%a %b %d %H:%M:%S %Y", num / 1000000000))
end

local function permissions(p)
  local r = ""

  r = r .. bit("r", green, p.user_read)
  r = r .. bit("w", yellow, p.user_write)

  if p.user_execute == false and p.setuid == false then
    r = r .. bit("-", red, p.user_execute)
  elseif p.user_execute == true and p.setuid == false then
    r = r .. bit("x", red, p.user_execute)
  elseif p.user_execute == false and p.setuid == true then
    r = r .. bit("S", red, p.user_execute)
  else
    r = r .. bit("s", red, p.user_execute)
  end

  r = r .. bit("r", green, p.group_read)
  r = r .. bit("w", yellow, p.group_write)

  if p.group_execute == false and p.setuid == false then
    r = r .. bit("-", red, p.group_execute)
  elseif p.group_execute == true and p.setuid == false then
    r = r .. bit("x", red, p.group_execute)
  elseif p.group_execute == false and p.setuid == true then
    r = r .. bit("S", red, p.group_execute)
  else
    r = r .. bit("s", red, p.group_execute)
  end

  r = r .. bit("r", green, p.other_read)
  r = r .. bit("w", yellow, p.other_write)

  if p.other_execute == false and p.setuid == false then
    r = r .. bit("-", red, p.other_execute)
  elseif p.other_execute == true and p.setuid == false then
    r = r .. bit("x", red, p.other_execute)
  elseif p.other_execute == false and p.setuid == true then
    r = r .. bit("T", red, p.other_execute)
  else
    r = r .. bit("t", red, p.other_execute)
  end

  return r
end

local function stat(node)
  local type = node.mime_essence
  if node.is_symlink then
    if node.is_broken then
      type = "broken symlink"
    else
      type = "symlink to: " .. node.symlink.absolute_path
    end
  end

  return "Type     : "
      .. type
      .. "\nSize     : "
      .. node.human_size
      .. "\nOwner    : "
      .. string.format("%s:%s", node.uid, node.gid)
      .. "\nPerm     : "
      .. permissions(node.permissions)
      .. "\nCreated  : "
      .. datetime(node.created)
      .. "\nModified : "
      .. datetime(node.last_modified)
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
      p:close()
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

local function offset(listing, height)
  local h = height - 3
  local start = (listing.focus - (listing.focus % h))
  local result = {}
  for i = start + 1, start + h, 1 do
    table.insert(result, listing.files[i])
  end
  return result
end

local function list(parent, focused, explorer_config, height)
  local files, focus = {}, 0
  local config = { sorters = explorer_config.sorters }
  local ok, nodes = pcall(xplr.util.explore, parent, config)
  if not ok then
    nodes = {}
  end

  for i, node in ipairs(nodes) do
    if i > height + 1 then
      break
    else
      local rel = node.relative_path
      if rel == focused then
        focus = i
      end
      if node.is_dir then
        rel = rel .. "/"
      end
      table.insert(files, rel)
    end
  end

  return { files = files, focus = focus }
end

local function tree_view(files, focus)
  local count = #files
  local res = {}
  for i, file in ipairs(files) do
    local arrow, tree = " ", "├"
    if i == focus then
      arrow = "▸"
    end
    if i == count then
      tree = "└"
    end
    table.insert(res, tree .. arrow .. file)
  end
  return res
end

local function render_left_pane(ctx)
  if ctx.app.pwd == "/" then
    return {}
  end

  local parent = xplr.util.dirname(ctx.app.pwd)
  local focused = xplr.util.basename(ctx.app.pwd)
  local listing = list(parent, focused, ctx.app.explorer_config, ctx.layout_size.height)
  return tree_view(offset(listing, ctx.layout_size.height), listing.focus)
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
      local listing =
      list(n.absolute_path, nil, ctx.app.explorer_config, ctx.layout_size.height)
      local visible = offset(listing, ctx.layout_size.height)
      return table.concat(tree_view(visible, listing.focus), "\n")
    else
      return stat(n)
    end
  else
    return ""
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
end

return { setup = setup }
