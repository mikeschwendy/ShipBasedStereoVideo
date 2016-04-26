function [X,Y,Z,disparityMap,imageLeftRect,imageRightRect] = ...
    Stereo2XYZ(imageLeft,imageRight,stereoParams,stereoOptions)

% rectify
[imageLeftRect, imageRightRect] = ...
    rectifyStereoImages(imageLeft, imageRight, stereoParams);

% define mask
[nv,nu] = size(imageLeftRect);
mask = nan(nv,nu);
if isempty(stereoOptions.vROI)
    stereoOptions.vROI = [1,nv];
end
if isempty(stereoOptions.uROI)
    stereoOptions.uROI = [1,nu];
end
mask(stereoOptions.vROI(1):stereoOptions.vROI(2),...
    stereoOptions.uROI(1):stereoOptions.uROI(2)) = 1;

% find disparity
disparityMap = disparity(imageLeftRect, imageRightRect,...
    'Method', stereoOptions.Method,...
    'DisparityRange', stereoOptions.DisparityRange,...
    'BlockSize', stereoOptions.BlockSize,...
    'ContrastThreshold', stereoOptions.ContrastThreshold,...
    'UniquenessThreshold', stereoOptions.UniquenessThreshold,...
    'DistanceThreshold', stereoOptions.DistanceThreshold);

% Median filter
if ~isempty(stereoOptions.medFilt)
    disparityMap = medfilt2(disparityMap,stereoOptions.medFilt);
    %imageLeftRect = medfilt2(imageLeftRect,stereoOptions.medFilt);
end

% convert to XYZ point cloud
pointCloud = reconstructScene(disparityMap, stereoParams);

% Convert from millimeters to meters.
pointCloud = pointCloud / 1000;

% break into components
X = pointCloud(:, :, 1);
Y = pointCloud(:, :, 2);
Z = pointCloud(:, :, 3);

%  Mask near and far field
X = X.*mask;
Y = Y.*mask;
Z = Z.*mask;
disparityMap = disparityMap.*mask;