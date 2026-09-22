-- Tracking Probe Guidance MC
-- State 1: Radio-telemetry pursuit+PN | State 2: hand-off on link/track loss | State 3: onboard sensor terminal homing (locked)
local locked=false
local pB,pE,haveP=0,0,false  -- previous LOS bearing/elevation, for PN rate term
local N=4        -- PN gain (3-5 typical)
local G=1.5      -- fin sensitivity gain
local function clamp(v,a,b) if v<a then return a elseif v>b then return b end return v end
local function wrap(a) return a-math.floor(a+0.5) end -- wrap to -0.5..0.5 turns

function onTick()
 local launched=input.getBool(3)
 if not launched then
  output.setBool(1,false) output.setBool(2,false)
  output.setNumber(1,0) output.setNumber(2,0)
  locked=false haveP=false
  return
 end

 -- Radio telemetry (Composite In 1)
 local tx,ty,tz=input.getNumber(1),input.getNumber(2),input.getNumber(3)
 local dataValid=input.getBool(1)
 -- Onboard directional sensor (Composite In 2)
 local sFound=input.getBool(2)
 local sAz,sEl=input.getNumber(5),input.getNumber(6)
 -- Physics sensor (Composite In 3)
 local mx,my,mz=input.getNumber(7),input.getNumber(8),input.getNumber(9)
 local pitch,yaw=input.getNumber(10),input.getNumber(12)

 -- State hand-off: sticky lock into autonomous mode, never re-arms telemetry
 if not dataValid then locked=true end
 local auto=locked
 output.setBool(1,auto) -- onboard sensor power

 local yErr,pErr=0,0
 if not auto then
  -- State 1: telemetry pursuit + PN lead term
  local dx,dz,dy=tx-mx,tz-mz,ty-my
  local hDist=math.sqrt(dx*dx+dz*dz)
  local brg=math.atan(dx,dz)/(2*math.pi)
  local elv=math.atan(dy,hDist)/(2*math.pi)
  local rY,rP=0,0
  if haveP then rY,rP=wrap(brg-pB),wrap(elv-pE) end
  pB,pE,haveP=brg,elv,true
  yErr=wrap(brg-yaw)*G+rY*N
  pErr=wrap(elv-pitch)*G+rP*N
 else
  -- State 3: onboard sensor terminal homing
  haveP=false
  if sFound then yErr,pErr=sAz*G,sEl*G end
 end

 output.setNumber(2,clamp(yErr,-1,1)) -- yaw fins
 output.setNumber(1,clamp(pErr,-1,1)) -- pitch fins
 output.setBool(2,true) -- thruster ignition
end
