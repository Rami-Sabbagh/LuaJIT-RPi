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
  CLR = tonumber(00000001, 2), --Clear display
  CRH = tonumber(00000010, 2), --Cursor home
  EMS = tonumber(00000100, 2), --Entry mode set
  DCT = tonumber(00001000, 2), --Display on/off control
  CDS = tonumber(00010000, 2), --Cursor/display shift
  FCS = tonumber(00100000, 2), --Function set
  SCA = tonumber(01000000, 2), --Set CGRAM address
  SDA = tonumber(10000000, 2), --Set DDRAM address
  
  ---Arguments--
  --Entry mode
  S  = tonumber(00000001, 2), --Display shift
  ID = tonumber(00000010, 2), --Input Direction, Increment cursor pos.
  
  --Display on/off control
  B  = tonumber(00000001, 2), --Cursor blink on
  C  = tonumber(00000010, 2), --Cursor on
  D  = tonumber(00000100, 2), --Display on
  
  --Cursor/display shift
  RL = tonumber(00000100, 2), --Shift right
  SC = tonumber(00001000, 2), --Shift display
  
  --Function set
  F  = tonumber(00000100, 2), --5x10 dots
  N  = tonumber(00001000, 2), --1/16 duty (2 lines)
  DL = tonumber(00010000, 2)  --8Bit interface
}

--RS RW E DB0 1 2 3 4 5 6 7
--local pins = {8,10,12, 16,18, 22,24,26, 32, 36,38}
local pins = {2,3,12, 4,18, 17,24,27, 32, 36,22}

--Initalize the pins
print("Initializing the pins...")
for i=1,#pins do
  pins[i] = GPIO(pins[i],"low")
end

io.read()

local DB = {} --Data Bus
for i=1,8 do DB[i] = pins[3+i] end --Copy from pins

local RS, RW, E = pins[1], pins[2], pins[3] --Control pins

--Send a command, or data, anything....
local function sendDataBus(bits,rs,rw)
  --Set RS
  RS:write(rs)
  
  --Set RW
  RW:write(rw)
  
  --Toggle Enable Pin
  E:write(true)
  
  --Send the actual data
  for i=1,8 do
    DB[i]:write(band(bits,1) > 0) --Write the bit
    bits = rshift(bits,1) --Shift right
  end
  
  --Toggle Enable Pin
  E:write(false) sleep(0.0001)
end

--Send "Clear Display" Command
local function sendClearDisplay()
  sendDataBus(Const.CLR,false,false)
  sleep(0.03) --This command takes lots of time
end

--Send "Cursor Home" Command
local function sendCursorHome()
  sendDataBus(Const.CRH,false,false)
  sleep(0.03) --This command takes lots of time
end

--Send "Entry mode set" Command
local function sendEntryModeSet(ID,S)
  local bits = bor(Const.EMS, ID and Const.ID or 0, S and Const.S or 0)
  sendDataBus(bits,false,false)
end

--Send "Display On/Off Control" Command
local function sendDisplayOnOffControl(D,C,B)
  local bits = bor(Const.DCT, D and Const.D or 0, C and Const.C or 0, B and Const.B or 0)
  sendDataBus(bits,false,false)
end

--Send "Cursor/Display Shift" Command
local function sendCursorDisplayShift(SC,RL)
  local bits = bor(Const.CDS, SC and Const.SC or 0, RL and Const.RL or 0)
  sendDataBus(bits,false,false)
end

--Send "Function Set" Command: DataLength,DisplayLine,CharacterFont
local function sendFunctionSet(DL,N,F)
  local bits = bor(Const.FCS, DL and Const.DL or 0, N and Const.N or 0, F and Const.F or 0)
  sendDataBus(bits,false,false)
end

--Send "SetCGRAMAddress" Command
local function sendCGRAMAddress(addr)
  local bits = bor(Const.SCA, addr or 0)
  sendDataBus(bits,false,false)
end

--Send "SetDDRAMAddress" Command
local function sendDDRAMAddress(addr)
  local bits = bor(Const.SDA, addr or 0)
  sendDataBus(bits,false,false)
end

--Reset the controller state to 8-bit mode
local function reset()
  sendFunctionSet(true,false,false) sleep(0.005)
  sendFunctionSet(true,false,false) sleep(0.005)
  sendFunctionSet(true,false,false) sleep(0.005)
  sendFunctionSet(true,true,false)
  sendDisplayOnOffControl(true,false,false)
  sendEntryModeSet(true,false)
end

--Send a string of data to the screen
local function sendString(str)

  for char in string.gmatch(str,".") do
    local char = string.byte(char)
    sendDataBus(char,true,false)
  end
  
end

print("Screen reset")

reset()

print("Send clear")

sendClearDisplay()

print("Send custom char")

sendCGRAMAddress(0)

sendDataBus(tonumber(00000, 2),true,false) --|-----|
sendDataBus(tonumber(01010, 2),true,false) --|-#-#-|
sendDataBus(tonumber(01010, 2),true,false) --|-#-#-|
sendDataBus(tonumber(00000, 2),true,false) --|-----|
sendDataBus(tonumber(10001, 2),true,false) --|#---#|
sendDataBus(tonumber(01110, 2),true,false) --|-###-|
sendDataBus(tonumber(00000, 2),true,false) --|-----|
sendDataBus(tonumber(00000, 2),true,false) -- Cursor line !

print("Send data")

sendDDRAMAddress(0)

sendString("Time "..string.char(0),".")

sendDDRAMAddress(40)

sendString(" Lua for ever ! ")

while true do
  sendDDRAMAddress(8)
  
  sendString(os.date("%H:%M:%S",os.time()),".")
  
  sleep(1)
end

--Close the GPIO Pins
print("Closing the pins")
for i=1,#pins do
  pins[i]:write(false)
  pins[i]:close()
end
