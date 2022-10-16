-- Author: Toastery
-- GitHub: https://github.com/Toast732
-- Workshop: 
--
-- Developed & Minimized using LifeBoatAPI - Stormworks Lua plugin for VSCode
-- https://code.visualstudio.com/download (search "Stormworks Lua with LifeboatAPI" extension)
--      By Nameous Changey
-- Minimized Size: 1786 (2100 with comment) chars

ak=false
aa=property
v=math
am=output
_=am.setNumber
f=am.setBool
R=v.abs
a=input.getNumber
P=v.max
an=aa.getText
aw=an("Yaw navigation constant")or 5
ay=an("Pitch navigation constant")or 7
g=v
ap=g.pi*2
pi=ap/2
atan=g.atan
sqrt=g.sqrt
V=0
Y=0
ai=0
X=0
ae=0
ac=0
ao=0
b,e,p=0,0,0
E,t,u=0,0,0
W,S,ab=0,0,0
F,A,O=0,0,0
h=0
G=0
D=0
r=0
H=0
ag=0
ah=0
d=0
m=0
x=ak
ad=0
af=0
c=75
U=0
aq=0
T=0
al=0
q=0
n=0
z=0
y=0
N=0
I=0
M=0
w=0
C=0
function s(b,ar,au)return v.min(P(b,ar),au)end
function onTick()o=a(10)l=a(11)if w==0 or C==0 then
w=o
C=l
end
aA=g.max(g.min(o*.175+(o-w)*.2,1),-1)av=g.max(g.min(l*.175+(l-C)*.2,1),-1)w=o
C=l
K=a(1)J=a(2)Z=a(3)aj=a(7)>0
k=K~=0 and J~=0
if k then
if a(9)>0 then
E,t,u=K,J,Z
aC,aD,ax=E-W,t-S,u-ab
b,e,p=E+aC*2,t+aD*2,u+ax*2 else b,e,p=K,J,Z
end
end
i=a(4)j=a(5)B=a(6)F=b-i
A=e-j
O=p-B
d=sqrt(F^2+A^2+O^2)Q=atan(F,A)L=atan(O,sqrt(F^2+A^2))z=(i-aq)*60
y=(j-T)*60
N=(B-al)*60
at=atan(z,y)as=atan(N,sqrt(z^2+y^2))n=sqrt(z^2+y^2+N^2)q=(n-U)*60
aB=(Q-at+pi)%ap-pi
az=L-as
if k then
h=(ai-d)*60
G=Q-V
D=L-Y
r=G-X
H=D-ae
ag=r-ac
ah=H-ao
c=d/h
ad=G*R(h)+ag*c*5+r*c^2
af=D*R(h)+ah*c*5+H*c^2
end
f(1,ak)if aj and not x then
_(2,.04)_(1,-0)if not k or aa.getBool("Seeker preference")and d<1000 and h>20 and o~=0 and l~=0 then
_(2,.04-av)_(1,-aA)elseif b~=0 and e~=0 and h>20 and d<3000 then
_(2,.04-af*ay*s(c/6,.3,1)*s(1-c/8,.75,1))_(1,-(ad*aw*s(c/6,.3,1)*s(1-c/8,.75,1)))elseif b~=0 and e~=0 then
_(2,.04-az)_(1,-aB)end
m=m+1
_(3,m)if(d<25 and c<.177 or d<100 and q<-50)and b~=0 and e~=0 and p~=0 and m>30 or m>2400 then
f(1,true)end
x=x
or a(8)>0
I=P(I,n)M=P(M,q)end
V=Q
Y=L
ai=d
X=G
ae=D
ac=r
ao=H
aq=i
T=j
al=B
U=n
_(4,b)_(5,e)_(6,p)_(7,i)_(8,j)_(9,B)_(10,n)_(11,I)_(12,q)_(13,M)f(2,b==0 and e==0)f(3,i==0 and j==0)f(4,k)f(5,x)f(6,aj)if k then
W=E
S=t
ab=u
end
end
