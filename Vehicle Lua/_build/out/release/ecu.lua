-- Author: Toastery
-- GitHub: https://github.com/Toast732
-- Workshop: 
--
-- Developed & Minimized using LifeBoatAPI - Stormworks Lua plugin for VSCode
-- https://code.visualstudio.com/download (search "Stormworks Lua with LifeboatAPI" extension)
--      By Nameous Changey
-- Minimized Size: 1041 (1355 with comment) chars

A=true
j=false
t=math
y=output
z=input
f=z.getNumber
g=y.setBool
b=y.setNumber
c=property.getNumber
local h=t
D=c("Throttle Type")H=c("Starter RPS")w=c("Min RPS")v=c("Max RPS")B=c("AFR")L=c("Enabling Cooling System Temp")I=c("Half Throttle Temp")F=c("Automatic Shutdown Temp")function E(o,m,s)return{o=o,m=m,s=s,a=0,e=0,i=0,G=function(_,J,C)local a,e,r
a=J-C
e=a-_.a
r=t.abs(e-_.e)_.a=a
_.e=e
_.i=r<a and _.i+a*_.m or _.i*.5
return a*_.o+(r<a and _.i or 0)+e*_.s
end}end
function u()b(1,0)b(2,0)q=j
b(4,0)g(1,j)end
function onTick()local M=E(-.037+f(7),.00025+f(8),.125052+f(9))q=z.getBool(1)if not q then
u()end
local p=f(3)if p>=F then
u()end
local k=f(5)if p>L then
g(2,A)else
g(2,j)end
if not q then
return
end
if p>I then
k=k/2
end
local l=f(4)local n=k+.8
if D==0 then
n=h.max(h.abs(v*k),w)+.8
end
local x=h.K(M:G(n,l),0,1)b(5,n)b(1,x/B)b(2,x)b(3,O(h.sqrt(h.max(l-w)/v,0)))if l<H then
b(4,1)g(1,A)else
b(4,0)g(1,j)end
end
function t.K(d,min,max)return N(max<d and max or min>d and min or d)end
function N(d)return d~=d and 0 or d
end
