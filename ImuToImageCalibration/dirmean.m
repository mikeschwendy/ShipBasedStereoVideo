function meanVal = dirmean(vect,varargin)
% Like nanmean, for component-wise mean of directional vector (in degrees)
if nargin == 3
    dim = varargin{2};
    if ~isempty(varargin{1})
        weights = varargin{1};
    else
        weights = ones(size(vect));
    end
elseif nargin == 2
    weights = varargin{1};
    dim = [];
else
    weights = ones(size(vect));
    dim = [];
end
if min(vect(:))>-2*pi && max(vect(:))<2*pi
    warning('Input to dirmean might be in radians.  dirmean expects angles in degrees')
end

if isempty(dim)
    xComp = nanmean(weights.*cos(pi/180*vect));
    yComp = nanmean(weights.*sin(pi/180*vect));
else
    xComp = nanmean(weights.*cos(pi/180*vect),dim);
    yComp = nanmean(weights.*sin(pi/180*vect),dim);
end
meanVal = 180/pi*atan2(yComp,xComp);