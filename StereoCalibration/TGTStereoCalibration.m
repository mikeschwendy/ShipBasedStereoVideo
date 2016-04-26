clearvars
close all
clc

% input image files
imageDirectory = '/Users/mike/Documents/UW/Research/Data/TGTCalibration/1831UTC_portcalibration';
outputDirectory = '/Users/mike/Documents/UW/Research/Data/TGTCalibration/PostCalibration_Port';
mkdir(outputDirectory)
calibrationFileName = [outputDirectory '/StereoCalibrationResults.mat'];

% Options
%squareSize = 4*25.4; % millimeters, large metal grid
%squareSize = 1.25*25.4; % millimeters, 8x11" paper grid
%squareSize = 2*25.4; % millimeters, 11x16" paper grid
squareSize = 8*25.4; % millimeters, large wooden grid
imageSkip = 25;
usePrevImages = false;
usePrevMask = false;
usePrevCalibration = false;
checkDetection = true;
checkDistortion = true;
checkRectification = true;
ncStereo = 1024;
nrStereo = 768;
%% check for previous calibration

prevFileName = calibrationFileName;
if exist(prevFileName,'file') && usePrevCalibration
    load(prevFileName)
    numImagesUsed = length(leftImageFileNames);
    usedImagesLeft = zeros(nrStereo,ncStereo,1,numImagesUsed,'uint8');
    usedImagesRight = zeros(nrStereo,ncStereo,1,numImagesUsed,'uint8');
    for i = 1:numImagesUsed
        usedImagesLeft(:,:,1,i) = imread(cell2mat(leftImageFileNames(i)));
        usedImagesRight(:,:,1,i) = imread(cell2mat(rightImageFileNames(i)));
    end
else
    if exist(prevFileName,'file') && usePrevImages
        load(prevFileName,'leftImageFileNames','rightImageFileNames');
    else
        % load frame info .mat file
        load([imageDirectory '/StereoFrameInfo_ThreeCameras.mat']);
        
        % input start and stop frame numbers (use buffer to account for left or right)
