clearvars
close all
clc

%% INPUTS
inputDirectory =  './SampleData/ImuDataFiles';  % Raw data directory
outputDirectory = './SampleResults/ImuMatFiles';  % Directory for results
plotDirectory = './SampleResults/FilteredHeavePlots';  % Directory for results
% Inputs for heave filter (Highpass FIR)
Fpass = 0.05; % Passband Frequency
Fstop = 0.03; % Stopband Frequency
Ap = 1; % Passband Ripple 
Ast = 30; % Stopband Attenuation

%% Load IMU Data
imuFiles = dir([inputDirectory '/*.ASC']);
numFiles = length(imuFiles);
mkdir(outputDirectory)
mkdir(plotDirectory)
for i = 1:numFiles
    imuData = parseNovatelAsciiData([inputDirectory '/' imuFiles(i).name]);  % load data into matlab structure

    if ~isempty(imuData.timeGNSS)
        %% Filter out drift in IGM elevation data (INSPVASA data string)
        Fs = round(1/nanmean(diff(imuData.timeGNSS*24*60*60)));
        
        heaveFilter = designfilt('highpassfir', ...
            'PassbandFrequency',Fpass,'StopbandFrequency',Fstop, ...
            'PassbandRipple',Ap,'StopbandAttenuation',Ast,...
            'DesignMethod','equiripple','SampleRate',Fs);
        filterDelay = mean(grpdelay(heaveFilter));
        
        imuData.heave = filter(heaveFilter,imuData.height);
        imuData.heave = imuData.heave - mean(imuData.heave);
        if filterDelay < length(imuData.heave)
            imuData.heave(1:(end-filterDelay)) = imuData.heave((filterDelay+1):end);
            imuData.heave((end-filterDelay+1):end) = nan;
        else
            imuData.heave(1:end) = nan;
        end
        
        %% Plot to check filtered heave data      
        windowSmooth = Fs*60; % half-width
        smoothUnfilt = nan(size(imuData.heave));
        smoothFilt = nan(size(imuData.heave));
        for k = 1:length(imuData.heave)
            ind1 = max(1,k-windowSmooth);
            ind2 = min(length(imuData.heave),k+windowSmooth);
            smoothUnfilt(k) = nanmean(imuData.height(ind1:ind2)-mean(imuData.height));
            smoothFilt(k) = nanmean(imuData.heave(ind1:ind2));
        end
        
        f1 = figure(1); clf(f1);
        a1 = subplot(2,1,1);
        plot(imuData.timeGNSS,imuData.height-mean(imuData.height),'-k')
        hold on
        plot(imuData.timeGNSS,imuData.heave,'-b')
        plot(imuData.timeGNSS,smoothUnfilt,'-r','linewidth',2)
        plot(imuData.timeGNSS,smoothFilt,'-c','linewidth',2)
        a1.YLim = [-5 5];
        legend('Raw','Filtered','2-Min Moving Average','2-Min Moving Average','location','best')
        xlabel('Time (Full Record)')
        ylabel('Heave [m]')
        datetick
        xLimits = a1.XLim;
        plot(xLimits,[-0.5 -0.5],':k')
        plot(xLimits,[0.5 0.5],':k')
        hold off
        a1.XLim = xLimits;
        a2 = subplot(2,1,2);
        ind = 1:min(Fs*60*5,length(imuData.timeGNSS));
        plot(imuData.timeGNSS(ind),imuData.height(ind)-mean(imuData.height(ind)),'-k')
        hold on
        plot(imuData.timeGNSS(ind),imuData.heave(ind),'-b')
        datetick
        hold off
        a2.YLim = [-5 5];
        xlabel('Time (5 Minute Sample)')
        ylabel('Heave [m]')
        print(f1,[plotDirectory '/' imuFiles(i).name(1:(end-4)) '.jpg'],'-djpeg')
        
    else
        imuData.heave = [];
    end
    
    %% Save into mat file
    save([outputDirectory '/' imuFiles(i).name(1:(end-4)) '.mat'],'imuData')
end


