clc
clearvars
close all

%% INPUTS
fileName = '28Dec2014_1930UTC';
cameraID = 3; % choose camera to use for horizon
imageDirectory =  './SampleData/ImageFiles';  % Image directory
outputDirectory = './SampleResults';  % Directory for results;
calibrationFile = [outputDirectory '/CameraCalibrationResults/CalibrationResults_stbd_center.mat']; % Horizon Camera
imuDirectory = [outputDirectory '/ImuMatFiles'];
fileNamesDirectory = [outputDirectory '/AlignedStereoFileNames'];
plotDirectoryImu = [outputDirectory '/ImuDataPlots']; mkdir(plotDirectoryImu);
plotDirectorySync = [outputDirectory '/ImuHorizonComparisonPlots']; mkdir(plotDirectorySync);
outputDirectorySync = [outputDirectory '/SyncedImuData']; mkdir(outputDirectorySync);
imuCameraOppositeSide = false;
syncDuration = 45; % seconds
syncWindows = 1; % for averaging
maxLagExpected = 2; % seconds
horizonOptions.Cols = [200 1080]; % set options for horizon-finding
horizonOptions.Rows = [1 480];
horizonOptions.Method = 'canny';
horizonOptions.IncRange = pi/180*[72 82];
horizonOptions.RollRange = pi/180*[-6 6];
horizonOptions.MinScore = 0;

%% Load stereo frame info

load([fileNamesDirectory '/' fileName '.mat'],'fileNamesAligned','numFilesAligned','beginTimeAligned','fps');
cameraTimeOffset = beginTimeAligned+(1/(24*60*60))*(1/fps)*(0:(numFilesAligned-1));
cameraBeginTime = beginTimeAligned;
cameraEndTime = max(cameraTimeOffset);
load(calibrationFile)

%% Load IMU files, interpolate data to camera frames (slightly offset)
imuDataOffset = struct('inc',nan(1,numFilesAligned),'roll',nan(1,numFilesAligned),...
    'azi',nan(1,numFilesAligned),'lat',nan(1,numFilesAligned),...
    'lon',nan(1,numFilesAligned),'heave',nan(1,numFilesAligned));
imuFiles = dir([imuDirectory '/*.mat']);
numImuFiles = length(imuFiles);
for j = 1:numImuFiles
    load([imuDirectory '/' imuFiles(j).name])
    if ~isempty(imuData.startTime) && imuData.endTime > cameraBeginTime && imuData.startTime < cameraEndTime
        aziI = interp1(imuData.timeGNSS,imuData.azimuth,cameraTimeOffset,'linear',nan);
        latI = interp1(imuData.timeGNSS,imuData.lat,cameraTimeOffset,'linear',nan);
        lonI = interp1(imuData.timeGNSS,imuData.lon,cameraTimeOffset,'linear',nan);
        heaveI = interp1(imuData.timeGNSS,imuData.heave,cameraTimeOffset,'linear',nan);
        if imuCameraOppositeSide
            incI = interp1(imuData.timeGNSS,-imuData.roll,cameraTimeOffset,'linear',nan);
            rollI = interp1(imuData.timeGNSS,-imuData.pitch,cameraTimeOffset,'linear',nan);
        else
            incI = interp1(imuData.timeGNSS,imuData.roll,cameraTimeOffset,'linear',nan);
            rollI = interp1(imuData.timeGNSS,imuData.pitch,cameraTimeOffset,'linear',nan);
        end
        % Add to nans
        imuDataOffset.inc = nansum([imuDataOffset.inc; incI]);
        imuDataOffset.roll = nansum([imuDataOffset.roll; rollI]);
        imuDataOffset.azi = nansum([imuDataOffset.azi; aziI]);
        imuDataOffset.lat = nansum([imuDataOffset.lat; latI]);
        imuDataOffset.lon = nansum([imuDataOffset.lon; lonI]);
        imuDataOffset.heave = nansum([imuDataOffset.heave; heaveI]);
    end
end

%% Print all IMU data coinciding with this video
f1 = figure(1);
subplot(6,1,1), plot(cameraTimeOffset,imuDataOffset.inc), datetick, ylabel('Incidence')
subplot(6,1,2), plot(cameraTimeOffset,imuDataOffset.roll), datetick, ylabel('Roll')
subplot(6,1,3), plot(cameraTimeOffset,imuDataOffset.azi), datetick, ylabel('Azimuth')
subplot(6,1,4), plot(cameraTimeOffset,imuDataOffset.lat), datetick, ylabel('Latitude')
subplot(6,1,5), plot(cameraTimeOffset,imuDataOffset.lon), datetick, ylabel('Longitude')
subplot(6,1,6), plot(cameraTimeOffset,imuDataOffset.heave), datetick, ylabel('Heave')
xlabel('Time')
print(f1,[plotDirectoryImu '/' fileName '.jpg'],'-djpeg','-r300')

