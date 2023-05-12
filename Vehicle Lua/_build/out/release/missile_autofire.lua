-- Author: Toastery
-- GitHub: https://github.com/Toast732
-- Workshop: 
--
-- Developed & Minimized using LifeBoatAPI - Stormworks Lua plugin for VSCode
-- https://code.visualstudio.com/download (search "Stormworks Lua with LifeboatAPI" extension)
--      By Nameous Changey
-- Minimized Size: 1042 (1356 with comment) chars

t=true
e=false
u=property
c=math
r=input
q=output.setBool
a=r.getNumber
y=c.atan
b=u.getNumber
w=u.getBool
n=0
A=0
D=0
L=0
v=w("Requires Is Occupied?")N=w("Radar Rotation")G=b("Time Between Missiles (s)")d=b("Min Mass")i=b("Max Mass")S=b("Min Y")U=b("Max Y")E=b("Min Distance")Q=b("Max Distance")m=b("Radar FOV X")*.75
f=b("Radar FOV Y")*.75
if N then
local P=f
f=m
m=P
end
s=c.pi*2
function K(h,g,l,o)return y(h-l,g-o)/s
end
function H(l,o,h,g)return c.sqrt((h-l)^2+(g-o)^2)end
function onTick()local B=e
n=n+1
D=0
L=0
V=e
X=e
J=r.getBool(1)if not v or v and J then
k=a(8)if i==0 and d==0 or i==0 and d>=0 and k>=d or k>=d and k<=i then
z=a(5)x=a(7)p=a(1)C=a(3)j=H(z,x,p,C)if j>=E and j<=Q then
O=-a(4)M=K(p,C,z,x)if c.abs(M-O)<=m then
F=a(6)I=a(2)if y((I-F)/j)/s-a(9)<=f then
if A==0 or n-A>=G*60 then
q(1,t)B=t
end
end
end
end
end
end
if not B then
q(1,e)end
end
function c.T(_,min,max)return max<_ and max or min>_ and min or _
end
function R(_)return _~=_ and 0 or _
end
function W(_,min,max)return(_-min)/(max-min)%1*(max-min)+min
end
