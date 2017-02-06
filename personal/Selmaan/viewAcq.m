function [mov, mF] = viewAcq(obj,nSlice)

if ~exist('nSlice','var')
    nSlice = 1;
end

movStruct = obj.correctedMovies.slice(nSlice).channel(1);

nMovies = length(movStruct.fileName);
mov = nan([movStruct.size(1,1:2),nMovies]);
for nMovie = 1:nMovies
    t = meanRef(obj,nMovie,nSlice);
    mov(:,:,nMovie) = imNorm(t);
    mF(nMovie) = nanmean(t(:));
end