clearvars
close all
clc

% input image files
imageDirectory = '/Users/mike/Documents/UW/Research/Data/TGTCalibration/15Jan2015/1834UTC_flea18';
outputDirectory = '/Users/mike/Documents/UW/Research/Data/TGTCalibration/IndividualCalibration';
mkdir(outputDirectory)

side = 'stbd';
camera = 'left';
if strcmp(side,'port')
    if strcmp(camera,'left')
        cameraName = 'flea35';
    elseif strcmp(camera,'right')
        cameraName = 'flea34';
    else
        cameraName = 'flea65';
    end
else
    if strcmp(camera,'left')
        cameraName = 'flea18';
    elseif strcmp(camera,'right')
        cameraName = 'flea21';
    else
        cameraName = 'flea83';
    end
end
calibrationFileName = [outputDirectory '/CalibrationResults_' side '_' camera '.mat'];

if strcmp(camera,'center')
    squareSize = 2*25.4; % millimeters, 11x16" paper grid
else
    squareSize = 1*25.4; % millimeters, 8x11" paper grid
end

imageSkip = 10;  % 
usePrevImages = false;
usePrevMask = false;
checkDetection = true;
checkDistortion = true;
ncStereo = 1024;
nrStereo = 768;
ncCenter = 1280;
nrCenter = 960;
%% check for previous calibration
prevFileName = calibrationFileName;
if exist(prevFileName,'file') && usePrevImages
    load(prevFileName,'imageFileNames');
else
    imageFileNames = regexpdir(imageDirectory,['(' cameraName ')+(.)*(.pgm)$']);
end

if exist(prevFileName,'file') && usePrevImages
    load(prevFileName,'imageMask');
else
    if strcmp(camera,'center')
        % define mask
        imageMask = ones(nrCenter,ncCenter,'uint8');
    else
        imageMask = ones(nrStereo,ncStereo,'uint8');
    end
    
end

%% load images, perform checkerboard detection

numImages = length(imageFileNames);

allInds = 1:imageSkip:numImages;
for i = 1:length(allInds)
    %allImages(:,:,1,i) = rgb2gray(imread(cell2mat(imageFileNames(allInds(i)))));
    %allImages(:,:,1,ind) = imadjust(allImages(:,:,1,ind),[0; 50/255],[0; 1]);
    allImages(:,:,1,i) = imread(cell2mat(imageFileNames(allInds(i))));
end

%allImages = allImages.*repmat(imageMask,[1 1 1 length(allInds)]);

[imagePoints, boardSize, imagesUsedInd] = detectCheckerboardPoints(allImages);

usedImages = allImages(:,:,:,imagesUsedInd);
imageFileNames = imageFileNames(allInds(imagesUsedInd));
numImagesUsed = sum(imagesUsedInd);
%% check detection

if checkDetection
    figure(1)
    for i = 1:numImagesUsed;
        imshow(usedImages(:,:,:,i), 'InitialMagnification', 50);
        hold on;
        plot(imagePoints(:, 1, i, 1), imagePoints(:, 2, i, 1), '*-g');
        pause(1)
        hold off
    end
end

%% Perform calibration

% Generate world coordinates of the checkerboard points.
worldPoints = generateCheckerboardPoints(boardSize, squareSize);

% Compute the stereo camera parameters.
cameraParams = estimateCameraParameters(imagePoints, worldPoints, 'NumRadialDistortionCoefficients', 2, 'EstimateTangentialDistortion', false,'EstimateSkew',false);

% Evaluate calibration accuracy.
figure(2)
showReprojectionErrors(cameraParams);

if checkDistortion
    figure(3)
    for i = 1:numImagesUsed;
        undistortedImage = undistortImage(usedImages(:,:,:,i),cameraParams);
        imshowpair(usedImages(:,:,:,i),undistortedImage,'montage');
        pause(1)
    end
end

%% save calibration results
save(calibrationFileName,'imageFileNames','imageMask','cameraParams')