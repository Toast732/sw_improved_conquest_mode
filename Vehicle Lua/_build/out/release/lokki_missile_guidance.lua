-- Author: Toastery
-- GitHub: https://github.com/Toast732
-- Workshop: 
--
-- Developed & Minimized using LifeBoatAPI - Stormworks Lua plugin for VSCode
-- https://code.visualstudio.com/download (search "Stormworks Lua with LifeboatAPI" extension)
--      By Nameous Changey
-- Minimized Size: 1786 (2100 with comment) chars

S=false
V=property
H=math
am=output
_=am.setNumber
f=am.setBool
Z=H.abs
a=input.getNumber
N=H.max
aj=V.getText
au=aj("Yaw navigation constant")or 5
aB=aj("Pitch navigation constant")or 7
g=H
aa=g.pi*2
pi=aa/2
atan=g.atan
sqrt=g.sqrt
ag=0
al=0
U=0
T=0
ap=0
R=0
X=0
b,d,l=0,0,0
E,A,t=0,0,0
ah,af,ai=0,0,0
u,x,L=0,0,0
h=0
C=0
z=0
w=0
G=0
ad=0
ae=0
e=0
k=0
v=S
ac=0
Y=0
c=75
ab=0
ak=0
aq=0
an=0
q=0
o=0
y=0
r=0
M=0
P=0
Q=0
s=0
F=0
function B(b,ar,aD)return H.min(N(b,ar),aD)end
function onTick()j=a(10)i=a(11)if s==0 or F==0 then
s=j
F=i
end
ax=g.max(g.min(j*.175+(j-s)*.2,1),-1)av=g.max(g.min(i*.175+(i-F)*.2,1),-1)s=j
F=i
O=a(1)J=a(2)W=a(3)ao=a(7)>0
m=O~=0 and J~=0
if m then
if a(9)>0 then
E,A,t=O,J,W
ay,aC,as=E-ah,A-af,t-ai
b,d,l=E+ay*2,A+aC*2,t+as*2 else b,d,l=O,J,W
end
end
p=a(4)n=a(5)D=a(6)u=b-p
x=d-n
L=l-D
e=sqrt(u^2+x^2+L^2)K=atan(u,x)I=atan(L,sqrt(u^2+x^2))y=(p-ak)*60
r=(n-aq)*60
M=(D-an)*60
aw=atan(y,r)az=atan(M,sqrt(y^2+r^2))o=sqrt(y^2+r^2+M^2)q=(o-ab)*60
at=(K-aw+pi)%aa-pi
aA=I-az
if m then
h=(U-e)*60
C=K-ag
z=I-al
w=C-T
G=z-ap
ad=w-R
ae=G-X
c=e/h
ac=C*Z(h)+ad*c*5+w*c^2
Y=z*Z(h)+ae*c*5+G*c^2
end
f(1,S)if ao and not v then
_(2,.04)_(1,-0)if not m or V.getBool("Seeker preference")and e<1000 and h>20 and j~=0 and i~=0 then
_(2,.04-av)_(1,-ax)elseif b~=0 and d~=0 and h>20 and e<3000 then
_(2,.04-Y*aB*B(c/6,.3,1)*B(1-c/8,.75,1))_(1,-(ac*au*B(c/6,.3,1)*B(1-c/8,.75,1)))elseif b~=0 and d~=0 then
_(2,.04-aA)_(1,-at)end
k=k+1
_(3,k)if(e<25 and c<.177 or e<100 and q<-50)and b~=0 and d~=0 and l~=0 and k>30 or k>2400 then
f(1,true)end
v=v
or a(8)>0
P=N(P,o)Q=N(Q,q)end
ag=K
al=I
U=e
T=C
ap=z
R=w
X=G
ak=p
aq=n
an=D
ab=o
_(4,b)_(5,d)_(6,l)_(7,p)_(8,n)_(9,D)_(10,o)_(11,P)_(12,q)_(13,Q)f(2,b==0 and d==0)f(3,p==0 and n==0)f(4,m)f(5,v)f(6,ao)if m then
ah=E
af=A
ai=t
end
end
