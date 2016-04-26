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
xyzResultsDirectory = [outputDirectory '/XYZResults']; mkdir(xyzResultsDirectory)
xyzPlotsDirectory = [outputDirectory '/XYZPlots']; mkdir(xyzPlotsDirectory)
disparityPlotsDirectory = [outputDirectory '/DisparityPlots']; mkdir(disparityPlotsDirectory)
makePlots = true;
plotSkip = 25;
correctForSurgeSwayAndHeading = false;
nr = 737;
nc = 965;
[u,v] = meshgrid(1:nc,nr:-1:1);
stereoOptions.DisparityRange = [0 176];    % Must be divisible by 16
stereoOptions.uROI = [175 (nc-15)];
stereoOptions.vROI = [15 (nr-15)];
stereoOptions.Method = 'SemiGlobal';    % Much better than BlockMatching
stereoOptions.BlockSize = 15;            % (Odd integer, 5-255, default: 15)
stereoOptions.ContrastThreshold = 0.5;  % (Scalar value, 0-1, default = 0.5, disable = 1)
stereoOptions.UniquenessThreshold = 25; % (Non-negative integer, default = 15, disable = 0)
stereoOptions.DistanceThreshold = [];   % (Non-negative integer, default = disabled = [])
stereoOptions.medFilt = [5,5];
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
useApproxOffsets = false;
incOffsetApprox = 65*pi/180;
rollOffsetApprox = 0;
heaveOffsetApprox = 12;
windowLength = 45; % Seconds
numWindowsUse = inf; % Make inf to use all available windows

%% Load IMU data and offsets, video frame info, and camera calibration.
load([fileNamesDirectory '/' fileName '.mat']);
load([imuDirectory '/' fileName '.mat'])
load(calibrationFile)
if useApproxOffsets
    incOffset = incOffsetApprox;
    rollOffset = rollOffsetApprox;
    heaveOffset = heaveOffsetApprox;
else
    load([offsetsDirectory '/' fileName '.mat'])
end
% setup windows
framesPerWindow = round(windowLength*fps);
numWindows = min(floor(numFilesAligned/framesPerWindow),numWindowsUse);

%% Map lat/lon to x,y, calculate heading (azimuth) from mean heading
if correctForSurgeSwayAndHeading
    latMean = dirmean(imuDataSynced.lat);
    lonMean = dirmean(imuDataSynced.lon);
    aziMean = dirmean(imuDataSynced.azi);
    zone = utmzone([latMean,lonMean]);
    [ellipsoid,estr] = utmgeoid(zone);
    utmstruct = defaultm('utm');
    utmstruct.zone = zone;
    utmstruct.geoid = ellipsoid(1,:);
    utmstruct = defaultm(utmstruct);
    [xMean,yMean] = mfwdtran(utmstruct,latMean,lonMean);
    [x,y] = mfwdtran(utmstruct,imuDataSynced.lat,imuDataSynced.lon);
    xShip = x - xMean;
    yShip = y - yMean;
    aziShip = -(imuDataSynced.azi-aziMean)*pi/180;
end

