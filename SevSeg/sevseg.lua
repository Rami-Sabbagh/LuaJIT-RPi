--SEV SEG RAMI

local socket = require("socket")
local periphery = require('periphery')

local GPIO = periphery.GPIO

print("Using GPIO:",GPIO.version)

local function sleep(seconds)
  os.execute("sleep "..tostring(seconds).."s")
end

--A B C D E F G DT 1 2 3 4
local pins = {2,3,4, 17,27,22, 10,9,11, 5,6,13}

--[[
{A,B,C,D,E,F,G}

 A
F B
 G
E C
 D
]]

local sv_font = {
  {true,true,true,true,true,true,false}, --0
  {false,true,true,false,false,false,false}, --1
  {true,true,false,true,true,false,true}, --2
  {true,true,true,true,false,false,true}, --3
  {false,true,true,false,false,true,true}, --4
  {true,false,true,true,false,true,true}, --5
  {true,false,true,true,true,true,true}, --6
  {true,true,true,false,false,false,false}, --7
  {true,true,true,true,true,true,true}, --8
  {true,true,true,true,false,true,true}, --9
  {true,true,true,false,true,true,true}, --A (10)
  {false,false,true,true,true,true,true}, --b (11)
  {false,false,false,true,true,false,true}, --C (12)
  {false,true,true,true,true,false,true}, --d (13)
  {true,false,false,true,true,true,true}, --E (14)
  {true,false,false,false,true,true,true}, --F (15)
}

local function display(num,digitID,dot)
  local num = num or 0
  local digitID = digitID or 1
  
  for i=1,7 do
    pins[i]:write(not sv_font[num+1][i])
  end
  
  pins[8]:write(not dot)
  
  for i=9,12 do
	pins[i]:write((i-8) == digitID)
  end
end

local MDTime = 1/120

local function display2Digits(num1,num2,timer)
	local num1, num2 = num1 or 0, num2 or 0
	local timer = timer or 1
	
	while timer > 0 do
		display(num1,1,false)
		socket.sleep(MDTime)
		display(num2,2,false)
		socket.sleep(MDTime)
		timer = timer - MDTime*2
	end
end

--Initalize the pins
print("Initializing the pins...")
for i=1,#pins do
  pins[i] = GPIO(pins[i],"out")
end

--Disable all the digits & segments
print("Disabling all the digits & segments")
for i=1,12 do
  pins[i]:write(i < 9)
end

--[[
for d=1,4 do
  for n=0,15 do
    print("DISPLAY","Number",n,"Digit",d)
    display(n,d,true)
    sleep(0.1)
  end
end]]

for n1=0,9 do
  for n2=0,9 do
	print("DISPLAY", n1..n2)
	display2Digits(n1,n2,0.05)
  end
end

--Close the GPIO Pins
print("Closing the pins")
for i=1,#pins do
  pins[i]:write(i < 9)
  pins[i]:close()
end