%% Calculate Camera Orientation From Horizon
windowFrames = round(syncDuration*fps);
lag = nan(syncWindows,1);
for j = 1:syncWindows
    frameNumStart = randi([1,numFilesAligned - windowFrames + 1],1);
    frameNumEnd = frameNumStart + windowFrames - 1;
    frameNums = frameNumStart:frameNumEnd;
    cameraTimeWindow = cameraTimeOffset(frameNumStart:frameNumEnd);
    
    % load horizon images
    image1 = imread([imageDirectory '/' char(fileNamesAligned{cameraID}(frameNums(1)))]);
    [nr,nc] = size(image1);
    horizonImages = nan(nr,nc,windowFrames);
    horizonImages(:,:,1) = image1;
    for k = 2:windowFrames
        horizonImages(:,:,k) = imread([imageDirectory '/' char(fileNamesAligned{cameraID}(frameNums(k)))]);
    end
    % calculate angles from horizon
    [incHorizon,rollHorizon,flag] = cameraAnglesFromHorizon(horizonImages,cameraParams,horizonOptions);
    incHorizon = incHorizon*180/pi;
    rollHorizon = rollHorizon*180/pi;
    
    % imu angles
    incImuWindow = imuDataOffset.inc(frameNumStart:frameNumEnd);
    rollImuWindow = imuDataOffset.roll(frameNumStart:frameNumEnd);
    
    % find offset in roll and pitch between center camera and IGM
    incImuMed = nanmedian(incImuWindow);
    rollImuMed = nanmedian(rollImuWindow);
    incHorMed = nanmedian(incHorizon);
    rollHorMed = nanmedian(rollHorizon);
    
    % max correlation of horizon and imu incidence to get time lag
    [C,lagVec] = xcorr(incImuWindow-incImuMed,incHorizon-incHorMed,round(maxLagExpected*fps));
    [~,lagInd] = max(C);
    lag(j) = lagVec(lagInd);
    if abs(lag(j))==round(maxLagExpected*fps)
        warning('Cross-correlation may not be finding the correct lag')
    end
    
    %% Plot synchronized data using horizon and IMU angles
    f2 = figure(2); clf(f2);
    subplot(2,1,1); plot(cameraTimeWindow,incImuWindow-incImuMed,'-b')
    hold('on')
    plot(cameraTimeWindow,incHorizon-incHorMed,'-k')
    plot(cameraTimeWindow + datenum(0,0,0,0,0,lag(j)/fps),incHorizon-incHorMed,'-r')
    hold('off')
    datetick
    ylabel('Pitch [deg]')
    title(['Lag = ', sprintf('%02d',lag(j))])
    legend('IMU','Horizon','Horizon Corrected')
    subplot(2,1,2);
    plot(cameraTimeWindow,rollImuWindow-rollImuMed,'-b')
    hold('on')
    plot(cameraTimeWindow,rollHorizon-rollHorMed,'-k')
    plot(cameraTimeWindow + datenum(0,0,0,0,0,lag(j)/fps),rollHorizon-rollHorMed,'-r')
    hold('off')
    datetick
    ylabel('Roll [deg]')
    legend('IMU','Horizon','Horizon Corrected')
    xlabel('Time')
    print(f2,[plotDirectorySync '/' fileName '_' sprintf('%d',j) '.jpg'],'-djpeg','-r300')
end
% Take correct lag as median of all windows
medLag = nanmedian(lag);

%% Interpolate IMU data to camera frames (offset removed)
cameraTimeSynced = cameraTimeOffset + datenum(0,0,0,0,0,medLag/fps);
cameraStartTime = min(cameraTimeSynced);
cameraEndTime = max(cameraTimeSynced);
imuDataSynced = struct('inc',nan(1,numFilesAligned),'roll',nan(1,numFilesAligned),...
    'azi',nan(1,numFilesAligned),'lat',nan(1,numFilesAligned),...
    'lon',nan(1,numFilesAligned),'heave',nan(1,numFilesAligned));
imuFiles = dir([imuDirectory '/*.mat']);
numImuFiles = length(imuFiles);
for j = 1:numImuFiles
    load([imuDirectory '/' imuFiles(j).name])
    if ~isempty(imuData.startTime) && imuData.endTime > cameraBeginTime && imuData.startTime < cameraEndTime
        aziI = interp1(imuData.timeGNSS,imuData.azimuth,cameraTimeSynced,'linear',nan);
        latI = interp1(imuData.timeGNSS,imuData.lat,cameraTimeSynced,'linear',nan);
        lonI = interp1(imuData.timeGNSS,imuData.lon,cameraTimeSynced,'linear',nan);
        heaveI = interp1(imuData.timeGNSS,imuData.heave,cameraTimeSynced,'linear',nan);
        if imuCameraOppositeSide
            incI = interp1(imuData.timeGNSS,-imuData.roll,cameraTimeSynced,'linear',nan);
            rollI = interp1(imuData.timeGNSS,-imuData.pitch,cameraTimeSynced,'linear',nan);
        else
            incI = interp1(imuData.timeGNSS,imuData.roll,cameraTimeSynced,'linear',nan);
            rollI = interp1(imuData.timeGNSS,imuData.pitch,cameraTimeSynced,'linear',nan);
        end
        % Add to nans
        imuDataSynced.inc = nansum([imuDataSynced.inc; incI]);
        imuDataSynced.roll = nansum([imuDataSynced.roll; rollI]);
        imuDataSynced.azi = nansum([imuDataSynced.azi; aziI]);
        imuDataSynced.lat = nansum([imuDataSynced.lat; latI]);
        imuDataSynced.lon = nansum([imuDataSynced.lon; lonI]);
        imuDataSynced.heave = nansum([imuDataSynced.heave; heaveI]);
    end
end
imuDataSynced.time = cameraTimeSynced;

% save new dataset
save([outputDirectorySync '/'  fileName '.mat'],'imuDataSynced')



