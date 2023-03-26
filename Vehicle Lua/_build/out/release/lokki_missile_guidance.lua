-- Author: Toastery
-- GitHub: https://github.com/Toast732
-- Workshop: 
--
-- Developed & Minimized using LifeBoatAPI - Stormworks Lua plugin for VSCode
-- https://code.visualstudio.com/download (search "Stormworks Lua with LifeboatAPI" extension)
--      By Nameous Changey
-- Minimized Size: 1786 (2100 with comment) chars

U=false
aa=property
u=math
ap=output
_=ap.setNumber
f=ap.setBool
ak=u.abs
a=input.getNumber
K=u.max
ac=aa.getText
ar=ac("Yaw navigation constant")or 5
aB=ac("Pitch navigation constant")or 7
g=u
V=g.pi*2
pi=V/2
atan=g.atan
sqrt=g.sqrt
aj=0
ad=0
ai=0
ao=0
S=0
ag=0
ae=0
b,d,i=0,0,0
D,G,E=0,0,0
an,X,aq=0,0,0
H,F,I=0,0,0
h=0
A=0
s=0
r=0
v=0
W=0
Y=0
e=0
k=0
C=U
ah=0
ab=0
c=75
af=0
Z=0
al=0
am=0
w=0
o=0
z=0
q=0
J=0
M=0
N=0
y=0
x=0
function B(b,aD,ay)return u.min(K(b,aD),ay)end
function onTick()j=a(10)p=a(11)if y==0 or x==0 then
y=j
x=p
end
at=g.max(g.min(j*.175+(j-y)*.2,1),-1)aw=g.max(g.min(p*.175+(p-x)*.2,1),-1)y=j
x=p
L=a(1)O=a(2)T=a(3)R=a(7)>0
n=L~=0 and O~=0
if n then
if a(9)>0 then
D,G,E=L,O,T
az,aA,ax=D-an,G-X,E-aq
b,d,i=D+az*2,G+aA*2,E+ax*2 else b,d,i=L,O,T
end
end
m=a(4)l=a(5)t=a(6)H=b-m
F=d-l
I=i-t
e=sqrt(H^2+F^2+I^2)P=atan(H,F)Q=atan(I,sqrt(H^2+F^2))z=(m-Z)*60
q=(l-al)*60
J=(t-am)*60
av=atan(z,q)as=atan(J,sqrt(z^2+q^2))o=sqrt(z^2+q^2+J^2)w=(o-af)*60
au=(P-av+pi)%V-pi
aC=Q-as
if n then
h=(ai-e)*60
A=P-aj
s=Q-ad
r=A-ao
v=s-S
W=r-ag
Y=v-ae
c=e/h
ah=A*ak(h)+W*c*5+r*c^2
ab=s*ak(h)+Y*c*5+v*c^2
end
f(1,U)if R and not C then
_(2,.04)_(1,-0)if not n or aa.getBool("Seeker preference")and e<1000 and h>20 and j~=0 and p~=0 then
_(2,.04-aw)_(1,-at)elseif b~=0 and d~=0 and h>20 and e<3000 then
_(2,.04-ab*aB*B(c/6,.3,1)*B(1-c/8,.75,1))_(1,-(ah*ar*B(c/6,.3,1)*B(1-c/8,.75,1)))elseif b~=0 and d~=0 then
_(2,.04-aC)_(1,-au)end
k=k+1
_(3,k)if(e<25 and c<.177 or e<100 and w<-50)and b~=0 and d~=0 and i~=0 and k>30 or k>2400 then
f(1,true)end
C=C
or a(8)>0
M=K(M,o)N=K(N,w)end
aj=P
ad=Q
ai=e
ao=A
S=s
ag=r
ae=v
Z=m
al=l
am=t
af=o
_(4,b)_(5,d)_(6,i)_(7,m)_(8,l)_(9,t)_(10,o)_(11,M)_(12,w)_(13,N)f(2,b==0 and d==0)f(3,m==0 and l==0)f(4,n)f(5,C)f(6,R)if n then
an=D
X=G
aq=E
end
end
