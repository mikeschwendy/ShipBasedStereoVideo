function [x2, y2, z2] = UnWorld2World(x1,y1,z1,inc,roll,azi)


R_roll = [cos(roll), -sin(roll), 0; sin(roll), cos(roll), 0; 0, 0, 1];
R_pitch = [1, 0, 0; 0, -cos(inc), -sin(inc); 0 sin(inc) -cos(inc)];
R_azi = [cos(azi), sin(azi), 0; -sin(azi), cos(azi), 0;  0 0 1];

R = R_roll*R_pitch*R_azi;
%R = R_azi*R_pitch*R_roll;

pw = ([R, zeros(3,1); zeros(1,3), 1])*...
    ([x1(:)'; y1(:)';  z1(:)'; ones(size(x1(:)'))]);

x2 = pw(1,:)./pw(4,:);
y2 = pw(2,:)./pw(4,:);
z2 = pw(3,:)./pw(4,:);

x2 = reshape(x2,size(x1));
y2 = reshape(y2,size(x1));
z2 = reshape(z2,size(x1));