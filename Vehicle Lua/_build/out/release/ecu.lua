-- Author: Toastery
-- GitHub: https://github.com/Toast732
-- Workshop: 
--
-- Developed & Minimized using LifeBoatAPI - Stormworks Lua plugin for VSCode
-- https://code.visualstudio.com/download (search "Stormworks Lua with LifeboatAPI" extension)
--      By Nameous Changey
-- Minimized Size: 1041 (1355 with comment) chars

y=true
j=false
l=math
u=output
v=input
f=v.getNumber
g=u.setBool
b=u.setNumber
c=property.getNumber
local h=l
N=c("Throttle Type")E=c("Starter RPS")x=c("Min RPS")A=c("Max RPS")J=c("AFR")M=c("Enabling Cooling System Temp")F=c("Half Throttle Temp")D=c("Automatic Shutdown Temp")function L(p,q,t)return{p=p,q=q,t=t,a=0,e=0,k=0,K=function(_,I,G)local a,e,o
a=I-G
e=a-_.a
o=l.abs(e-_.e)_.a=a
_.e=e
_.k=o<a and _.k+a*_.q or _.k*.5
return a*_.p+(o<a and _.k or 0)+e*_.t
end}end
function z()b(1,0)b(2,0)s=j
b(4,0)g(1,j)end
function onTick()local C=L(-.037+f(7),.00025+f(8),.125052+f(9))s=v.getBool(1)if not s then
z()end
local n=f(3)if n>=D then
z()end
local i=f(5)if n>M then
g(2,y)else
g(2,j)end
if not s then
return
end
if n>F then
i=i/2
end
local m=f(4)local r=i+.8
if N==0 then
r=h.max(h.abs(A*i),x)+.8
end
local w=h.B(C:K(r,m),0,1)b(5,r)b(1,w/J)b(2,w)b(3,O(h.sqrt(h.max(m-x)/A,0)))if m<E then
b(4,1)g(1,y)else
b(4,0)g(1,j)end
end
function l.B(d,min,max)return H(max<d and max or min>d and min or d)end
function H(d)return d~=d and 0 or d
end
