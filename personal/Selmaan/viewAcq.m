function [mov, mF] = viewAcq(obj)

movStruct = obj.correctedMovies.slice.channel;

nMovies = length(movStruct.fileName);
mov = nan([movStruct.size(1,1:2),nMovies]);
for nMovie = 1:nMovies
    t = meanRef(obj,nMovie);
    mov(:,:,nMovie) = imNorm(t);
    mF(nMovie) = nanmean(t(:));
end