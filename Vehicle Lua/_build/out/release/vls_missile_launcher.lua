-- Author: Toastery
-- GitHub: https://github.com/Toast732
-- Workshop: 
--
-- Developed & Minimized using LifeBoatAPI - Stormworks Lua plugin for VSCode
-- https://code.visualstudio.com/download (search "Stormworks Lua with LifeboatAPI" extension)
--      By Nameous Changey
-- Minimized Size: 511 (823 with comment) chars

g=math
i=input
_=i.getNumber
j=output.setBool
a=property.getNumber
local q=a("Min Y")local c=a("Min Distance")local d=a("Max Distance")local n=a("Fire Rate (s)")local l=n*60
local b=0
function onTick()j(1,false)if b>0 then
b=g.max(0,b-1)return
end
if not i.getBool(1)then
return
end
if _(2)<q then
return
end
if c~=0 or d~=0 then
local k=_(1)local o=_(3)local p=_(4)local m=_(5)local e=k-p
local f=o-m
local h=g.sqrt(e*e+f*f)if d~=0 and h>d then
return
end
if c~=0 and h<c then
return
end
end
j(1,true)b=l
end