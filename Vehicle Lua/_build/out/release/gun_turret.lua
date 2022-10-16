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

z=true
r=false
R=property
W=input
k=math
ab=output
o=screen.drawText
X=ab.setNumber
Y=ab.setBool
b=k.abs
d=W.getNumber
U=k.atan
_=R.getNumber
s=R.getBool
ac=r
F=0
aa=0
a=0
c=0
an=s("Enable Debug")ao=s("Invert Horizontal Rotation")ag=s("Invert Vertical Rotation")au=s("Aim Mode")T=s("Requires Is Occupied?")h=_("Horizontal Pivot Type")j=_("Vertical Pivot Type")C=_("Angle Units")A=_("Horizontal Max Angle")M=_("Horizontal Min Angle")w=_("Vertical Max Angle")K=_("Vertical Min Angle")ae=_("Time Between Shots (s)")u=_("Min Mass")x=_("Max Mass")am=_("Min Y")at=_("Max Y")l=_("Yaw Threshold")m=_("Pitch Threshold")al=_("Min Distance")Z=_("Max Distance")E=k.pi*2
g=4
p=4
N=1
n=1
function aj(H,B,D,L)return U(H-D,B-L)/E
end
function as(D,L,H,B)return k.sqrt((H-D)^2+(B-L)^2)end
function af()f=1
if C==1 then
f=E
elseif C==2 then
f=400
elseif C==3 then
f=360
end
if h>=2 then
g=1
end
if j>=2 then
p=1
end
N=g
if ao then
N=-g
end
n=p
if ag then
n=-p
end
A=e(A/f/g)M=e(M/f/g)w=e(w/f/p)K=e(K/f/p)l=e(l/f)m=e(m/f)end
function onTick()local V=r
if not ac then
af()ac=z
end
F=F+1
a=0
c=0
G=r
I=r
ah=W.getBool(1)if not T or T and ah then
J=d(10)if x==0 and u==0 or x==0 and u>=0 and J>=u or J>=u and J<=x then
y=d(2)if y>=am and y<=at then
ad=d(7)Q=d(9)P=d(1)O=d(3)v=as(ad,Q,P,O)if v>=al and v<=Z+300 then
ai=d(8)aq=-d(4)t=d(5)q=d(6)ap=d(11)*4
ar=aq-aj(P,O,ad,Q)a=e(k.S(ar,M,A)*N)if h<=1 then
a=e(ak(a,-1,1))end
if h>=2 then
a=e(((a-t*g)%1+1.5)%1-.5)end
c=e(k.S(U((y-ai)/v)/E,K,w)*n)+ap
if j>=2 then
c=e(((c-q*p)%1+1.5)%1-.5)end
G=(h<=1 and b(t*g-a)<=l or h>=2 and b(a)<=l)I=(j<=1 and b(q*n-c)<=m or j>=2 and b(c)<=m)if G then
if I then
if aa==0 or F-aa>=ae*60 then
if v<Z then
Y(1,z)V=z
end
end
end
end
end
end
end
end
if not V then
Y(1,r)end
X(1,a)X(2,c)end
function onDraw()if an then
if t then
if G then
o(0,0,"VALID yaw thrsh: "..(aw):format(l)..ax..(aw):format(h<=1 and b(t*g-a)or h>=2 and b(a)))else
o(0,0,"INVALID yaw thrsh: "..(aw):format(l)..ax..(aw):format(h<=1 and b(t*g-a)or h>=2 and b(a)))end
else
o(0,0,"horizontal_rot doesnt exist")end
if q then
if I then
o(0,20,"VALID pitch thrsh: "..(aw):format(m)..av..(aw):format(j<=1 and b(q*n-c)or j>=2 and b(c)))else
o(0,20,"INVALID pitch thrsh: "..(aw):format(m)..av..(aw):format(j<=1 and b(q*n-c)or j>=2 and b(c)))end
else
o(0,20,"vertical_rot doesnt exist")end
end
end
function k.S(i,min,max)return max<i and max or min>i and min or i
end
function e(i)return i~=i and 0 or i
end
function ak(i,min,max)return(i-min)/(max-min)%1*(max-min)+min
end
