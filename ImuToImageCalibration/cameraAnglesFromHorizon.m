function [inc,roll,flag] = cameraAnglesFromHorizon(images,cameraParams,horizonOptions)

% undistort images
[nr,nc,n] = size(images);
imageUndistort = zeros(nr,nc,n,'uint8');
for i = 1:n
    imageUndistort(:,:,i) = undistortImage(images(:,:,i),cameraParams);
end

% set horizon search ROI
if isempty(horizonOptions.Rows)
    horizonOptions.Rows = [1,nr];
end
if isempty(horizonOptions.Cols)
    horizonOptions.Cols = [1,nc];
end

% find horizon in undistorted, unrectified, left image
[theta,r,peakFrac] = FindHorizon(imageUndistort,...
    [horizonOptions.Rows(1),horizonOptions.Cols(1),...
    horizonOptions.Rows(2),horizonOptions.Cols(2)],...
    horizonOptions.Method);

% calculate angles
K = cameraParams.IntrinsicMatrix';
[inc,roll] = Horizon2Angles(theta,r,K);

% determine whether horizon is likely good
flag = peakFrac > horizonOptions.MinScore &...
    inc > horizonOptions.IncRange(1) & inc < horizonOptions.IncRange(2) &...
    roll > horizonOptions.RollRange(1) & roll < horizonOptions.RollRange(2);
    


