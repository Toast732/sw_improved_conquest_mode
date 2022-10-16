-- Author: Toastery
-- GitHub: https://github.com/Toast732
-- Workshop: 
--
-- Developed & Minimized using LifeBoatAPI - Stormworks Lua plugin for VSCode
-- https://code.visualstudio.com/download (search "Stormworks Lua with LifeboatAPI" extension)
--      By Nameous Changey
-- Minimized Size: 2590 (2904 with comment) chars
at="\nyaw from tar: "
as="\npitch from tar: "
ar="%.3f"

N=true
Z=property
Y=input
n=math
M=output
o=screen.drawText
P=M.setNumber
a=n.abs
h=Y.getNumber
O=n.atan
_=Z.getNumber
r=Z.getBool
X=false
u=0
J=0
w=0
b=0
c=0
an=r("Enable Debug")ap=r("Invert Horizontal Rotation")aa=r("Invert Vertical Rotation")aq=r("Aim Mode")T=r("Requires Is Occupied?")d=_("Horizontal Pivot Type")g=_("Vertical Pivot Type")x=_("Angle Units")F=_("Horizontal Max Angle")y=_("Horizontal Min Angle")B=_("Vertical Max Angle")I=_("Vertical Min Angle")ag=_("Missile Count")af=_("Time Between Missiles (s)")s=_("Min Mass")A=_("Max Mass")al=_("Min Y")ao=_("Max Y")l=_("Yaw Threshold")m=_("Pitch Threshold")ak=_("Min Distance")U=_("Max Distance")E=n.pi*2
f=4
k=4
C=1
t=1
function ae(G,K,L,H)return O(L-G,H-K)/E
end
function ab(L,H,G,K)return n.sqrt((G-L)^2+(K-H)^2)end
function ad()j=1
if x==1 then
j=E
elseif x==2 then
j=400
elseif x==3 then
j=360
end
if d>=2 then
f=1
end
if g>=2 then
k=1
end
C=f
if ap then
C=-f
end
t=k
if aa then
t=-k
end
F=e(F/j/f)y=e(y/j/f)B=e(B/j/k)I=e(I/j/k)l=e(l/j)m=e(m/j)end
function onTick()if not X then
ad()X=N
end
u=u+1
b=0
c=0
if w<ag then
am=Y.getBool(1)if not T or T and am then
D=h(10)if A==0 and s==0 or A==0 and s>=0 and D>=s or D>=s and D<=A then
z=h(2)if z>=al and z<=ao then
R=h(7)S=h(9)V=h(1)W=h(3)v=ab(R,S,V,W)if v>=ak and v<=U+300 then
ah=h(8)ai=-h(4)p=h(5)q=h(6)aj=ai-ae(V,W,R,S)b=e(n.Q(aj,y,F)*C)if d<=1 then
b=e(ac(b,-1,1))end
if d>=2 then
b=e(((b-p*f)%1+1.5)%1-.5)end
c=e(n.Q(O((z-ah)/v)/E,I,B)*t)if g>=2 then
c=e(((c-q*k)%1+1.5)%1-.5)end
if d<=1 and a(p*f-b)<=l or d>=2 and a(b)<=l then
if g<=1 and a(q*t-c)<=m or g>=2 and a(c)<=m then
if J==0 or u-J>=af*60 then
if v<U then
w=w+1
M.setBool(w,N)J=u
end
end
end
end
end
end
end
end
end
P(1,b)P(2,c)end
function onDraw()if an then
if p then
if d<=1 and a(p*f-b)<=l or d>=2 and a(b)<=l then
o(0,0,"VALID yaw thrsh: "..(ar):format(l)..at..(ar):format(d<=1 and a(p*f-b)or d>=2 and a(b)))else
o(0,0,"INVALID yaw thrsh: "..(ar):format(l)..at..(ar):format(d<=1 and a(p*f-b)or d>=2 and a(b)))end
else
o(0,0,"horizontal_rot doesnt exist")end
if q then
if g<=1 and a(q*k-c)<=m or g>=2 and a(c)<=m then
o(0,20,"VALID pitch thrsh: "..(ar):format(m)..as..(ar):format(g<=1 and a(q*k-c)or g>=2 and a(c)))else
o(0,20,"INVALID pitch thrsh: "..(ar):format(m)..as..(ar):format(g<=1 and a(q*k-c)or g>=2 and a(c)))end
else
o(0,20,"vertical_rot doesnt exist")end
end
end
function n.Q(i,min,max)return max<i and max or min>i and min or i
end
function e(i)return i~=i and 0 or i
end
function ac(i,min,max)return(i-min)/(max-min)%1*(max-min)+min
end
