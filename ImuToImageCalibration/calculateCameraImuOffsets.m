clc
clearvars
close all

%% INPUTS
fileName = '28Dec2014_1930UTC';
leftCameraID = 1; % choose cameras to use for stereo imaging
rightCameraID = 2; % choose cameras to use for stereo imaging
imageDirectory =  './SampleData/ImageFiles';  % Image directory
outputDirectory = './SampleResults';  % Directory for results;
calibrationFile = [outputDirectory '/CameraCalibrationResults/StereoCalibrationResults.mat']; % Stereo Calibration
imuDirectory = [outputDirectory '/SyncedImuData'];
fileNamesDirectory = [outputDirectory '/AlignedStereoFileNames'];
offsetsDirectory = [outputDirectory '/CameraImuOffsets']; mkdir(offsetsDirectory)
meanSurfacePlotDirectory = [outputDirectory '/MeanSurfacePlots']; mkdir(meanSurfacePlotDirectory)
nr = 737;
nc = 965;
stereoOptions.DisparityRange = [0 176];    % Must be divisible by 16
stereoOptions.uROI = [175 (nc-15)];
stereoOptions.vROI = [15 (nr-15)];
stereoOptions.Method = 'SemiGlobal';    % Much better than BlockMatching
stereoOptions.BlockSize = 15;            % (Odd integer, 5-255, default: 15)
stereoOptions.ContrastThreshold = 0.5;  % (Scalar value, 0-1, default = 0.5, disable = 1)
stereoOptions.UniquenessThreshold = 15; % (Non-negative integer, default = 15, disable = 0)
stereoOptions.DistanceThreshold = [];   % (Non-negative integer, default = disabled = [])
stereoOptions.medFilt = [5 5];
xMin = -20;
xMax = 20;
yMin = 40;
yMax = 80;
zMax = 8;
xvec = xMin:.25:xMax;
nx = length(xvec);
yvec = yMin:.25:yMax;
ny = length(yvec);
[xgrid,ygrid] = meshgrid(xvec,yvec);
numFramesUse = 200;
randSeed = 42;
incOffsetApprox = 65*pi/180;
rollOffsetApprox = 0;
heaveOffsetApprox = 12; 

%% Load video files names, synchronized IMU data, and stereo calibration results
load([fileNamesDirectory '/' fileName '.mat']);
load([imuDirectory '/' fileName '.mat']);
load(calibrationFile);

%% Stereo process random subset of images
% initialize variables
numFramesUse = min(numFramesUse,numFilesAligned);
zgrid = nan(ny,nx,numFramesUse,'single');
rng(randSeed);
randFrames = ceil(rand(numFramesUse,1)*numFilesAligned);
heaveRand = imuDataSynced.heave(randFrames);
incRand = imuDataSynced.inc(randFrames);
rollRand = imuDataSynced.roll(randFrames);

for j = 1:numFramesUse
    fprintf('Image %d of %d\n',j,numFramesUse)
    
    % Load stereo images
    imageLeft = imread([imageDirectory '/' char(fileNamesAligned{leftCameraID}(randFrames(j)))]);
    imageRight = imread([imageDirectory '/' char(fileNamesAligned{rightCameraID}(randFrames(j)))]);
    
    % Calculate XYZ
    [X,Y,Z,~,~,~] = Stereo2XYZ(imageLeft,imageRight,stereoParams,stereoOptions);
    
    % Rotate XYZ with approximate inc, roll, heave values
    [xRotApprox, yRotApprox, zRotApprox] = World2World(X,Y,Z,incRand(j)*pi/180+incOffsetApprox,rollRand(j)*pi/180+rollOffsetApprox,0);
    zRotApprox = zRotApprox + heaveRand(j) + heaveOffsetApprox;
    
    % Filter out outliers and values outside of sample
    indFilt = abs(zRotApprox) < zMax & xRotApprox < xMax & yRotApprox < yMax &...
        xRotApprox > xMin & yRotApprox > yMin;
    
    % if remaining points greater than some minimum, interpolate to surface
    if sum(indFilt(:))>=100  
        xRot = double(xRotApprox(indFilt));
        yRot = double(yRotApprox(indFilt));
        zRot = double(zRotApprox(indFilt));
        zinterp = scatteredInterpolant(xRot,yRot,zRot,'linear','none');
        zgrid(:,:,j) = single(zinterp(xgrid,ygrid));
    end
    
end

%% Find mean surface, and inc, roll, and heave offsets that make mean surface flat at z=0
heaveMean = nanmean(heaveRand);
rollMean = dirmean(rollRand);
incMean = dirmean(incRand);
zgridMean = nanmean(zgrid,3);
indNan = isnan(zgrid);
indNanTot = sum(indNan,3);
zgridMean(indNanTot>5) = nan;
% Find better angle offsets
[incOffsetTemp,rollOffsetTemp,heaveOffsetTemp,xNew,yNew,zNew] = ...
    improveAngleOffsets(xgrid,ygrid,zgridMean,...
    incMean*pi/180+incOffsetApprox,rollMean*pi/180+rollOffsetApprox,heaveMean+heaveOffsetApprox);
incOffset = incOffsetTemp-incMean*pi/180;
rollOffset = rollOffsetTemp-rollMean*pi/180;
heaveOffset = heaveOffsetTemp-heaveMean;

%% Plot old mean surface vs. new mean surface
f1 = figure(1); clf(f1);
subplot(2,1,1)
pcolor(xgrid,ygrid,zgridMean)
shading('flat')
ylabel('Y [m]')
xlabel('X [m]')
cbar = colorbar;
set(gca,'CLim',[-0.5 0.5]);
ylabel(cbar,'Old Mean Water Level [m]')
subplot(2,1,2)
pcolor(xNew,yNew,zNew)
shading('flat')
ylabel('Y [m]')
xlabel('X [m]')
cbar = colorbar;
set(gca,'CLim',[-0.5 0.5]);
ylabel(cbar,'New Mean Water Level [m]')
print(f1,'-djpeg',[meanSurfacePlotDirectory '/' fileName '.jpg'])

%% Save results
save([offsetsDirectory '/' fileName '.mat'],'incOffset','rollOffset','heaveOffset')

