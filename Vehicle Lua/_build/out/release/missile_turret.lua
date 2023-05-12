-- Author: Toastery
-- GitHub: https://github.com/Toast732
-- Workshop: 
--
-- Developed & Minimized using LifeBoatAPI - Stormworks Lua plugin for VSCode
-- https://code.visualstudio.com/download (search "Stormworks Lua with LifeboatAPI" extension)
--      By Nameous Changey
-- Minimized Size: 2664 (2978 with comment) chars
au="%.3f"
at="\nyaw from tar: "
as="\npitch from tar: "

U=true
O=property
N=input
n=math
Z=output
o=screen.drawText
M=Z.setNumber
a=n.abs
e=N.getNumber
Q=n.atan
_=O.getNumber
r=O.getBool
T=false
t=0
z=0
s=0
b=0
c=0
ae=r("Enable Debug")ad=r("Invert Horizontal Rotation")ak=r("Invert Vertical Rotation")ar=r("Aim Mode")V=r("Requires Is Occupied?")ap=r("Require Can Fire Input?")f=_("Horizontal Pivot Type")g=_("Vertical Pivot Type")y=_("Angle Units")H=_("Horizontal Max Angle")J=_("Horizontal Min Angle")F=_("Vertical Max Angle")L=_("Vertical Min Angle")ac=_("Missile Count")af=_("Time Between Missiles (s)")u=_("Min Mass")A=_("Max Mass")ai=_("Min Y")an=_("Max Y")l=_("Yaw Threshold")m=_("Pitch Threshold")aa=_("Min Distance")P=_("Max Distance")G=n.pi*2
k=4
i=4
K=1
v=1
function aj(I,C,B,D)return Q(I-B,C-D)/G
end
function al(B,D,I,C)return n.sqrt((I-B)^2+(C-D)^2)end
function aq()h=1
if y==1 then
h=G
elseif y==2 then
h=400
elseif y==3 then
h=360
end
if f>=2 then
k=1
end
if g>=2 then
i=1
end
K=k
if ad then
K=-k
end
v=i
if ak then
v=-i
end
H=d(H/h/k)J=d(J/h/k)F=d(F/h/i)L=d(L/h/i)l=d(l/h)m=d(m/h)end
function onTick()if not T then
aq()T=U
end
t=t+1
b=0
c=0
debug.log("SW | 0")if s<ac then
ao=e(11)==1
if not V or V and ao then
E=e(10)if A==0 and u==0 or A==0 and u>=0 and E>=u or E>=u and E<=A then
x=e(2)if x>=ai and x<=an then
Y=e(7)X=e(9)S=e(1)R=e(3)w=al(Y,X,S,R)if w>=aa and w<=P+300 then
am=e(8)ah=-e(4)q=e(5)p=e(6)ag=ah-aj(S,R,Y,X)b=d(n.W(ag,J,H)*K)if f<=1 then
b=d(ab(b,-1,1))end
if f>=2 then
b=d(((b-q)%1+1.5)%1-.5)end
c=d(n.W(Q((x-am)/w)/G,L,F)*v)if g>=2 then
c=d(((c-p*i)%1+1.5)%1-.5)end
if f<=1 and a(q*k-b)<=l or f>=2 and a(b)<=l then
if g<=1 and a(p*v-c)<=m or g>=2 and a(c)<=m then
if z==0 or t-z>=af*60 then
if w<P and(not ap or N.getBool(s+1))then
s=s+1
Z.setBool(s,U)z=t
end
end
end
end
end
end
end
end
end
M(1,b)M(2,c)end
function onDraw()if ae then
if q then
if f<=1 and a(q*k-b)<=l or f>=2 and a(b)<=l then
o(0,0,"VALID yaw thrsh: "..(au):format(l)..at..(au):format(f<=1 and a(q*k-b)or f>=2 and a(b)))else
o(0,0,"INVALID yaw thrsh: "..(au):format(l)..at..(au):format(f<=1 and a(q*k-b)or f>=2 and a(b)))end
else
o(0,0,"horizontal_rot doesnt exist")end
if p then
if g<=1 and a(p*i-c)<=m or g>=2 and a(c)<=m then
o(0,20,"VALID pitch thrsh: "..(au):format(m)..as..(au):format(g<=1 and a(p*i-c)or g>=2 and a(c)))else
o(0,20,"INVALID pitch thrsh: "..(au):format(m)..as..(au):format(g<=1 and a(p*i-c)or g>=2 and a(c)))end
else
o(0,20,"vertical_rot doesnt exist")end
end
end
function n.W(j,min,max)return max<j and max or min>j and min or j
end
function d(j)return j~=j and 0 or j
end
function ab(j,min,max)return(j-min)/(max-min)%1*(max-min)+min
end
