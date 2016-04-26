function [beginTime,sortedFileNames] = timeFromFileNames(fileNames)

numFiles = length(fileNames);
fileNum = nan(numFiles,1);
for i = 1:numFiles
    fileNumStr = regexp(cell2mat(fileNames(i)),'(\d)*','match');
    fileNum(i) = str2double(cell2mat(fileNumStr(end)));
end
[~, sortInd] = sort(fileNum,1,'ascend');
sortedFileNames = fileNames(sortInd);
beginHourMinSec = cell2mat(fileNumStr(end-1));
beginTime = datenum(str2double(cell2mat(fileNumStr(end-4))),...
    str2double(cell2mat(fileNumStr(end-3))),...
    str2double(cell2mat(fileNumStr(end-2))),...
    str2double(beginHourMinSec(1:2)),str2double(beginHourMinSec(3:4)),...
    str2double(beginHourMinSec(5:6)));
