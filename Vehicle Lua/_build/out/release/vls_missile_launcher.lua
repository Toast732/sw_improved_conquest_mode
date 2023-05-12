-- Author: Toastery
-- GitHub: https://github.com/Toast732
-- Workshop: 
--
-- Developed & Minimized using LifeBoatAPI - Stormworks Lua plugin for VSCode
-- https://code.visualstudio.com/download (search "Stormworks Lua with LifeboatAPI" extension)
--      By Nameous Changey
-- Minimized Size: 511 (823 with comment) chars

j=math
i=input
_=i.getNumber
g=output.setBool
a=property.getNumber
local q=a("Min Y")local c=a("Min Distance")local d=a("Max Distance")local m=a("Fire Rate (s)")local p=m*60
local b=0
function onTick()g(1,false)if b>0 then
b=j.max(0,b-1)return
end
if not i.getBool(1)then
return
end
if _(2)<q then
return
end
if c~=0 or d~=0 then
local n=_(1)local l=_(3)local o=_(4)local k=_(5)local f=n-o
local e=l-k
local h=j.sqrt(f*f+e*e)if d~=0 and h>d then
return
end
if c~=0 and h<c then
return
end
end
g(1,true)b=p
end
