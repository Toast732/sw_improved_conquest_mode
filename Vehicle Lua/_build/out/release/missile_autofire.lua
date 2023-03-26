-- Author: Toastery
-- GitHub: https://github.com/Toast732
-- Workshop: 
--
-- Developed & Minimized using LifeBoatAPI - Stormworks Lua plugin for VSCode
-- https://code.visualstudio.com/download (search "Stormworks Lua with LifeboatAPI" extension)
--      By Nameous Changey
-- Minimized Size: 1042 (1356 with comment) chars

q=true
d=false
x=property
c=math
A=input
y=output.setBool
b=A.getNumber
z=c.atan
a=x.getNumber
C=x.getBool
k=0
u=0
Q=0
J=0
s=C("Requires Is Occupied?")D=C("Radar Rotation")G=a("Time Between Missiles (s)")e=a("Min Mass")i=a("Max Mass")U=a("Min Y")V=a("Max Y")F=a("Min Distance")L=a("Max Distance")m=a("Radar FOV X")*.75
g=a("Radar FOV Y")*.75
if D then
local H=g
g=m
m=H
end
w=c.pi*2
function O(j,f,o,l)return z(j-o,f-l)/w
end
function M(o,l,j,f)return c.sqrt((j-o)^2+(f-l)^2)end
function onTick()local v=d
k=k+1
Q=0
J=0
T=d
X=d
E=A.getBool(1)if not s or s and E then
h=b(8)if i==0 and e==0 or i==0 and e>=0 and h>=e or h>=e and h<=i then
r=b(5)p=b(7)B=b(1)t=b(3)n=M(r,p,B,t)if n>=F and n<=L then
N=-b(4)K=O(B,t,r,p)if c.abs(K-N)<=m then
I=b(6)P=b(2)if z((P-I)/n)/w-b(9)<=g then
if u==0 or k-u>=G*60 then
y(1,q)v=q
end
end
end
end
end
end
if not v then
y(1,d)end
end
function c.S(_,min,max)return max<_ and max or min>_ and min or _
end
function R(_)return _~=_ and 0 or _
end
function W(_,min,max)return(_-min)/(max-min)%1*(max-min)+min
end
