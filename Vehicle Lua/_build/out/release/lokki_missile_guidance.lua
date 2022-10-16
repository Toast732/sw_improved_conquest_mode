-- Author: Toastery
-- GitHub: https://github.com/Toast732
-- Workshop: 
--
-- Developed & Minimized using LifeBoatAPI - Stormworks Lua plugin for VSCode
-- https://code.visualstudio.com/download (search "Stormworks Lua with LifeboatAPI" extension)
--      By Nameous Changey
-- Minimized Size: 1786 (2100 with comment) chars

R=false
al=property
A=math
aq=output
_=aq.setNumber
g=aq.setBool
aj=A.abs
a=input.getNumber
J=A.max
ae=al.getText
au=ae("Yaw navigation constant")or 5
ar=ae("Pitch navigation constant")or 7
f=A
S=f.pi*2
pi=S/2
atan=f.atan
sqrt=f.sqrt
X=0
V=0
ap=0
U=0
Y=0
W=0
ah=0
c,e,o=0,0,0
B,w,D=0,0,0
Z,aa,T=0,0,0
x,z,K=0,0,0
h=0
t=0
C=0
v=0
F=0
an=0
ac=0
d=0
n=0
q=R
am=0
af=0
b=75
ab=0
ai=0
ad=0
ag=0
y=0
i=0
r=0
H=0
L=0
Q=0
O=0
G=0
u=0
function E(c,av,aw)return A.min(J(c,av),aw)end
function onTick()p=a(10)l=a(11)if G==0 or u==0 then
G=p
u=l
end
az=f.max(f.min(p*.175+(p-G)*.2,1),-1)at=f.max(f.min(l*.175+(l-u)*.2,1),-1)G=p
u=l
P=a(1)M=a(2)ao=a(3)ak=a(7)>0
k=P~=0 and M~=0
if k then
if a(9)>0 then
B,w,D=P,M,ao
ax,aA,ay=B-Z,w-aa,D-T
c,e,o=B+ax*2,w+aA*2,D+ay*2 else c,e,o=P,M,ao
end
end
m=a(4)j=a(5)s=a(6)x=c-m
z=e-j
K=o-s
d=sqrt(x^2+z^2+K^2)I=atan(x,z)N=atan(K,sqrt(x^2+z^2))r=(m-ai)*60
H=(j-ad)*60
L=(s-ag)*60
aC=atan(r,H)aB=atan(L,sqrt(r^2+H^2))i=sqrt(r^2+H^2+L^2)y=(i-ab)*60
as=(I-aC+pi)%S-pi
aD=N-aB
if k then
h=(ap-d)*60
t=I-X
C=N-V
v=t-U
F=C-Y
an=v-W
ac=F-ah
b=d/h
am=t*aj(h)+an*b*5+v*b^2
af=C*aj(h)+ac*b*5+F*b^2
end
g(1,R)if ak and not q then
_(2,.04)_(1,-0)if not k or al.getBool("Seeker preference")and d<1000 and h>20 and p~=0 and l~=0 then
_(2,.04-at)_(1,-az)elseif c~=0 and e~=0 and h>20 and d<3000 then
_(2,.04-af*ar*E(b/6,.3,1)*E(1-b/8,.75,1))_(1,-(am*au*E(b/6,.3,1)*E(1-b/8,.75,1)))elseif c~=0 and e~=0 then
_(2,.04-aD)_(1,-as)end
n=n+1
_(3,n)if(d<25 and b<.177 or d<100 and y<-50)and c~=0 and e~=0 and o~=0 and n>30 or n>2400 then
g(1,true)end
q=q
or a(8)>0
Q=J(Q,i)O=J(O,y)end
X=I
V=N
ap=d
U=t
Y=C
W=v
ah=F
ai=m
ad=j
ag=s
ab=i
_(4,c)_(5,e)_(6,o)_(7,m)_(8,j)_(9,s)_(10,i)_(11,Q)_(12,y)_(13,O)g(2,c==0 and e==0)g(3,m==0 and j==0)g(4,k)g(5,q)g(6,ak)if k then
Z=B
aa=w
T=D
end
end
