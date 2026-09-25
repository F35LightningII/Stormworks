-- Radar Emission Tracker MC
-- In  (composite bools 1-6): Front, Back, Left, Right, Top, Bottom radar detectors
-- Out (composite numbers):   1 = azimuth, 2 = elevation
-- Out (composite bool 1):     countermeasure trigger (any detector on, held HOLD ticks)
-- Units: normalized. Azimuth -1..1 = -180..+180 deg (0 = front, +right).
--        Elevation -1..1 = -90..+90 deg (0 = level, +up).
local SMOOTH=0.15  -- fraction of remaining error closed per tick
local AZ_RATE=0.02 -- max azimuth slew per tick (0.02 = 3.6 deg/tick)
local EL_RATE=0.02 -- max elevation slew per tick (0.02 = 1.8 deg/tick)
local HOLD=30      -- ticks to keep the countermeasure output on after the last hit (30 = 0.5 s)
local az,el=0,0
local holdT=0

local function clamp(v,a,b) if v<a then return a elseif v>b then return b end return v end
local function wrap(a) return (a+1)%2-1 end -- wrap to -1..1
local function n(b) return b and 1 or 0 end

function onTick()
 local f,b=input.getBool(1),input.getBool(2)
 local l,r=input.getBool(3),input.getBool(4)
 local t,d=input.getBool(5),input.getBool(6)

 -- Countermeasure: on while any detector is lit, then held so a sweeping beam doesn't flicker it
 if f or b or l or r or t or d then holdT=HOLD elseif holdT>0 then holdT=holdT-1 end
 output.setBool(1,holdT>0)

 -- Sum active detector faces into a direction vector; opposing faces cancel
 local x=n(f)-n(b) -- forward
 local y=n(r)-n(l) -- right
 local z=n(t)-n(d) -- up
 local h=math.sqrt(x*x+y*y)

 -- Azimuth: only steer when there is a horizontal cue, otherwise hold
 if h>0 then
  local tAz=math.atan(y,x)/math.pi -- front=0, right=+0.5, left=-0.5, back=+-1
  local e=wrap(tAz-az)             -- shortest way round
  az=wrap(az+clamp(e*SMOOTH,-AZ_RATE,AZ_RATE))
 end

 -- Elevation: steer toward the combined up/down vs horizontal cue, otherwise hold
 if h>0 or z~=0 then
  local tEl=math.atan(z,h)/(math.pi/2) -- level=0, top only=+1, bottom only=-1
  el=clamp(el+clamp((tEl-el)*SMOOTH,-EL_RATE,EL_RATE),-1,1)
 end

 output.setNumber(1,az)
 output.setNumber(2,el)
end