%         %%%% PostCalibration_Starboard %%%%
%         frameNumStart = [690 960 1500 2110 3210 4000 4615 5450 7000 7400 ...
%             7780 8000 8880 9760];
%         frameNumEnd = [750 1180 1970 2410 3650 4475 5300 6100 7210 7560 ...
%             7790 8500 9600 9980];
        %%%% PostCalibration_Port %%%%
        frameNumStart = [1065 1380 1555 2170 2270 2600 3190 3495 3720 4020 4270];
        frameNumEnd = [1235 1425 2055 2210 2440 3035 3390 3570 3838 4190 4400];

        %frameNumStart = 2050;
        %frameNumEnd = 5400;
        
        indLeft = [];
        indRight = [];
        indCenter = [];
        for i = 1:length(frameNumStart)
            indLeft = [indLeft; find(fileNumSyncLeft>=frameNumStart(i) & fileNumSyncLeft<=frameNumEnd(i))];
            indRight = [indRight; find(fileNumSyncRight>=frameNumStart(i) & fileNumSyncRight<=frameNumEnd(i))];
            indCenter = [indCenter; find(fileNumSyncCenter>=frameNumStart(i) & fileNumSyncCenter<=frameNumEnd(i))];
        end
        
        leftImageFileNames = fileNameLeft(indLeft);
        rightImageFileNames = fileNameRight(indRight);
        centerImageFileNames = fileNameCenter(indCenter);
    end
    
    
    if length(leftImageFileNames)~=length(rightImageFileNames);
        error('Left/right images do not match');
    else
        numImages = length(rightImageFileNames);
    end
    
    if exist(prevFileName,'file') && usePrevImages
        load(prevFileName,'leftImageMask','rightImageMask');
    else
        % define mask
        leftImageMask = ones(nrStereo,ncStereo,'uint8');
        rightImageMask = ones(nrStereo,ncStereo,'uint8');
        leftImageMask(1:100,:) = 0;
        rightImageMask(1:100,:) = 0;
    end
    
    %% load images, perform checkerboard detection
    allInds = 1:imageSkip:numImages;
    allImagesLeft = zeros(nrStereo,ncStereo,1,length(allInds),'uint8');
    allImagesRight = zeros(nrStereo,ncStereo,1,length(allInds),'uint8');
    for i = 1:length(allInds)
        leftName = char(leftImageFileNames(allInds(i)));
        rightName = char(rightImageFileNames(allInds(i)));
        allImagesLeft(:,:,1,i) = imread([imageDirectory '/' leftName]).*leftImageMask;
        allImagesRight(:,:,1,i) = imread([imageDirectory '/' rightName]).*rightImageMask;
        
    end
    
    %allImagesRight = allImagesRight(97:(end-96),129:(end-128),:,:);
    %allImagesLeft = allImagesLeft(97:(end-96),129:(end-128),:,:);
    [imagePoints, boardSize, imagesUsedInd] = detectCheckerboardPoints(allImagesLeft,allImagesRight);
    
    usedImagesLeft = allImagesLeft(:,:,:,imagesUsedInd);
    usedImagesRight = allImagesRight(:,:,:,imagesUsedInd);
    leftImageFileNames = leftImageFileNames(allInds(imagesUsedInd));
    rightImageFileNames = rightImageFileNames(allInds(imagesUsedInd));
    numImagesUsed = sum(imagesUsedInd);
    %% check detection
    
    if checkDetection
        figure(1)
        figSize = [1 1 10 4];
        set(gcf,'position',figSize,'paperposition',figSize)
        for i = 1:numImagesUsed;
            subplot(1,2,1)
            imshow(usedImagesLeft(:,:,:,i), 'InitialMagnification', 50);
            hold on;
            plot(imagePoints(:, 1, i, 1), imagePoints(:, 2, i, 1), '*-g');
            hold off
            title('Left Image')
            subplot(1,2,2)
            imshow(usedImagesRight(:,:,:,i), 'InitialMagnification', 50);
            hold on;
            plot(imagePoints(:, 1, i, 2), imagePoints(:, 2, i, 2), '*-g');
            hold off
            title('Right Image')
            print(1,'-dpng','-r300',[outputDirectory '/CheckerboardDetectionStereo_' sprintf('%04d',i) '.png'])
            pause(1)
        end
    end
    
    %% Perform calibration
    
    % Generate world coordinates of the checkerboard points.
    worldPoints = generateCheckerboardPoints(boardSize, squareSize);
    
    % Compute the stereo camera parameters.
    stereoParams = estimateCameraParameters(imagePoints, worldPoints);
    
end

%% Evaluate calibration accuracy.
figure(2)
showReprojectionErrors(stereoParams);

if checkDistortion
    figure(3)
    for i = 1:numImagesUsed;
        undistortedImage = undistortImage(usedImagesLeft(:,:,:,i),stereoParams.CameraParameters1);
        imshowpair(usedImagesLeft(:,:,:,i),undistortedImage,'montage');
        pause(1)
    end
    figure(4)
    for i = 1:numImagesUsed;
        undistortedImage = undistortImage(usedImagesRight(:,:,:,i),stereoParams.CameraParameters2);
        imshowpair(usedImagesRight(:,:,:,i),undistortedImage,'montage');
        pause(1)
    end
end

if checkRectification
    figure(5)
    for i = 1:numImagesUsed
        [rectifiedLeftImage, rectifiedRightImage] = ...
            rectifyStereoImages(usedImagesLeft(:,:,:,i), usedImagesRight(:,:,:,i), ...
            stereoParams, 'OutputView', 'valid');
        imshowpair(rectifiedLeftImage, rectifiedRightImage, 'montage');
        pause(1)
    end
end


%% save calibration results
save(calibrationFileName,'leftImageFileNames','rightImageFileNames','leftImageMask','rightImageMask','stereoParams')