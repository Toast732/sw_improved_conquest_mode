-- Author: Toastery
-- GitHub: https://github.com/Toast732
-- Workshop: 
--
-- Developed & Minimized using LifeBoatAPI - Stormworks Lua plugin for VSCode
-- https://code.visualstudio.com/download (search "Stormworks Lua with LifeboatAPI" extension)
--      By Nameous Changey
-- Minimized Size: 1042 (1356 with comment) chars

x=true
d=false
p=property
c=math
q=input
u=output.setBool
a=q.getNumber
z=c.atan
_=p.getNumber
v=p.getBool
j=0
w=0
E=0
J=0
A=v("Requires Is Occupied?")P=v("Radar Rotation")Q=_("Time Between Missiles (s)")e=_("Min Mass")g=_("Max Mass")W=_("Min Y")S=_("Max Y")K=_("Min Distance")M=_("Max Distance")h=_("Radar FOV X")*.75
m=_("Radar FOV Y")*.75
if P then
local I=m
m=h
h=I
end
y=c.pi*2
function N(l,i,k,o)return z(l-k,i-o)/y
end
function O(k,o,l,i)return c.sqrt((l-k)^2+(i-o)^2)end
function onTick()local r=d
j=j+1
E=0
J=0
U=d
X=d
H=q.getBool(1)if not A or A and H then
n=a(8)if g==0 and e==0 or g==0 and e>=0 and n>=e or n>=e and n<=g then
B=a(5)C=a(7)t=a(1)s=a(3)f=O(B,C,t,s)if f>=K and f<=M then
L=-a(4)D=N(t,s,B,C)if c.abs(D-L)<=h then
F=a(6)G=a(2)if z((G-F)/f)/y-a(9)<=m then
if w==0 or j-w>=Q*60 then
u(1,x)r=x
end
end
end
end
end
end
if not r then
u(1,d)end
end
function c.T(b,min,max)return max<b and max or min>b and min or b
end
function R(b)return b~=b and 0 or b
end
function V(b,min,max)return(b-min)/(max-min)%1*(max-min)+min
end
