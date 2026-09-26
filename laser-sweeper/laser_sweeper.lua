-- Laser Wavelength Sweeper MC
-- In : comp bool ch1 = Missile Alert
-- Out: comp num ch1-10 = Wavelength for emitters 1-10
--      comp bool ch1   = Emitter Enable (drive every laser's on/off)
-- Properties (optional, add as Number properties on the MC):
--   "Min WL"  lowest wavelength to sweep   (default 0)
--   "Max WL"  highest wavelength to sweep  (default 99)
--   "Dwell"   ticks each value is held      (default 1)
--   "Hold"    ticks to keep sweeping after alert drops (default 120 = 2s)

local N=10 -- emitter count = output channels used

local function prop(name,def)
 local v=property.getNumber(name)
 if v==nil or v~=v then return def end -- nil/NaN guard
 return v
end

-- Read once at load; properties can't change while the vehicle is spawned
local lo=math.floor(prop("Min WL",0))
local hi=math.floor(prop("Max WL",99))
if hi<lo then lo,hi=hi,lo end
local span=hi-lo+1
local dwell=math.max(1,math.floor(prop("Dwell",1)))
local holdT=math.max(0,math.floor(prop("Hold",120)))

-- Lanes: emitter i starts at offset (i-1)*stride so the 10 lasers
-- partition the band instead of overlapping. Each lane then steps +1.
local stride=math.max(1,math.ceil(span/N))

local step=0  -- sweep position within one lane (0..stride-1)
local t=0     -- dwell counter
local hold=0  -- ticks of post-alert hold remaining

function onTick()
 if input.getBool(1) then hold=holdT+1 end
 local active=hold>0
 output.setBool(1,active)

 if not active then
  step,t=0,0
  for i=1,N do output.setNumber(i,0) end
  return
 end
 hold=hold-1

 for i=1,N do
  -- (i-1)*stride+step walks lane i; % span wraps the last lane back
  -- into range when span isn't a multiple of N
  output.setNumber(i,lo+((i-1)*stride+step)%span)
 end

 t=t+1
 if t>=dwell then
  t=0
  step=(step+1)%stride
 end
end
