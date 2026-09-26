-- Laser Scatter Sweep MC
-- One composite output: ch1 = X tilt (-1..1), ch2 = Y tilt (-1..1). No inputs.
-- Every tick the beam jumps to the diagonally-opposite quadrant, while a
-- golden-ratio sequence varies radius/angle inside the quadrant so repeated
-- cycles fill the whole square instead of re-hitting the same four points.
local t=0
local PHI=0.6180339887  -- golden ratio conjugate: low-discrepancy step
local R2=0.7548776662   -- second irrational step (plastic number conjugate), decorrelates axes
local QX={1,-1,1,-1}    -- quadrant order ++, --, +-, -+ : each tick flips at least one axis,
local QY={1,-1,-1,1}    -- and every other tick flips both (maximum jump)
local a,b=0,0

function onTick()
 t=t+1
 local q=(t-1)%4+1
 local x,y
 if t%8<4 then
  -- hard corners: absolute max deflection on both axes
  x,y=QX[q],QY[q]
 else
  -- in-quadrant fill: sqrt gives uniform area coverage, never collapses to centre
  a=(a+PHI)%1 b=(b+R2)%1
  x=QX[q]*(0.25+0.75*math.sqrt(a))
  y=QY[q]*(0.25+0.75*math.sqrt(b))
 end
 output.setNumber(1,x)
 output.setNumber(2,y)
end
