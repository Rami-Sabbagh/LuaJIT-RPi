--HD44780 LCD Driver

local bits = require("bit")
local band,bor,lshift,rshift = bit.band, bit.bor, bit.lshift, bit.rshift

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
  SPG = tonumber(10000000, 2), --Set page
  DSL = tonumber(11000000, 2), --Display start line
  
  ---Arguments--
  --Display on/off control
  D   = tonumber(00000001, 2), --Display on
}

--WR RD CE C/D RST DB0 1 2 3 4 5 6 7 FS
local pins_ids = {2,3, 14,15,18, 23,24,25,8, 7,12,16,20, 21}
local pins = {}

--Initalize the pins
print("Initializing the pins...")
for i=1,#pins_ids do
  pins[i] = GPIO(pins_ids[i], "in")--i > 5 and "high" or "low")
  pins[i].edge = "none"
  pins[i].direction = "out"
  pins[i]:write(i > 5)
end

local WR, RD, CE, CD, RST = unpack(pins)
local FS = pins[14]

local DB = {} --Data Bus
for i=1,8 do DB[i] = pins[5+i] end --Copy from pins

local DB_WRITE = true

local function setWrite()
  if DB_WRITE then return end
  
  for i=1,8 do
    DB[i].edge = "none"
    DB[i].direction = "out"
  end
  
  DB_WRITE = true
end

local function setRead()
  if not DB_WRITE then return end
  
  for i=1,8 do
    DB[i].direction = "in"
    DB[i].edge = "rising"
  end
  
  DB_WRITE = false
end

local function readDataBus(cd)
  
  --Ensure that the DB pins are in read mode
  setRead()
  
  --Tell that we are reading
  RD:write(false)
  
  --Tell that we are NOT writing
  WR:write(true)
  
  --Data read (cd = false), Status read (cd = true)
  CD:write(cd or false)
  
  --Chip enable
  CE:write(false)
  
  sleep(0.0015)
  
  --Read the data bus
  local states, bits, bitStr = {}, 0, ""
  for i=8,1,-1 do
    local b = DB[i]:read()
    print("read",i,b)
    
    states[i] = b
    bits = bor(lshift(bits,1), b and 1 or 0)
    bitStr = bitStr..(b and "1" or "0")
  end
  
  --Chip disable
  CE:write(true)
  
  --Return the data
  return bits, states, bitStr
  
end

local function logStatus()
  --Read the STA bits
  local _, sta, str = readDataBus(true)
  
  print("----- STATUS READ -----")
  print("Check command execution capability", sta[1])
  print("Check data read/write capability", sta[2])
  print("Check Auto mode data read capability", sta[3])
  print("Check Auto mode data write capability", sta[4])
  print("Check controller operation capability", sta[6])
  print("Error flag. Used for Screen Peek and Screen copy commands", sta[7] and "Error" or "No error")
  print("Check the blink condition", sta[8] and "Blink ON" or "Blink OFF")
  print("------- "..str.." ------")
end

local function checkStatus()
  
  --Ensure that the DB pins are in read mode
  setRead()
  
  --Tell that we are reading
  RD:write(false)
  
  --Tell that we are NOT writing
  WR:write(true)
  
  --Data read (cd = false), Status read (cd = true)
  CD:write(true)
  
  --Chip enable
  CE:write(false)
  
  sleep(0.0015)
  
  if not DB[1]:read() then
    print("Waiting STA0")
    print(DB[1]:poll(0.5) and "Success" or "Failed")
  end
  
  if not DB[2]:read() then
    print("Waiting STA1")
    print(DB[2]:poll(0.5) and "Success" or "Failed")
  end
  
  --Chip disable
  CE:write(true)
  
end

local function writeDataBus(bits,cd)
  
  checkStatus()
  
  --Ensure that the DB pins are in write mode
  setWrite()
  
  --Tell that we are NOT reading
  RD:write(true)
  
  --Tell that we are writing
  WR:write(false)
  
  --Data write (cd = false), Command write (cd = true)
  CD:write(cd or false)
  
  --Send the actual data
  for i=1,8 do
    DB[i]:write(band(bits,1) > 0) --Write the bit
    bits = rshift(bits,1) --Shift right
  end
  
  --Chip enable
  CE:write(false)
  
  sleep(0.001)
  
  --Chip disable
  CE:write(true)
  
  sleep(0.002)
  
end

--Close the GPIO Pins
print("Closing the pins")
for i=1,#pins do
  pins[i].direction = "in" --Set all pins to read
  pins[i]:close()
end

