-- Made by lassi/Neottious (https://steamcommunity.com/id/i5-2500k)

NY=property.getText("Yaw navigation constant"
)or 5
NP=property.getText("Pitch navigation constant"
)or 7
m=math
tau=m.pi*2
pi=tau/2
atan=m.atan
sqrt=m.sqrt
ldyaw=0
ldpitch=0
ldistance=0
lloshr=0
llosvr=0
llosha=0
llosva=0
x,y,z=0,0,0
tx,ty,tz=0,0,0
lx,ly,lz=0,0,0
dx,dy,dz=0,0,0
closingv=0
loshr=0
losvr=0
losha=0
losva=0
loshj=0
losvj=0
distance=0
runtime=0
fuzed=false
finYaw=0
finPitch=0
tgo=75
lspeed=0
lastX=0
lastY=0
lastZ=0
accel=0
speed=0
dmX=0
dmY=0
dmZ=0
speedPeak=0
accelPeak=0
lastpx=0
lastpy=0
function clamp(x,a,b)
return math.min(math.max(x,a),b)
end

function onTick()
px=input.getNumber(10)
py=input.getNumber(11)
if lastpx==0 or lastpy==0 then
lastpx=px
lastpy=py
end
activeX=m.max(m.min(px*.175+(px-lastpx)*0.2,1),-1)
activeY=m.max(m.min(py*.175+(py-lastpy)*0.2,1),-1)
lastpx=px
lastpy=py
rx=input.getNumber(1)
ry=input.getNumber(2)
rz=input.getNumber(3)
launch=input.getNumber(7)>0
accept=rx~=0 and ry~=0
if accept then
if input.getNumber(9)>0 then
tx,ty,tz=rx,ry,rz
dtx,dty,dtz=tx-lx,ty-ly,tz-lz
x,y,z=tx+dtx*2,ty+dty*2,tz+dtz*2 else x,y,z=rx,ry,rz 
end
end
X=input.getNumber(4)
Y=input.getNumber(5)
Z=input.getNumber(6)
dx=x-X
dy=y-Y
dz=z-Z
distance=sqrt(dx^2+dy^2+dz^2)
dyaw=atan(dx,dy)
dpitch=atan(dz,sqrt(dx^2+dy^2))
dmX=(X-lastX)*60
dmY=(Y-lastY)*60
dmZ=(Z-lastZ)*60
selfCrs=atan(dmX,dmY)
selfVV=atan(dmZ,sqrt(dmX^2+dmY^2))
speed=sqrt(dmX^2+dmY^2+dmZ^2)
accel=(speed-lspeed)*60
pursuitX=(dyaw-selfCrs+pi)%tau-pi
pursuitY=dpitch-selfVV
if accept then
closingv=(ldistance-distance)*60
loshr=dyaw-ldyaw
losvr=dpitch-ldpitch
losha=loshr-lloshr
losva=losvr-llosvr
loshj=losha-llosha
losvj=losva-llosva
tgo=distance/closingv
finYaw=loshr*math.abs(closingv)+loshj*tgo*5+losha*tgo^2
finPitch=losvr*math.abs(closingv)+losvj*tgo*5+losva*tgo^2 
end
output.setBool(1,false)
if launch and not fuzed then
output.setNumber(2,0.04)
output.setNumber(1,-0)
if not accept or property.getBool("Seeker preference"
)and distance<1000 and closingv>20 and px~=0 and py~=0 then
output.setNumber(2,0.04-activeY)
output.setNumber(1,-activeX)
elseif x~=0 and y~=0 and closingv>20 and distance<3000 then
output.setNumber(2,0.04-finPitch*NP*clamp(tgo/6,0.3,1)*clamp(1-tgo/8,0.75,1))
output.setNumber(1,-(finYaw*NY*clamp(tgo/6,0.3,1)*clamp(1-tgo/8,0.75,1)))
elseif x~=0 and y~=0 then
output.setNumber(2,0.04-pursuitY)
output.setNumber(1,-pursuitX)
end
runtime=runtime+1
output.setNumber(3,runtime)
if(distance<25 and tgo<0.177 or distance<100 and accel<-50)and x~=0 and y~=0 and z~=0 and runtime>30 or runtime>2400 then
output.setBool(1,true)
end
fuzed=fuzed
or input.getNumber(8)>0
speedPeak=math.max(speedPeak,speed)
accelPeak=math.max(accelPeak,accel)
end
ldyaw=dyaw
ldpitch=dpitch
ldistance=distance
lloshr=loshr
llosvr=losvr
llosha=losha
llosva=losva
lastX=X
lastY=Y
lastZ=Z
lspeed=speed
output.setNumber(4,x)
output.setNumber(5,y)
output.setNumber(6,z)
output.setNumber(7,X)
output.setNumber(8,Y)
output.setNumber(9,Z)
output.setNumber(10,speed)
output.setNumber(11,speedPeak)
output.setNumber(12,accel)
output.setNumber(13,accelPeak)
output.setBool(2,x==0 and y==0)
output.setBool(3,X==0 and Y==0)
output.setBool(4,accept)
output.setBool(5,fuzed)
output.setBool(6,launch)
if accept then
lx=tx
ly=ty
lz=tz
end
end