-- Author: Toastery
-- GitHub: https://github.com/Toast732
-- Workshop: 
--
-- Developed & Minimized using LifeBoatAPI - Stormworks Lua plugin for VSCode
-- https://code.visualstudio.com/download (search "Stormworks Lua with LifeboatAPI" extension)
--      By Nameous Changey
-- Minimized Size: 2548 (2862 with comment) chars
ax="\nyaw from tar: "
aw="%.3f"
av="\npitch from tar: "

y=true
t=false
T=property
S=input
k=math
U=output
m=screen.drawText
W=U.setNumber
Q=U.setBool
b=k.abs
e=S.getNumber
P=k.atan
_=T.getNumber
s=T.getBool
ab=t
z=0
V=0
a=0
d=0
ao=s("Enable Debug")af=s("Invert Horizontal Rotation")ar=s("Invert Vertical Rotation")au=s("Aim Mode")Z=s("Requires Is Occupied?")f=_("Horizontal Pivot Type")j=_("Vertical Pivot Type")F=_("Angle Units")C=_("Horizontal Max Angle")D=_("Horizontal Min Angle")G=_("Vertical Max Angle")B=_("Vertical Min Angle")ak=_("Time Between Shots (s)")u=_("Min Mass")x=_("Max Mass")ap=_("Min Y")am=_("Max Y")n=_("Yaw Threshold")p=_("Pitch Threshold")ae=_("Min Distance")Y=_("Max Distance")M=k.pi*2
h=4
o=4
L=1
l=1
function as(w,H,N,J)return P(w-N,H-J)/M
end
function ai(N,J,w,H)return k.sqrt((w-N)^2+(H-J)^2)end
function an()i=1
if F==1 then
i=M
elseif F==2 then
i=400
elseif F==3 then
i=360
end
if f>=2 then
h=1
end
if j>=2 then
o=1
end
L=h
if af then
L=-h
end
l=o
if ar then
l=-o
end
C=c(C/i/h)D=c(D/i/h)G=c(G/i/o)B=c(B/i/o)n=c(n/i)p=c(p/i)end
function onTick()local aa=t
if not ab then
an()ab=y
end
z=z+1
a=0
d=0
E=t
A=t
ag=S.getBool(1)if not Z or Z and ag then
K=e(10)if x==0 and u==0 or x==0 and u>=0 and K>=u or K>=u and K<=x then
I=e(2)if I>=ap and I<=am then
ad=e(7)X=e(9)ac=e(1)R=e(3)v=ai(ad,X,ac,R)if v>=ae and v<=Y+300 then
aj=e(8)at=-e(4)r=e(5)q=e(6)aq=e(11)*4
al=at-as(ac,R,ad,X)a=c(k.O(al,D,C)*L)if f<=1 then
a=c(ah(a,-1,1))end
if f>=2 then
a=c(((a-r*h)%1+1.5)%1-.5)end
d=c(k.O(P((I-aj)/v)/M,B,G)*l)+aq
if j>=2 then
d=c(((d-q*o)%1+1.5)%1-.5)end
E=(f<=1 and b(r*h-a)<=n or f>=2 and b(a)<=n)A=(j<=1 and b(q*l-d)<=p or j>=2 and b(d)<=p)if E then
if A then
if V==0 or z-V>=ak*60 then
if v<Y then
Q(1,y)aa=y
end
end
end
end
end
end
end
end
if not aa then
Q(1,t)end
W(1,a)W(2,d)end
function onDraw()if ao then
if r then
if E then
m(0,0,"VALID yaw thrsh: "..(aw):format(n)..ax..(aw):format(f<=1 and b(r*h-a)or f>=2 and b(a)))else
m(0,0,"INVALID yaw thrsh: "..(aw):format(n)..ax..(aw):format(f<=1 and b(r*h-a)or f>=2 and b(a)))end
else
m(0,0,"horizontal_rot doesnt exist")end
if q then
if A then
m(0,20,"VALID pitch thrsh: "..(aw):format(p)..av..(aw):format(j<=1 and b(q*l-d)or j>=2 and b(d)))else
m(0,20,"INVALID pitch thrsh: "..(aw):format(p)..av..(aw):format(j<=1 and b(q*l-d)or j>=2 and b(d)))end
else
m(0,20,"vertical_rot doesnt exist")end
end
end
function k.O(g,min,max)return max<g and max or min>g and min or g
end
function c(g)return g~=g and 0 or g
end
function ah(g,min,max)return(g-min)/(max-min)%1*(max-min)+min
end
