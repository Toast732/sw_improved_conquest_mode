-- Author: Toastery
-- GitHub: https://github.com/Toast732
-- Workshop: 
--
-- Developed & Minimized using LifeBoatAPI - Stormworks Lua plugin for VSCode
-- https://code.visualstudio.com/download (search "Stormworks Lua with LifeboatAPI" extension)
--      By Nameous Changey
-- Minimized Size: 2588 (2902 with comment) chars
at="\nyaw from tar: "
as="%.3f"
ar="\npitch from tar: "

U=true
S=property
X=input
n=math
M=output
q=screen.drawText
N=M.setNumber
a=n.abs
g=X.getNumber
O=n.atan
_=S.getNumber
r=S.getBool
W=false
t=0
C=0
s=0
b=0
c=0
al=r("Enable Debug")ap=r("Invert Horizontal Rotation")ai=r("Invert Vertical Rotation")aq=r("Aim Mode")R=r("Requires Is Occupied?")d=_("Horizontal Pivot Type")f=_("Vertical Pivot Type")A=_("Angle Units")I=_("Horizontal Max Angle")D=_("Horizontal Min Angle")H=_("Vertical Max Angle")F=_("Vertical Min Angle")ah=_("Missile Count")aj=_("Time Between Missiles (s)")v=_("Min Mass")G=_("Max Mass")am=_("Min Y")ab=_("Max Y")m=_("Yaw Threshold")l=_("Pitch Threshold")ag=_("Min Distance")Q=_("Max Distance")x=n.pi*2
j=4
k=4
J=1
w=1
function ae(y,K,B,E)return O(y-B,K-E)/x
end
function ao(B,E,y,K)return n.sqrt((y-B)^2+(K-E)^2)end
function an()h=1
if A==1 then
h=x
elseif A==2 then
h=400
elseif A==3 then
h=360
end
if d>=2 then
j=1
end
if f>=2 then
k=1
end
J=j
if ap then
J=-j
end
w=k
if ai then
w=-k
end
I=e(I/h/j)D=e(D/h/j)H=e(H/h/k)F=e(F/h/k)m=e(m/h)l=e(l/h)end
function onTick()if not W then
an()W=U
end
t=t+1
b=0
c=0
if s<ah then
ad=X.getBool(1)if not R or R and ad then
z=g(10)if G==0 and v==0 or G==0 and v>=0 and z>=v or z>=v and z<=G then
L=g(2)if L>=am and L<=ab then
V=g(7)T=g(9)Z=g(1)Y=g(3)u=ao(V,T,Z,Y)if u>=ag and u<=Q+300 then
af=g(8)aa=-g(4)p=g(5)o=g(6)ac=aa-ae(Z,Y,V,T)b=e(n.P(ac,D,I)*J)if d<=1 then
b=e(ak(b,-1,1))end
if d>=2 then
b=e(((b-p)%1+1.5)%1-.5)end
c=e(n.P(O((L-af)/u)/x,F,H)*w)if f>=2 then
c=e(((c-o*k)%1+1.5)%1-.5)end
if d<=1 and a(p*j-b)<=m or d>=2 and a(b)<=m then
if f<=1 and a(o*w-c)<=l or f>=2 and a(c)<=l then
if C==0 or t-C>=aj*60 then
if u<Q then
s=s+1
M.setBool(s,U)C=t
end
end
end
end
end
end
end
end
end
N(1,b)N(2,c)end
function onDraw()if al then
if p then
if d<=1 and a(p*j-b)<=m or d>=2 and a(b)<=m then
q(0,0,"VALID yaw thrsh: "..(as):format(m)..at..(as):format(d<=1 and a(p*j-b)or d>=2 and a(b)))else
q(0,0,"INVALID yaw thrsh: "..(as):format(m)..at..(as):format(d<=1 and a(p*j-b)or d>=2 and a(b)))end
else
q(0,0,"horizontal_rot doesnt exist")end
if o then
if f<=1 and a(o*k-c)<=l or f>=2 and a(c)<=l then
q(0,20,"VALID pitch thrsh: "..(as):format(l)..ar..(as):format(f<=1 and a(o*k-c)or f>=2 and a(c)))else
q(0,20,"INVALID pitch thrsh: "..(as):format(l)..ar..(as):format(f<=1 and a(o*k-c)or f>=2 and a(c)))end
else
q(0,20,"vertical_rot doesnt exist")end
end
end
function n.P(i,min,max)return max<i and max or min>i and min or i
end
function e(i)return i~=i and 0 or i
end
function ak(i,min,max)return(i-min)/(max-min)%1*(max-min)+min
end
