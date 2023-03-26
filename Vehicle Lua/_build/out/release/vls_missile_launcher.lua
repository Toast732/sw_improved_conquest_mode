-- Author: Toastery
-- GitHub: https://github.com/Toast732
-- Workshop: 
--
-- Developed & Minimized using LifeBoatAPI - Stormworks Lua plugin for VSCode
-- https://code.visualstudio.com/download (search "Stormworks Lua with LifeboatAPI" extension)
--      By Nameous Changey
-- Minimized Size: 511 (823 with comment) chars

f=math
i=input
_=i.getNumber
h=output.setBool
b=property.getNumber
local p=b("Min Y")local d=b("Min Distance")local c=b("Max Distance")local o=b("Fire Rate (s)")local k=o*60
local a=0
function onTick()h(1,false)if a>0 then
a=f.max(0,a-1)return
end
if not i.getBool(1)then
return
end
if _(2)<p then
return
end
if d~=0 or c~=0 then
local n=_(1)local q=_(3)local m=_(4)local l=_(5)local j=n-m
local g=q-l
local e=f.sqrt(j*j+g*g)if c~=0 and e>c then
return
end
if d~=0 and e<d then
return
end
end
h(1,true)a=k
end
