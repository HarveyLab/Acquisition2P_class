function [mov, mF] = viewAcq(obj,nSlice,nChannel)

if ~exist('nSlice','var') || isempty(nSlice)
    nSlice = 1;
end

if ~exist('nChannel','var') || isempty(nChannel)
    nChannel = 1;
end

movStruct = obj.correctedMovies.slice(nSlice).channel(nChannel);

nMovies = length(movStruct.fileName);
mov = nan([movStruct.size(1,1:2),nMovies]);
for nMovie = 1:nMovies
    t = meanRef(obj,nMovie,nSlice,nChannel);
    mov(:,:,nMovie) = imNorm(t);
    mF(nMovie) = nanmean(t(:));
end

end

function normImage = imNorm(rawImage)

rawImage = double(rawImage);
normImage = imadjust(rawImage/max(rawImage(:)));
end