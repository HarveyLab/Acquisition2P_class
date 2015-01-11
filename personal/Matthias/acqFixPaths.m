acq = MM052_141210_longMaze_noStim_task;

fixFunMov = @(s) strrep(s, '\Corrected\Corrected\', '\Corrected\');

% Corrected movies:
for i = 1:numel(acq.correctedMovies.slice.channel.fileName)
    acq.correctedMovies.slice.channel.fileName{i} = ...
        fixFunMov(acq.correctedMovies.slice.channel.fileName{i});
end

fixFunMeta = @(s) strrep(s, '\Corrected\', '\');

% Binary movie:
acq.indexedMovie.slice(1).channel(1).fileName = ...
    fixFunMeta(acq.indexedMovie.slice(1).channel(1).fileName);

% Covariance file:
acq.roiInfo.slice.covFile.fileName = ...
    fixFunMeta(acq.roiInfo.slice.covFile.fileName);
