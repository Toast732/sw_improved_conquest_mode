-- Author: Toastery
-- GitHub: https://github.com/Toast732
-- Workshop: 
--
-- Developed & Minimized using LifeBoatAPI - Stormworks Lua plugin for VSCode
-- https://code.visualstudio.com/download (search "Stormworks Lua with LifeboatAPI" extension)
--      By Nameous Changey
-- Minimized Size: 2548 (2862 with comment) chars
ax="%.3f"
aw="\nyaw from tar: "
av="\npitch from tar: "

B=true
t=false
ad=property
Q=input
k=math
Z=output
o=screen.drawText
W=Z.setNumber
U=Z.setBool
b=k.abs
e=Q.getNumber
T=k.atan
_=ad.getNumber
q=ad.getBool
P=t
M=0
ac=0
a=0
c=0
an=q("Enable Debug")ai=q("Invert Horizontal Rotation")ae=q("Invert Vertical Rotation")au=q("Aim Mode")ab=q("Requires Is Occupied?")f=_("Horizontal Pivot Type")j=_("Vertical Pivot Type")C=_("Angle Units")L=_("Horizontal Max Angle")z=_("Horizontal Min Angle")G=_("Vertical Max Angle")I=_("Vertical Min Angle")aj=_("Time Between Shots (s)")u=_("Min Mass")A=_("Max Mass")aq=_("Min Y")ap=_("Max Y")n=_("Yaw Threshold")p=_("Pitch Threshold")ao=_("Min Distance")aa=_("Max Distance")D=k.pi*2
h=4
m=4
E=1
l=1
function ar(N,F,x,w)return T(N-x,F-w)/D
end
function ah(x,w,N,F)return k.sqrt((N-x)^2+(F-w)^2)end
function am()i=1
if C==1 then
i=D
elseif C==2 then
i=400
elseif C==3 then
i=360
end
if f>=2 then
h=1
end
if j>=2 then
m=1
end
E=h
if ai then
E=-h
end
l=m
if ae then
l=-m
end
L=d(L/i/h)z=d(z/i/h)G=d(G/i/m)I=d(I/i/m)n=d(n/i)p=d(p/i)end
function onTick()local V=t
if not P then
am()P=B
end
M=M+1
a=0
c=0
y=t
K=t
ag=Q.getBool(1)if not ab or ab and ag then
H=e(10)if A==0 and u==0 or A==0 and u>=0 and H>=u or H>=u and H<=A then
J=e(2)if J>=aq and J<=ap then
S=e(7)Y=e(9)R=e(1)O=e(3)v=ah(S,Y,R,O)if v>=ao and v<=aa+300 then
af=e(8)al=-e(4)s=e(5)r=e(6)as=e(11)*4
ak=al-ar(R,O,S,Y)a=d(k.X(ak,z,L)*E)if f<=1 then
a=d(at(a,-1,1))end
if f>=2 then
a=d(((a-s*h)%1+1.5)%1-.5)end
c=d(k.X(T((J-af)/v)/D,I,G)*l)+as
if j>=2 then
c=d(((c-r*m)%1+1.5)%1-.5)end
y=(f<=1 and b(s*h-a)<=n or f>=2 and b(a)<=n)K=(j<=1 and b(r*l-c)<=p or j>=2 and b(c)<=p)if y then
if K then
if ac==0 or M-ac>=aj*60 then
if v<aa then
U(1,B)V=B
end
end
end
end
end
end
end
end
if not V then
U(1,t)end
W(1,a)W(2,c)end
function onDraw()if an then
if s then
if y then
o(0,0,"VALID yaw thrsh: "..(ax):format(n)..aw..(ax):format(f<=1 and b(s*h-a)or f>=2 and b(a)))else
o(0,0,"INVALID yaw thrsh: "..(ax):format(n)..aw..(ax):format(f<=1 and b(s*h-a)or f>=2 and b(a)))end
else
o(0,0,"horizontal_rot doesnt exist")end
if r then
if K then
o(0,20,"VALID pitch thrsh: "..(ax):format(p)..av..(ax):format(j<=1 and b(r*l-c)or j>=2 and b(c)))else
o(0,20,"INVALID pitch thrsh: "..(ax):format(p)..av..(ax):format(j<=1 and b(r*l-c)or j>=2 and b(c)))end
else
o(0,20,"vertical_rot doesnt exist")end
end
end
function k.X(g,min,max)return max<g and max or min>g and min or g
end
function d(g)return g~=g and 0 or g
end
function at(g,min,max)return(g-min)/(max-min)%1*(max-min)+min
end
