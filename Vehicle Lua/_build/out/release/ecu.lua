-- Author: Toastery
-- GitHub: https://github.com/Toast732
-- Workshop: 
--
-- Developed & Minimized using LifeBoatAPI - Stormworks Lua plugin for VSCode
-- https://code.visualstudio.com/download (search "Stormworks Lua with LifeboatAPI" extension)
--      By Nameous Changey
-- Minimized Size: 1041 (1355 with comment) chars

z=true
k=false
s=math
y=output
x=input
f=x.getNumber
g=y.setBool
b=y.setNumber
c=property.getNumber
local h=s
J=c("Throttle Type")F=c("Starter RPS")A=c("Min RPS")w=c("Max RPS")N=c("AFR")H=c("Enabling Cooling System Temp")D=c("Half Throttle Temp")I=c("Automatic Shutdown Temp")function E(m,q,r)return{m=m,q=q,r=r,a=0,d=0,j=0,C=function(_,M,L)local a,d,o
a=M-L
d=a-_.a
o=s.abs(d-_.d)_.a=a
_.d=d
_.j=o<a and _.j+a*_.q or _.j*.5
return a*_.m+(o<a and _.j or 0)+d*_.r
end}end
function u()b(1,0)b(2,0)p=k
b(4,0)g(1,k)end
function onTick()local B=E(-.037+f(7),.00025+f(8),.125052+f(9))p=x.getBool(1)if not p then
u()end
local l=f(3)if l>=I then
u()end
local i=f(5)if l>H then
g(2,z)else
g(2,k)end
if not p then
return
end
if l>D then
i=i/2
end
local n=f(4)local t=i+.8
if J==0 then
t=h.max(h.abs(w*i),A)+.8
end
local v=h.K(B:C(t,n),0,1)b(5,t)b(1,v/N)b(2,v)b(3,O(h.sqrt(h.max(n-A)/w,0)))if n<F then
b(4,1)g(1,z)else
b(4,0)g(1,k)end
end
function s.K(e,min,max)return G(max<e and max or min>e and min or e)end
function G(e)return e~=e and 0 or e
end
