--- ModMatrix
-- @classmod ModMatrix

local UI = require "ui"
local ScreenState = include("lib/ui/util/screen_state")
local Label = include("lib/ui/util/label")
local ModMatrixUtil = include("lib/ui/util/modmatrix")

local ModMatrix = {}

function ModMatrix:new()
  local i = {}
  setmetatable(i, self)
  self.__index = self

  i.modmatrix = ModMatrixUtil:new()
  i.rows = {}
  i.x = 1
  i.y = 1

  return i
end

function ModMatrix:add_params(pedal_classes)
  if self.modmatrix ~= nil then
    self.modmatrix:init(pedal_classes)
  else
    ModMatrixUtil:new():init(pedal_classes)
  end
end

function ModMatrix:enter()
  -- Called when the page is scrolled to
end

function ModMatrix:add_pedal(pedal, index)
  self.modmatrix:add_pedal(pedal, index)
  self:_calculate_rows()
end

function ModMatrix:remove_pedal(index)
  self.modmatrix:remove_pedal(index)
  self:_calculate_rows()
end

function ModMatrix:_calculate_rows()
  local rows = {}
  for i = 1,#self.modmatrix.pedals do
    local pedal = self.modmatrix.pedals[i]
    if pedal ~= self.modmatrix.EMPTY then
      table.insert(rows, { true, pedal:name() })
      for i, param_id in ipairs(pedal._param_ids_flat) do
        local param = pedal._params_by_id[param_id]
        if self.modmatrix.is_targetable(param) then
          table.insert(rows, { false, param })
        end
      end
    end
  end
  self.rows = rows
  ScreenState.mark_screen_dirty(true)
end

function ModMatrix:key(n, z)
  -- Key-up currently has no meaning
  if z ~= 1 then
    return false
  end

  -- Change the focused column
  local direction = 0
  if n == 2 then
    direction = -1
  elseif n == 3 then
    direction = 1
  end
  self.x = util.clamp(self.x + direction, 1, self.modmatrix.lfos.number_of_outputs)

  return true
end

local lfo_controls = {
  {"Enabled", "lfo"},
  {"Shape", "lfo_shape"},
  {"Freq", "lfo_freq"},
  {"Depth", "lfo_depth"},
  {"Offset", "lfo_offset"},
}
local num_controls_per_lfo = #lfo_controls + 1
local max_x = 125

function ModMatrix:enc(n, delta)
  local num_lfo_controls = num_controls_per_lfo * self.modmatrix.lfos.number_of_outputs
  if n == 2 then
    local scroll_delta = util.clamp(delta, -1, 1)
    self.y = util.clamp(self.y + scroll_delta, 1, #self.rows + num_lfo_controls)
  elseif n == 3 then
    if self.y > num_lfo_controls then
      local row = self.rows[self.y - num_lfo_controls]
      local is_title = row[1]
      if is_title then return false end
      local param = row[2]
      local param_id = self.modmatrix.param_id(param.id, self.x)
      params:delta(param_id, delta)
    else
      local lfo_control_index = (self.y - 1) % num_controls_per_lfo
      local is_title = lfo_control_index == 0
      if is_title then return false end
      local lfo_num = math.floor((self.y - 1) / num_controls_per_lfo) + 1
      local lfo_control = lfo_controls[lfo_control_index]
      params:delta(lfo_num..lfo_control[2], delta)
    end
  end
  return true
end

function ModMatrix:redraw()
  -- Adapted from norns/lua/core/menu/params.lua
  local offset = self.y - 3
  local num_lfo_controls = num_controls_per_lfo * self.modmatrix.lfos.number_of_outputs
  for i=1,6 do
    local index = offset + i
    local row_index = index - num_lfo_controls
    if i==3 then screen.level(15) else screen.level(4) end
    if index >= 1 and row_index < 1 then
      local lfo_control_index = (index - 1) % num_controls_per_lfo
      local is_title = lfo_control_index == 0
      local lfo_num = math.floor((index - 1) / num_controls_per_lfo) + 1
      if is_title then
        screen.move(0,10*i+2.5)
        screen.line_rel(max_x,0)
        screen.stroke()
        screen.move(63,10*i)
        screen.text_center("LFO "..lfo_num)
      else
        local lfo_control = lfo_controls[lfo_control_index]
        screen.move(0,10*i)
        screen.text(lfo_control[1])
        screen.move(max_x,10*i)
        screen.text_right(params:string(lfo_num..lfo_control[2]))
      end
    elseif row_index >= 1 and row_index <= #self.rows then
      local is_title = self.rows[row_index][1]
      if is_title then
        screen.move(0,10*i+2.5)
        screen.line_rel(max_x,0)
        screen.stroke()
        screen.move(63,10*i)
        screen.text_center("Mod Matrix: "..self.rows[row_index][2])
      else
        local param = self.rows[row_index][2]
        screen.move(0,10*i)
        screen.text(param.name)
        for lfo_index = 1,self.modmatrix.lfos.number_of_outputs do
          local param_id = self.modmatrix.param_id(param.id, lfo_index)
          screen.move(max_x - ((self.modmatrix.lfos.number_of_outputs - lfo_index) * 22),10*i)
          if i==3 and self.x == lfo_index then screen.level(15) else screen.level(4) end
          screen.text_right(params:string(param_id))
        end
      end
    end
  end
end

function ModMatrix:cleanup()
  self.modmatrix:cleanup()
end

return ModMatrix
