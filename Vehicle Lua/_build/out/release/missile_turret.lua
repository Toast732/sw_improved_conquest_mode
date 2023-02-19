-- Author: Toastery
-- GitHub: https://github.com/Toast732
-- Workshop: 
--
-- Developed & Minimized using LifeBoatAPI - Stormworks Lua plugin for VSCode
-- https://code.visualstudio.com/download (search "Stormworks Lua with LifeboatAPI" extension)
--      By Nameous Changey
-- Minimized Size: 2645 (2959 with comment) chars
au="%.3f"
at="\npitch from tar: "
as="\nyaw from tar: "

M=true
U=property
T=input
n=math
W=output
o=screen.drawText
Q=W.setNumber
a=n.abs
e=T.getNumber
N=n.atan
_=U.getNumber
r=U.getBool
S=false
w=0
E=0
s=0
b=0
c=0
ak=r("Enable Debug")ab=r("Invert Horizontal Rotation")ah=r("Invert Vertical Rotation")ar=r("Aim Mode")O=r("Requires Is Occupied?")ae=r("Require Can Fire Input?")f=_("Horizontal Pivot Type")g=_("Vertical Pivot Type")z=_("Angle Units")D=_("Horizontal Max Angle")G=_("Horizontal Min Angle")x=_("Vertical Max Angle")I=_("Vertical Min Angle")ap=_("Missile Count")ai=_("Time Between Missiles (s)")v=_("Min Mass")H=_("Max Mass")an=_("Min Y")aq=_("Max Y")m=_("Yaw Threshold")l=_("Pitch Threshold")al=_("Min Distance")Y=_("Max Distance")K=n.pi*2
h=4
j=4
F=1
u=1
function am(B,L,C,J)return N(B-C,L-J)/K
end
function ac(C,J,B,L)return n.sqrt((B-C)^2+(L-J)^2)end
function ad()i=1
if z==1 then
i=K
elseif z==2 then
i=400
elseif z==3 then
i=360
end
if f>=2 then
h=1
end
if g>=2 then
j=1
end
F=h
if ab then
F=-h
end
u=j
if ah then
u=-j
end
D=d(D/i/h)G=d(G/i/h)x=d(x/i/j)I=d(I/i/j)m=d(m/i)l=d(l/i)end
function onTick()if not S then
ad()S=M
end
w=w+1
b=0
c=0
if s<ap then
ag=e(11)==1
if not O or O and ag then
A=e(10)if H==0 and v==0 or H==0 and v>=0 and A>=v or A>=v and A<=H then
y=e(2)if y>=an and y<=aq then
Z=e(7)P=e(9)R=e(1)V=e(3)t=ac(Z,P,R,V)if t>=al and t<=Y+300 then
aa=e(8)af=-e(4)q=e(5)p=e(6)aj=af-am(R,V,Z,P)b=d(n.X(aj,G,D)*F)if f<=1 then
b=d(ao(b,-1,1))end
if f>=2 then
b=d(((b-q)%1+1.5)%1-.5)end
c=d(n.X(N((y-aa)/t)/K,I,x)*u)if g>=2 then
c=d(((c-p*j)%1+1.5)%1-.5)end
if f<=1 and a(q*h-b)<=m or f>=2 and a(b)<=m then
if g<=1 and a(p*u-c)<=l or g>=2 and a(c)<=l then
if E==0 or w-E>=ai*60 then
if t<Y and(not ae or T.getBool(s+1))then
s=s+1
W.setBool(s,M)E=w
end
end
end
end
end
end
end
end
end
Q(1,b)Q(2,c)end
function onDraw()if ak then
if q then
if f<=1 and a(q*h-b)<=m or f>=2 and a(b)<=m then
o(0,0,"VALID yaw thrsh: "..(au):format(m)..as..(au):format(f<=1 and a(q*h-b)or f>=2 and a(b)))else
o(0,0,"INVALID yaw thrsh: "..(au):format(m)..as..(au):format(f<=1 and a(q*h-b)or f>=2 and a(b)))end
else
o(0,0,"horizontal_rot doesnt exist")end
if p then
if g<=1 and a(p*j-c)<=l or g>=2 and a(c)<=l then
o(0,20,"VALID pitch thrsh: "..(au):format(l)..at..(au):format(g<=1 and a(p*j-c)or g>=2 and a(c)))else
o(0,20,"INVALID pitch thrsh: "..(au):format(l)..at..(au):format(g<=1 and a(p*j-c)or g>=2 and a(c)))end
else
o(0,20,"vertical_rot doesnt exist")end
end
end
function n.X(k,min,max)return max<k and max or min>k and min or k
end
function d(k)return k~=k and 0 or k
end
function ao(k,min,max)return(k-min)/(max-min)%1*(max-min)+min
end
