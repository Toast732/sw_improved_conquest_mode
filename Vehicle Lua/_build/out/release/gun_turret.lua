-- Author: Toastery
-- GitHub: https://github.com/Toast732
-- Workshop: 
--
-- Developed & Minimized using LifeBoatAPI - Stormworks Lua plugin for VSCode
-- https://code.visualstudio.com/download (search "Stormworks Lua with LifeboatAPI" extension)
--      By Nameous Changey
-- Minimized Size: 2548 (2862 with comment) chars
ax="%.3f"
aw="\npitch from tar: "
av="\nyaw from tar: "

M=true
s=false
U=property
T=input
k=math
Q=output
p=screen.drawText
O=Q.setNumber
Y=Q.setBool
b=k.abs
e=T.getNumber
R=k.atan
_=U.getNumber
t=U.getBool
W=s
A=0
P=0
a=0
d=0
ar=t("Enable Debug")af=t("Invert Horizontal Rotation")at=t("Invert Vertical Rotation")au=t("Aim Mode")S=t("Requires Is Occupied?")h=_("Horizontal Pivot Type")j=_("Vertical Pivot Type")B=_("Angle Units")w=_("Horizontal Max Angle")I=_("Horizontal Min Angle")N=_("Vertical Max Angle")C=_("Vertical Min Angle")an=_("Time Between Shots (s)")u=_("Min Mass")D=_("Max Mass")aj=_("Min Y")ag=_("Max Y")l=_("Yaw Threshold")m=_("Pitch Threshold")ae=_("Min Distance")V=_("Max Distance")K=k.pi*2
f=4
o=4
L=1
n=1
function am(z,H,x,J)return R(z-x,H-J)/K
end
function as(x,J,z,H)return k.sqrt((z-x)^2+(H-J)^2)end
function ah()g=1
if B==1 then
g=K
elseif B==2 then
g=400
elseif B==3 then
g=360
end
if h>=2 then
f=1
end
if j>=2 then
o=1
end
L=f
if af then
L=-f
end
n=o
if at then
n=-o
end
w=c(w/g/f)I=c(I/g/f)N=c(N/g/o)C=c(C/g/o)l=c(l/g)m=c(m/g)end
function onTick()local ab=s
if not W then
ah()W=M
end
A=A+1
a=0
d=0
E=s
G=s
ao=T.getBool(1)if not S or S and ao then
y=e(10)if D==0 and u==0 or D==0 and u>=0 and y>=u or y>=u and y<=D then
F=e(2)if F>=aj and F<=ag then
ac=e(7)X=e(9)Z=e(1)aa=e(3)v=as(ac,X,Z,aa)if v>=ae and v<=V+300 then
ap=e(8)ak=-e(4)r=e(5)q=e(6)ai=e(11)*4
al=ak-am(Z,aa,ac,X)a=c(k.ad(al,I,w)*L)if h<=1 then
a=c(aq(a,-1,1))end
if h>=2 then
a=c(((a-r*f)%1+1.5)%1-.5)end
d=c(k.ad(R((F-ap)/v)/K,C,N)*n)+ai
if j>=2 then
d=c(((d-q*o)%1+1.5)%1-.5)end
E=(h<=1 and b(r*f-a)<=l or h>=2 and b(a)<=l)G=(j<=1 and b(q*n-d)<=m or j>=2 and b(d)<=m)if E then
if G then
if P==0 or A-P>=an*60 then
if v<V then
Y(1,M)ab=M
end
end
end
end
end
end
end
end
if not ab then
Y(1,s)end
O(1,a)O(2,d)end
function onDraw()if ar then
if r then
if E then
p(0,0,"VALID yaw thrsh: "..(ax):format(l)..av..(ax):format(h<=1 and b(r*f-a)or h>=2 and b(a)))else
p(0,0,"INVALID yaw thrsh: "..(ax):format(l)..av..(ax):format(h<=1 and b(r*f-a)or h>=2 and b(a)))end
else
p(0,0,"horizontal_rot doesnt exist")end
if q then
if G then
p(0,20,"VALID pitch thrsh: "..(ax):format(m)..aw..(ax):format(j<=1 and b(q*n-d)or j>=2 and b(d)))else
p(0,20,"INVALID pitch thrsh: "..(ax):format(m)..aw..(ax):format(j<=1 and b(q*n-d)or j>=2 and b(d)))end
else
p(0,20,"vertical_rot doesnt exist")end
end
end
function k.ad(i,min,max)return max<i and max or min>i and min or i
end
function c(i)return i~=i and 0 or i
end
function aq(i,min,max)return(i-min)/(max-min)%1*(max-min)+min
end
