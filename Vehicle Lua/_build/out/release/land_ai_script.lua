-- Author: Toastery
-- GitHub: https://github.com/Toast732
-- Workshop: 
--
-- Developed & Minimized using LifeBoatAPI - Stormworks Lua plugin for VSCode
-- https://code.visualstudio.com/download (search "Stormworks Lua with LifeboatAPI" extension)
--      By Nameous Changey
-- Minimized Size: 3357 (3671) chars
bR="aggressive_offroad_speed"
bQ="normal_road_speed"
bP="normal_bridge_speed"
bO="normal_offroad_speed"
bN="aggressive_bridge_speed"
bM="aggressive_road_speed"
bL=.125
bK=.1
bJ=.7
bI=.5
bH=true
bG=false
bF=input
bE=output
bD=math
bC=bD.abs
bB=bE.setBool
bA=bF.getNumber
bz=bE.setNumber
by=bD.min
bx=bD.max
bw=bD.random
bv=property.getNumber
b=0
c=0
d=bG
e=bv("random_speed_range")f=bD.pi*2
local g={[0]={[0]=0,[1]=0},[1]={[0]=bw(bv(bQ)-e,bv(bQ)+e),[1]=bw(bv(bM)-e,bv(bM)+e)},[2]={[0]=bw(bv(bO)-e,bv(bO)+e),[1]=bw(bv(bR)-e,bv(bR)+e)},[3]={[0]=bw(bv(bP)-e,bv(bP)+e),[1]=bw(bv(bN)-e,bv(bN)+e)}}function h(i,j)return bw()*(j-i)+i
end
function k(l,m,n,o)return bD.atan(l-n,m-o)/f
end
function p(n,o,l,m)return bD.sqrt((l-n)^2+(m-o)^2)end
function q(r,s)if r>s then
return bH
else
return bG
end
end
local t=bv("turning_rate_random_range")local u=bv("turning_rate")+h(-t,-t)function v(w,x,y,z)if not x then
local A=c-bx(by(c-w,u),-u)bz(1,A)c=A
else
local B=bv("aggressive_behaviour")local C=1
if B==0 then
C=bA(13)elseif B==1 then
C=0
end
local D=1
if z<100 and C==0 then
D=z/100
elseif z<50 then
D=z/50
end
local E=bA(14)if w>0 then
local F=bv("minimum_speed_random_range")local G=bv("minimum_speed")+h(-F,-F)if C==1 then
G=G*1.5
end
bz(1,bx(g[E][C]/bx(y,1)*(D),G))else
bz(1,0)end
end
end
function H(w,I)if not I then
bz(2,w)else
local J=b-bx(by(b-w,u),-u)bz(2,J)b=J
end
end
function onTick()local K=bv("steering_type")local L=bv("front_dist_tolerance")local M=bv("front_down_dist_tolerance")local N=bv("rear_dist_tolerance")local O=bv("rear_down_dist_tolerance")local P=bv("wall_safe_dist")local Q=bv("ground_safe_dist")local R=bv("tank_turn_speed")local S=bF.getBool(1)local T=bA(1)local U=bA(2)local V=bA(3)local W=bA(4)local X=bA(15)local Y=bA(16)local Z=-bA(5)local bb=k(V,W,T,U)local bc=bA(6)local bd=bA(7)local be=bA(8)local bf=bA(9)local bg=bA(10)local bh=bA(11)local bi=bc-L
local bj=bd-M
local bk=be-M
local bl=bf-N
local bm=bg-O
local bn=bh-O
if V~=0 or W~=0 then
z=p(T,U,V,W)bo=p(T,U,X,Y)bz(5,z)if bo>=2.5 and S then
bB(1,bH)bz(3,Z)local bp=(((Z-bb)%1+1.5)%1-bI)bz(5,bb)bz(6,bp)if K==0 then
local bq=bv("steering_max_angle")local br=bA(12)if bp>bJ or bp<-bJ then
if not d then
bB(2,bH)v(0)H(0,bH)bB(3,bH)if br<bK then
d=bH
bB(3,bG)end
else
bB(3,bG)H(-(bp*bq),bH)v(1,bH,bp,bo)bB(2,bH)d=bH
end
bz(7,1)elseif q(bi,P)then
if d then
bB(2,bG)v(0,bH,bp,bo)H(0,bH)bB(3,bH)if br<bK then
d=bG
bB(3,bG)end
else
bB(3,bG)H((bp*bq),bH)v(1,bH,bp,bo)bB(2,bG)d=bG
end
bz(7,2)elseif q(bl,P)then
if not d then
bB(2,bH)v(0)H(0,bH)bB(3,bH)if br<bK then
d=bH
bB(3,bG)end
else
bB(3,bG)H(-(bp*bq),bH)v(1,bH,bp,bo)bB(2,bH)d=bH
end
bz(7,3)else
bB(2,bG)bB(1,bG)v(0)H(0,bH)bz(7,4)end
elseif K==1 then
local bs=1
if z<50 then
bs=bx(z/50,bJ)end
local bt=1
if bC(bp)<bL then
bt=bx(bC(bp)/bL,.01)end
bz(4,bt)if bp<.026 and bp>-.026 then
bz(7,2)if q(bi,P)then
v(1*bs)if bp<0 then
H((R*bt),bH)else
H(-(R*bt),bH)end
end
elseif bp>.495 and bp<.51 or bp<-.495 and bp>-.51 then
bz(7,3)if q(bi,P)then
v(-1*bs)local bu=1
if bC(bI-bC(bp))<bL then
bu=bx(bC(bI-bC(bp))/bL,.01)end
bz(8,bu)if bp<0 then
H((R*bu),bH)else
H(-(R*bu),bH)end
end
elseif bp<-.00555556 and bp>=-.49 then
bz(7,1)if q(Q,bj)and q(Q,bn)then
H(R*bt,bH)if bt==1 then
v(0)else
v((.08/bt))end
end
else
bz(7,1)if q(Q,bk)and q(Q,bm)then
H(-R*bt,bH)if bt==1 then
v(0)else
v((.08/bt))end
end
end
end
else
bz(7,5)bB(1,bG)end
end
end
