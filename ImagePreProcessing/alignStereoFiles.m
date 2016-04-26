clc
clearvars
close all

%% INPUTS
imageDirectory =  './SampleData/ImageFiles';  % Image directory
outputDirectory = './SampleResults/';  % Directory for results
useImageNum = 300;  % number of images to use for aligning images 
cameraNum = 3; % number of cameras to align
imageString{1} = 'flea18';  % Identifying string for Camera 1 images
imageString{2} = 'flea21';  % Camera 2 
imageString{3} = 'flea83';  % Camera 3
fileNamesDirectory = [outputDirectory '/AlignedStereoFileNames'];
mkdir(fileNamesDirectory)
%% Find image files
imageFiles = cell(cameraNum,1);
for i = 1:cameraNum
    d = dir([imageDirectory '/' imageString{i} '*']);
    imageFiles{i} = {d.name};
    if isempty(imageFiles{i})
        error 'Input Files Not Found';
    end
end

%% Find approximate time from filenames
beginTime = nan(cameraNum,1);
fileNamesSorted = cell(cameraNum,1);
for i = 1:cameraNum
    [beginTime(i),fileNamesSorted{i}] = timeFromFileNames(imageFiles{i});
end

%% Parse embedded data from images
% check that numImages is less than the number of files
totalImages = nan(cameraNum,1);
for i = 1:cameraNum
    totalImages(i) = length(imageFiles{i}); 
end
numImages = min(useImageNum,min(totalImages));
timestamp = nan(cameraNum,numImages);
for i = 1:cameraNum
    embeddedBinaryString = false(numImages,8*40);
    for j = 1:numImages
        fprintf('Camera %d, Reading Image %d of %d\n',i,j,numImages)
        frame = imread([imageDirectory '/' char(imageFiles{i}(j))],'pgm');
        [~, timestamp(i,j)] = readPtGreyTimeStamp(frame);
    end
end

%% Find framerate and frame offset
dt = diff(timestamp(1,:));
fps = 1/mean(dt(abs(dt)<5));
offset = nan(cameraNum,1);
for i = 1:cameraNum
   timeDiff = timestamp(i,:) - timestamp(1,:);
   offset(i) = round(mean(timeDiff(abs(timeDiff)<60))*fps);
end

%% find indices of overlapping frames
firstFrame = max(offset) - offset + 1;
beginTimeAligned = beginTime(1) + datenum(0,0,0,0,0,firstFrame(1)/fps);
fileIndAligned = cell(cameraNum,1); 
numInd = nan(cameraNum,1);
for i = 1:cameraNum
    fileIndAligned{i} = firstFrame(i):totalImages(i);
    numInd(i) = length(fileIndAligned{i});
end
numFilesAligned = min(numInd);
for i = 1:cameraNum
    fileIndAligned{i} = fileIndAligned{i}(1:numFilesAligned);
end

%% Plot timestamps, check errors
timeError = nan(cameraNum,numFilesAligned);
f1 = figure(1); clf(f1);
hold('on')
for i = 1:cameraNum
    plot(timestamp(i,fileIndAligned{i}))
    timeError(i,:) = timestamp(i,fileIndAligned{i}) - timestamp(1,fileIndAligned{1});
end
hold('off')
xlabel('Aligned File Index')
ylabel('Timestamp')

maxError= max(timeError(:));

if maxError > 1/(fps/2)
    error('Alignment failed: Possible dropped frames, or other issue');
else
    fprintf('Aligned %d  Images\n',numFilesAligned)
end

%% Save aligned filenames 
fileNamesAligned = cell(cameraNum,1);
for i = 1:cameraNum
    fileNamesAligned{i} = fileNamesSorted{i}(fileIndAligned{i});
end

save([fileNamesDirectory '/' datestr(beginTimeAligned,'ddmmmyyyy_HHMMUTC') '.mat'],...
    'fileNamesAligned','numFilesAligned','beginTimeAligned','fps')
