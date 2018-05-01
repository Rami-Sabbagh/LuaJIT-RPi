--HD44780 LCD Driver

local slowMotion = false--0.01

math.randomseed(os.time())

local bits = require("bit")
local band,bor,bxor,lshift,rshift = bit.band, bit.bor, bit.bxor, bit.lshift, bit.rshift

local floor = math.floor

local socket = require("socket")
local periphery = require('periphery')

local GPIO = periphery.GPIO

print("Using GPIO:",GPIO.version)

local function sleep(seconds)
  socket.sleep(seconds)
end

--Constants
local Const = {
  ---Instructions--
  DOF = tonumber(00111110, 2), --Display On/Off
  SAD = tonumber(01000000, 2), --Set address
  SPG = tonumber(10111000, 2), --Set page
  DSL = tonumber(11000000, 2), --Display start line
  
  ---Arguments--
  --Display on/off control
  D   = tonumber(00000001, 2), --Display on
}

--RS RW E CS1 CS2 RST DB0 1 2 3 4 5 6 7 CS3(Optional)
local pins_ids = {14, 15, 18, 5, 11, 3, 16,26,13,6, 12,7,8,23, 2}
local pins = {}

--Initalize the pins
print("Initializing the pins...")
for i=1,#pins_ids do
  pins[i] = GPIO(pins_ids[i],"low")
end

local DB = {} --Data Bus
for i=1,8 do DB[i] = pins[6+i] end --Copy from pins

local function setRead()
  for i=1,8 do
    --DB[i]:write(false)
    DB[i].direction = "in"
  end
end

local function setWrite()
  for i=1,8 do
    DB[i].direction = "out"
    --DB[i]:write(false)
  end
end

local RS, RW, E = pins[1], pins[2], pins[3] --Control pins
local CS1, CS2, RST = pins[4], pins[5], pins[6] --Chip select and reset
local CS3 = pins[15] --Optional third chip select for bigger displays

local function sendEnablePulse()
  E:write(true)
  sleep(0.000005)
  E:write(false)
  sleep(0.000005)
  if slowMotion then sleep(slowMotion) end
end

--Send a command, or data, anything....
local function sendDataBus(bits,rs,rw)
  --Set RS
  RS:write(rs)
  
  --Set RW
  RW:write(rw)
  
  --Send the actual data
  for i=1,8 do
    DB[i]:write(band(bits,1) > 0) --Write the bit
    bits = rshift(bits,1) --Shift right
  end
  
  sleep(0.000001)
  
  --Toggle Enable Pin
  sendEnablePulse()
  
  RS:write(false)
  RW:write(false)
end

--Send "Display ON/OFF" Instruction
local function sendDisplayOnOff(D)
  local bits = bor(Const.DOF, D and Const.D or 0)
  sendDataBus(bits,false,false)
end

--Send "Set Address" Instruction
local function sendSetAddress(addr)
  local bits = bor(Const.SAD, addr or 0)
  sendDataBus(bits,false,false)
end

--Send "Set Page" Instruction
local function sendSetPage(page)
  local bits = bor(Const.SPG, page or 0)
  sendDataBus(bits,false,false)
end

--Send "Display Start Line" Instruction
local function sendDisplayStartLine(line)
  local bits = bor(Const.DSL, line or 0)
  sendDataBus(bits,false,false)
end

--Reset the controller state to 8-bit mode
local function reset()
  RST:write(false) sleep(0.1)
  RST:write(true) sleep(0.5)
end

local function readStatus()
  setRead()
  
  RW:write(true)
  
  E:write(true)
  sleep(0.000001)
  
  print("Status",DB[8]:read() and "BUSY" or "READY",DB[6]:read() and "OFF" or "ON",DB[5]:read() and "RESET" or "NORMAL")
  
  E:write(false)
  RW:write(false)
  sleep(0.000001)
  
  setWrite()
end

