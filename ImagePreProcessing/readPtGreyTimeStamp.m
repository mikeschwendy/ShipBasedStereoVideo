function [binaryEmbeddedString,timestamp] = readPtGreyTimeStamp(image)

% pixels to binary string
embeddedPixels = image(1,1:40); % 10 pieces of embedded data, 4 pixels each
binaryEmbeddedPixels = dec2bin(embeddedPixels,8);  % 8 bit
binaryEmbeddedString = reshape(binaryEmbeddedPixels',[1 8*40]);
% parse embedded string
secondCountBinary = binaryEmbeddedString(1:7);
cycleCountBinary = binaryEmbeddedString(8:20);
cycleOffsetBinary = binaryEmbeddedString(21:32);
secondCountDec = bin2dec(secondCountBinary);
cycleCountDec = bin2dec(cycleCountBinary);
cycleOffsetDec = bin2dec(cycleOffsetBinary);
% calculate timestamp
timestamp = secondCountDec + (cycleCountDec + cycleOffsetDec/3072)/8000;

end

