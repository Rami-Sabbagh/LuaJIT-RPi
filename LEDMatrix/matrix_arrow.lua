--8x5 LED Matrix

local json = dofile("/home/pi/Desktop/Matrix/json.lua")
local socket = require("socket")
local periphery = require('periphery')

local GPIO = periphery.GPIO

print("Using GPIO:",GPIO.version)

print("Loading the font...")
local fontfile = io.open("/home/pi/Desktop/Matrix/font.json","r")
local fontjson = fontfile:read("*a") --Read all the file
fontfile:close() --Close the font file
local font = json:decode(fontjson)

local function sleep(seconds)
	socket.sleep(seconds)
end

local pins = {2,3,4, 17,27,22, 10,9,11, 5,6,13,19}

--Initalize the pins
print("Initializing the pins...")
for i=1,#pins do
  pins[i] = GPIO(pins[i],"out")
end

--Disable all the digits & segments
print("Disabling all the digits & segments")
for i=1,#pins do
  pins[i]:write(i <= 5)
end

--Display API
local disp = {} --disp[x][y]
for i=1,8 do
  disp[i] = {false,false,false,false,false}
end

--Set a pixel, 0 based.
local function setPixel(x,y,on)
  local x,y = math.floor(x), math.floor(y)
  if x < 0 or x > 7 or y < 0 or y > 4 then return end
  disp[x+1][y+1] = on and true or false
end

--Draw a rectangle (filled or border)
local function rect(x,y,w,h,on,fill)
  for px=x,x+w-1 do
   for py=y,y+h-1 do
    if fill or (px == x or px == x+w-1 or py == y or py == y+h-1) then
      setPixel(px,py,on)
    end
   end
  end
end

--Clear the screen
local function clear(on)
  rect(0,0,8,5,on,true)
end

--Sroll the screen to the left
local function scrollLeft()
  local firstScanline = disp[1]
  for i=2,8 do
    disp[i-1] = disp[i]
  end
  disp[8] = firstScanline
end

local sltime = (1/120)/8 --Scanline time.

local function render(timer)
  local timer = timer or 1
  while timer > 0 do
    --Scanlines
    for i=1,8 do
      --Set the scanline pixels
      for p=1,5 do
        pins[p]:write(not disp[i][p])
      end
      
      --Enabe the scanline
      pins[5+i]:write(true)
      
      sleep(sltime)
      
      --Disable the scanline
      pins[5+i]:write(false)
    end
    
    timer = timer - sltime*8
  end
end

setPixel(7,1,true) setPixel(6,2,true) setPixel(7,3,true)

for i=0,16 do
  render(0.5)
  scrollLeft()
end

--Close the GPIO Pins
print("Closing the pins")
for i=1,#pins do
  pins[i]:write(i <= 5)
  pins[i]:close()
end