%% For each window, load images, calculate (x,y,z), plot, and save
for j = 1:numWindows
    firstFrame = (j-1)*framesPerWindow + 1;
    lastFrame = j*framesPerWindow;
    thisMinFrames = firstFrame:lastFrame;
    
    zgrid = nan(ny,nx,framesPerWindow,'single');
    imgrid = zeros(ny,nx,framesPerWindow,'uint8');
    for i = 1:framesPerWindow           
        fprintf('Window %d of %d: Frame %d of %d\n',j,numWindows,i,framesPerWindow)
        % load images, calculate disparities and point cloud
        imageLeft = imread([imageDirectory '/' char(fileNamesAligned{leftCameraID}(thisMinFrames(j)))]);
        imageRight = imread([imageDirectory '/' char(fileNamesAligned{rightCameraID}(thisMinFrames(j)))]);
        [X,Y,Z,disparityMap,imageLeftRect] = Stereo2XYZ(imageLeft,imageRight,stereoParams,stereoOptions);
        
        % Rotate into ship or earth reference system
        if correctForSurgeSwayAndHeading
            [xRot, yRot, zRot] = World2World(X,Y,Z,imuDataSynced.inc(thisMinFrames(j))*pi/180+incOffset,...
                imuDataSynced.roll(thisMinFrames(j))*pi/180+rollOffset,aziShip(thisMinFrames(j)));
            zRot = zRot + imuDataSynced.heave(thisMinFrames(j)) + heaveOffset;
            xRot = xShip(thisMinFrames(j)) + xRot;
            yRot = yShip(thisMinFrames(j)) + yRot;
        else
            [xRot, yRot, zRot] = World2World(X,Y,Z,imuDataSynced.inc(thisMinFrames(j))*pi/180+incOffset,...
                imuDataSynced.roll(thisMinFrames(j))*pi/180+rollOffset,0);
            zRot = zRot + imuDataSynced.heave(thisMinFrames(j)) + heaveOffset;
        end
        
        % Filter out outliers and values outside of sample
        indFilt = abs(zRot) < zMax & xRot < xMax & xRot > xMin & yRot < yMax & yRot > yMin;
        if sum(indFilt(:))>100
            xRot = double(xRot(indFilt));
            yRot = double(yRot(indFilt));
            zRot = double(zRot(indFilt));
            
            % Keep raw image to plot filtering
            imageLeftFiltered = double(imageLeftRect);
            imageLeftFiltered(~indFilt) = nan;
            imageLeftDouble = double(imageLeftRect(indFilt));
            disparityMap(~indFilt) = nan;
            
            % Interpolate onto rectangular grid
            zinterp = scatteredInterpolant(xRot,yRot,zRot,'linear','none');
            zgrid(:,:,i) = single(zinterp(xgrid,ygrid));
            iminterp = scatteredInterpolant(xRot,yRot,imageLeftDouble,'linear','none');
            imgrid(:,:,i) = uint8(iminterp(xgrid,ygrid));
        else
            zgrid(:,:,i) = nan;
            imgrid(:,:,i) = 0;
        end
        
        % Make plots
        if makePlots && mod(i,plotSkip) == 0;
            %% Disparity plot
            imMin = 0;
            imMax = 255;
            dispMin = 0;
            dispMax = 176;
            f1 = figure(1);  clf(f1);
            subplot(3,1,1)
            subimage(64*(double(imageLeftRect)-imMin)/(imMax-imMin),gray);
            set(gca,'XTick',[],'YTick',[])
            title('Left Rectified Image')
            subplot(3,1,2)
            subimage(64*(imageLeftFiltered-imMin)/(imMax-imMin),gray);
            set(gca,'XTick',[],'YTick',[])
            title('Left Rectified Image')
            subplot(3,1,3)
            subimage(64*(double(disparityMap)-dispMin)/(dispMax-dispMin),parula);
            set(gca,'XTick',[],'YTick',[])
            title('Disparity')
            print(f1,'-djpeg',[disparityPlotsDirectory '/' fileName '_' sprintf('%02d',j) '_' sprintf('%03d',i) '.jpg'])
            
            %% Gridded plots
            imMin = 0;
            imMax = 255;
            zMin = -4;
            zMax = 4;
            f2 = figure(2);  clf(f2);
            subplot(2,1,1)
            subimage(xgrid(1,:),ygrid(:,1),64*(double(imgrid(:,:,i))-imMin)/(imMax-imMin),gray),
            xlabel('x [m]'),
            ylabel('y [m]'),
            subplot(2,1,2)
            subimage(xgrid(1,:),ygrid(:,1),64*(double(zgrid(:,:,i))-zMin)/(zMax-zMin),parula)
            xlabel('x [m]'),
            ylabel('y [m]'),
            title('$-4 m \leq \eta \leq 4 m$','interpreter','latex')
            print(f2,'-djpeg',[xyzPlotsDirectory '/' fileName '_' sprintf('%02d',j) '_' sprintf('%03d',i) '.jpg'])
        end
    end
    save([xyzResultsDirectory '/' fileName '.mat'],'xgrid','ygrid','zgrid','imgrid');
end
