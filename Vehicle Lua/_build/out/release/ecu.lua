-- Author: Toastery
-- GitHub: https://github.com/Toast732
-- Workshop: 
--
-- Developed & Minimized using LifeBoatAPI - Stormworks Lua plugin for VSCode
-- https://code.visualstudio.com/download (search "Stormworks Lua with LifeboatAPI" extension)
--      By Nameous Changey
-- Minimized Size: 1041 (1355 with comment) chars

z=true
i=false
m=math
x=output
v=input
f=v.getNumber
h=x.setBool
b=x.setNumber
c=property.getNumber
local g=m
E=c("Throttle Type")I=c("Starter RPS")w=c("Min RPS")u=c("Max RPS")K=c("AFR")H=c("Enabling Cooling System Temp")L=c("Half Throttle Temp")F=c("Automatic Shutdown Temp")function M(t,o,q)return{t=t,o=o,q=q,a=0,e=0,j=0,B=function(_,N,G)local a,e,n
a=N-G
e=a-_.a
n=m.abs(e-_.e)_.a=a
_.e=e
_.j=n<a and _.j+a*_.o or _.j*.5
return a*_.t+(n<a and _.j or 0)+e*_.q
end}end
function y()b(1,0)b(2,0)s=i
b(4,0)h(1,i)end
function onTick()local C=M(-.037+f(7),.00025+f(8),.125052+f(9))s=v.getBool(1)if not s then
y()end
local p=f(3)if p>=F then
y()end
local k=f(5)if p>H then
h(2,z)else
h(2,i)end
if not s then
return
end
if p>L then
k=k/2
end
local r=f(4)local l=k+.8
if E==0 then
l=g.max(g.abs(u*k),w)+.8
end
local A=g.J(C:B(l,r),0,1)b(5,l)b(1,A/K)b(2,A)b(3,O(g.sqrt(g.max(r-w)/u,0)))if r<I then
b(4,1)h(1,z)else
b(4,0)h(1,i)end
end
function m.J(d,min,max)return D(max<d and max or min>d and min or d)end
function D(d)return d~=d and 0 or d
end
