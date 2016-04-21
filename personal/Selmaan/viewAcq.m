function [mov, mF] = viewAcq(obj)

movStruct = obj.correctedMovies.slice(1).channel(1);

nMovies = length(movStruct.fileName);
mov = nan([movStruct.size(1,1:2),nMovies]);
for nMovie = 1:nMovies
    t = meanRef(obj,nMovie);
    mov(:,:,nMovie) = imNorm(t);
    mF(nMovie) = nanmean(t(:));
end