function [incNew,rollNew,hNew,xNew,yNew,zNew] = improveAngleOffsets(xAvg,yAvg,zAvg,incOld,rollOld,hOld)

[xUnRot, yUnRot, zUnRot] = UnWorld2World(xAvg(:),yAvg(:),zAvg(:)-hOld,incOld,rollOld,0);

indFilt = isnan(xUnRot) | isnan(yUnRot) | isnan(zUnRot) ;
[n,~,p] = affine_fit([xUnRot(~indFilt),yUnRot(~indFilt),zUnRot(~indFilt)]);
a = -n(1)/n(3);
b = -n(2)/n(3);
c = -(-p(1)*n(1)-p(2)*n(2))/n(3)+p(3);

rollNew = atan(-a/b);
incNew = atan(a/rollNew);
hNew = c*cos(incNew);
[xNew, yNew, zNew] = World2World(xUnRot,yUnRot,zUnRot,incNew,rollNew,0);
zNew = zNew + hNew;

xNew = reshape(xNew,size(xAvg));
yNew = reshape(yNew,size(yAvg));
zNew = reshape(zNew,size(zAvg));