local function readDisplayData(first)
  setRead()
  
  RS:write(true)
  RW:write(true)
  
  E:write(true)
  sleep(0.000001)
  if first then
    E:write(false)
    sleep(0.000005)
    E:write(true)
    sleep(0.000001)
  end
  
  local bits = 0
  local bitstr = ""
  for i=8,1,-1 do
    local b = DB[i]:read() and 1 or 0
    bits = bor(lshift(bits,1),b)
    bitstr = bitstr..b
  end
  
  E:write(false)
  RS:write(false)
  RW:write(false)
  sleep(0.000001)
  
  setWrite()
  
  --print("DATA",bits,bitstr)
  
  return bits
end

local function selectChip(id,all)
  CS1:write(id ~= 1 and not all)
  CS2:write(id ~= 2 and not all)
  if CS3 then CS3:write(id ~= 3 and not all) end
end

local function resetDisplay()
  selectChip(0,true) --Select all the chips
  
  RST:write(false) sleep(0.0001)
  readStatus()
  RST:write(true)
  
  selectChip(0,false) --Deselect all the chips
end

local function initializeChip()
  sendDisplayOnOff(true)
  sendDisplayStartLine(0)
  sendSetAddress(0)
  sendSetPage(0)
end

local function initializeDisplay()
  selectChip(0,true)
  
  initializeChip()
  
  selectChip(1)
end

local function clearChip(value)
  for page=0,7 do
    sendSetPage(page)
    for i=0,63 do
      sendDataBus(value or 0,true,false)
    end
  end
  sendSetPage(0)
end

local function clearDisplay(value)
  selectChip(0,true) --Select all the chips
  
  clearChip(value)
  
  selectChip(1) --Select chip 1
end

local function invertPixel(x,y)
  selectChip(1 + floor(x/64)) --Select the chip
  sendSetPage(floor(y/8)) --Select the page
  sendSetAddress(x%64) --Select the address
  
  local byte = readDisplayData(true) --Read that byte
  
  --Set the pixel bit
  byte = bxor(byte,2^(y%8))
  
  sendSetAddress(x%64) --Select the address
  
  sendDataBus(byte,true,false) --Sen the new byte
end

local function setPixel(x,y,pv)
  selectChip(1 + floor(x/64)) --Select the chip
  sendSetPage(floor(y/8)) --Select the page
  sendSetAddress(x%64) --Select the address
  
  local byte = readDisplayData(true) --Read that byte
  
  --Set the pixel bit
  if pv then
    byte = bor(byte,2^(y%8))
  else
    byte = band(byte,bxor(255, 2^(y%8)))
  end
  
  sendSetAddress(x%64) --Select the address
  
  sendDataBus(byte,true,false) --Sen the new byte
end

local function fillRect(x,y,w,h,line,invert)
  if line then
  
    for px=x,x+w-1 do
      setPixel(px,y,not invert)
      setPixel(px,y+h-1,not invert)
    end
    for py=y+1,y+h-2 do
      setPixel(x,py,not invert)
      setPixel(x+w-1,py,not invert)
    end
    
  else
  
    for py=y, y+h-1 do
      for px=x, x+w-1 do
        setPixel(px,py,not invert)
      end
    end
    
  end
end

print("GLCD RESET")

resetDisplay()

print("GLCD INIT")

initializeDisplay()
readStatus()

print("GLCD CLEAR")

--clearDisplay(255)
clearDisplay()

print("GLCD DEMO")

--fillRect(1,1,18,18,false)
--fillRect(3,3,14,14,true,true)
--fillRect(4,4,12,12,true,true)

selectChip(0,true) --Select all chips

--[[for page=0,7 do
  sendSetPage(page)
  for i=0,63 do
    local data = (i%2 > 0 ) and 10101010 or 01010101
    sendDataBus(tonumber(data,2),true,false)
  end
end]]

for chip=1,(CS3 and 3 or 2) do
  selectChip(chip)
  for page=0,7 do
    sendSetPage(page)
    for i=0,63 do
      sendDataBus(math.random(0,255),true,false)
    end
  end
end

--Close the GPIO Pins
print("Closing the pins")
for i=1,#pins do
  pins[i]:write(i == 6) --Leave the RST pin on
  pins[i]:close()
end

