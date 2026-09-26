-- Laser Wavelength Sweeper MC
-- Runs continuously; laser on/off is handled by a separate key.
-- Out: comp num ch1-10 = Wavelength for emitters 1-10
-- Properties (optional, add as Number properties on the MC):
--   "Min WL"  lowest wavelength to sweep   (default 0)
--   "Max WL"  highest wavelength to sweep  (default 99)
--   "Dwell"   ticks each value is held      (default 1)

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

-- Lanes: emitter i starts at offset (i-1)*stride so the 10 lasers
-- partition the band instead of overlapping. Each lane then steps +1.
local stride=math.max(1,math.ceil(span/N))

local step=0  -- sweep position within one lane (0..stride-1)
local t=0     -- dwell counter

function onTick()
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
