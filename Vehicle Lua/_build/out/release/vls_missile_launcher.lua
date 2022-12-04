-- Author: Toastery
-- GitHub: https://github.com/Toast732
-- Workshop: 
--
-- Developed & Minimized using LifeBoatAPI - Stormworks Lua plugin for VSCode
-- https://code.visualstudio.com/download (search "Stormworks Lua with LifeboatAPI" extension)
--      By Nameous Changey
-- Minimized Size: 511 (823 with comment) chars

h=math
j=input
_=j.getNumber
g=output.setBool
b=property.getNumber
local k=b("Min Y")local c=b("Min Distance")local d=b("Max Distance")local l=b("Fire Rate (s)")local o=l*60
local a=0
function onTick()g(1,false)if a>0 then
a=h.max(0,a-1)return
end
if not j.getBool(1)then
return
end
if _(2)<k then
return
end
if c~=0 or d~=0 then
local q=_(1)local n=_(3)local p=_(4)local m=_(5)local i=q-p
local e=n-m
local f=h.sqrt(i*i+e*e)if d~=0 and f>d then
return
end
if c~=0 and f<c then
return
end
end
g(1,true)a=o
end
