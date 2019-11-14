local debug = true
local binary_out = true

function arr_to_hex(arr)
   local str = ''
   for i = 0, 7 do
      str = str .. arr[i]
   end
   return string.format("%2.2X", tonumber(str,2))
end

function arr_to_dex(arr)
   local str = ''
   for i = 0,7 do
      str = str .. arr[i]
   end
   return tonumber(str,2)
end

if app.apiVersion < 1 then
  return app.alert("This script requires Aseprite v1.2.10-beta3")
end

if not app.activeImage then
  return app.alert("There is no active image")
end

if app.activeImage.colorMode ~= ColorMode.INDEXED then
   return app.alert("This script requires an indexed image")
end

if #app.activeSprite.palettes[1] ~= 4 then
   return app.alert("This image has " .. #app.activeSprite.palettes[1] .. " colors, this script requires the palette to only have 4.")
end

if app.activeLayer ~= app.activeSprite.backgroundLayer then
   return app.alert("Please select the background layer (due to API limitations)")
end



-- need to loop through the layers
-- start with bottommost layer and go through the top layer
-- will only do current frame for now

app.command.FlattenLayers{visibleOnly=true}
local img = app.activeImage;

local w = img.width;
local h = img.height;

if w % 8 ~= 0 or h % 8 ~= 0 then
   app.command.Undo();
   return app.alert("This image has a width ("..w.."px) or height("..h.."px) not divisible by 8px, and can't be processed.")
end
app.command.Undo()

-- frame stuff
local spr = app.activeSprite

local outstr = ""
local arr = {};
for i = 0, h - 1 do
   arr[i] = {}
end
byteout = {}


for i,layer in ipairs(spr.layers) do
   if layer.isBackground == false then
      for j,hideme in ipairs(spr.layers) do
         if layer ~= hideme and hideme.isBackground == false then
            hideme.isVisible = false
         elseif layer == hideme or hideme.isBackground == true then
            hideme.isVisible = true
         end
      end

      outstr = outstr .. "\n;" .. layer.name .. "\nDB "

      app.command.FlattenLayers{visibleOnly = true}
      -- capture pixels into the array
      -- doing it this way so we dont have to worry about
      -- x/y not iterating through x then y += 1
      img = app.activeImage
      for i in img:pixels() do
         --print(i.x .. " | " .. i.y .. " | " .. i())
         arr[i.y][i.x] = i()
      end

      local b1 = {};
      local b2 = {};
      local bytes = {};
      
      --[[
      pixel format:
      0 - [0,0]
      1 - [1,0]
      2 - [0,1]
      3 - [1,1]
      ]]
      x = 0
      xcol = 0
      y = 0

      for i = 0, 7 do
         b1[i] = 0
         b2[i] = 0
      end
      --for y,i in pairs(arr) do
      while true do
         p = arr[y][x]
         md = x % 8
         if p == 1 then
            b1[md] = 1
         elseif p == 2 then
            b2[md] = 1
         elseif p == 3 then
            b1[md] = 1
            b2[md] = 1
         end
         if md == 7 then
            bytes[#bytes + 1] = arr_to_hex(b1)
            bytes[#bytes + 1] = arr_to_hex(b2)
            byteout[#byteout + 1] = arr_to_dex(b1)
            byteout[#byteout + 1] = arr_to_dex(b2)
            for i = 0, 7 do
               b1[i] = 0
               b2[i] = 0
            end
            y = y + 1
            if y == h then
               xcol = xcol + 8
               y = 0
               if xcol == w then break end
            end
            x = xcol
         else
            x = x + 1
         end
         if x == 1000 and debug then break end
      end
      -- make output string
      for i, b in ipairs(bytes) do
         if (i - 1) % 8 == 0 and i ~= 1 then
            outstr = outstr .. "\nDB "
         elseif i ~= 1 then
            outstr = outstr .. ","
         end
         outstr = outstr .. "$" .. b
      end
      app.command.Undo()
   end
end

if (not debug) or binary_out then
   local dlg = Dialog()
   dlg:file {  id="save_loc",
            label = "Save location:",
            title = "Export file",
            open = false,
            save = true,
            entry = true,
            }
   dlg:button{ id="ok", text="OK" }
   dlg:button{ id="cancel", text="Cancel" }
   dlg:show()
   data = dlg.data
   if data.ok then
      if binary_out then
         local file = io.open(data.save_loc, 'w+b')
         local str = ''
         for i = 1, #byteout do
            str = str .. string.char(byteout[i])
         end
         -- local str = string.char(unpack(byteout))
         file:write(str)
         file:close()
         print(outstr)
      else
         local file = io.open(data.save_loc, "w+")
         file:write(outstr)
         file:close()
         app.alert("Exported to " .. data.save_loc .. ".")
      end
   end
else
   print(outstr)
end
-- undo FlattenLayers
app.command.Undo();
