-- Author: Toastery
-- GitHub: https://github.com/Toast732
-- Workshop: 
--
-- Developed & Minimized using LifeBoatAPI - Stormworks Lua plugin for VSCode
-- https://code.visualstudio.com/download (search "Stormworks Lua with LifeboatAPI" extension)
--      By Nameous Changey
-- Minimized Size: 1042 (1356 with comment) chars

v=true
e=false
z=property
c=math
x=input
w=output.setBool
b=x.getNumber
C=c.atan
a=z.getNumber
B=z.getBool
n=0
u=0
D=0
G=0
r=B("Requires Is Occupied?")E=B("Radar Rotation")N=a("Time Between Missiles (s)")d=a("Min Mass")f=a("Max Mass")W=a("Min Y")X=a("Max Y")Q=a("Min Distance")I=a("Max Distance")i=a("Radar FOV X")*.75
l=a("Radar FOV Y")*.75
if E then
local O=l
l=i
i=O
end
s=c.pi*2
function K(j,k,h,g)return C(j-h,k-g)/s
end
function L(h,g,j,k)return c.sqrt((j-h)^2+(k-g)^2)end
function onTick()local q=e
n=n+1
D=0
G=0
S=e
U=e
M=x.getBool(1)if not r or r and M then
m=b(8)if f==0 and d==0 or f==0 and d>=0 and m>=d or m>=d and m<=f then
A=b(5)y=b(7)p=b(1)t=b(3)o=L(A,y,p,t)if o>=Q and o<=I then
H=-b(4)P=K(p,t,A,y)if c.abs(P-H)<=i then
F=b(6)J=b(2)if C((J-F)/o)/s-b(9)<=l then
if u==0 or n-u>=N*60 then
w(1,v)q=v
end
end
end
end
end
end
if not q then
w(1,e)end
end
function c.V(_,min,max)return max<_ and max or min>_ and min or _
end
function T(_)return _~=_ and 0 or _
end
function R(_,min,max)return(_-min)/(max-min)%1*(max-min)+min
end
