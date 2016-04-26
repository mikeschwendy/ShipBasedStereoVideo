function data = parseNovatelAsciiData(fileName)

fid = fopen(fileName);
ind = 0;
leapSecs = nan;
data = struct('lat',[],'lon',[],'height',[],'roll',[],'pitch',[],...
    'azimuth',[],'timeUTC',[],'timeGNSS',[],'startTime',[],'endTime',[]);
while true
    tline = fgetl(fid); 
    if ~ischar(tline)
        break
    end % from fgetl help file, end while loop if error or at end of file 
    if strcmp(tline(1:6),'#TIMEA') % get GNSS conversion to UTC (number of leap second of lag)
        headerSplit = regexp(tline,';','split');  % header and message are split by semicolon
        header = headerSplit{1}; message = headerSplit{2};
        messageFields = regexp(message,',','split');  % split message into fields by commas
        headerFields = regexp(header,',','split');  % split header into fields by commas
        weekGNSS = str2double(headerFields{6}); % GNSS week, (num weeks since night of Jan 5, 1980, midnight)
        secondsGNSS = str2double(headerFields{7}); % seconds from week start (0 to 604799)
        leapSecs = str2double(messageFields{4}); % number of seconds that GNSS leads UTC due to leap seconds (negative number)
        yearUTC = str2double(messageFields{5});
        monthUTC = str2double(messageFields{6});
        dayUTC = str2double(messageFields{7});
        hourUTC = str2double(messageFields{8});
        minuteUTC = str2double(messageFields{9});
        secondsUTC = str2double(messageFields{10})/1000; % ms to seconds
        dateNumGNSS = datenum(1980,1,6,0,0,0) + datenum(0,0,7*weekGNSS,0,0,0) + datenum(0,0,0,0,0,secondsGNSS+leapSecs);
        dateNumUTC = datenum(yearUTC,monthUTC,dayUTC,hourUTC,minuteUTC,secondsUTC);
        if dateNumGNSS~=dateNumUTC  % should give same answer for UTC time
            error('Time string is not to be trusted')
        end
    end
    if strcmp(tline(1:9),'%INSPVASA') 
        ind = ind+1;
        headerSplit = regexp(tline,';','split');  % header and message are split by semicolon
        message = headerSplit{2};
        fields = regexp(message,',','split');  % split message into fields by commas
        week = str2double(fields{1}); % GNSS week, (num weeks since night of Jan 5, 1980, midnight)
        seconds = str2double(fields{2}); % seconds from week start (0 to 604799)
        data.lat(ind) = str2double(fields{3}); % degrees, wgs84
        data.lon(ind) = str2double(fields{4}); % degrees, wgs84
        data.height(ind) = str2double(fields{5}); % ellipsoidal height, wgs84, m
        data.roll(ind) = str2double(fields{9}); % right-handed rotation from local level around y-axis in degrees
        data.pitch(ind) = str2double(fields{10}); % right-handed rotation from local level around x-axis in degrees
        data.azimuth(ind) = str2double(fields{11}); % left-handed rotation around z-axis in degrees clockwise from north
        data.timeGNSS(ind) = datenum(1980,1,6,0,0,0) + datenum(0,0,7*week,0,0,0) + datenum(0,0,0,0,0,seconds);
        data.timeUTC(ind) = datenum(1980,1,6,0,0,0) + datenum(0,0,7*week,0,0,0) + datenum(0,0,0,0,0,seconds+leapSecs);
    end
end
data.startTime = min(data.timeGNSS);
data.endTime = max(data.timeGNSS);
fclose(fid);
