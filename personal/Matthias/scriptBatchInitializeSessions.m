%{
Initialize a batch of sessions for processing using Acq2p.
%}

%% Get session list:
dirRaw = '\\research.files.med.harvard.edu\Neurobio\HarveyLab\Matthias\data\imaging\raw';
mouse = 'MM112';
snList = dir(fullfile(dirRaw, mouse, 'MM*'));
snList = snList([snList.isdir]==1);

%% Initialize:
for i = 1:numel(snList)
    try
        tiffList = dir(fullfile(dirRaw, mouse, snList(i).name, '*maIn*.tif'));
        snId = tiffList(1).name(1:end-16);
        mjlmInitialization(snId, improc.dir.jobs('orchestra'));
        if mod(numel(tiffList), 10)==0
            fprintf('%s successfully initialized with %d movies.\n', ...
                snId, numel(tiffList))
        else
            warning('%s has a strange number of movies: %d', ...
                snId, numel(tiffList))
        end
    catch err
        fprintf('Error while initializing %s:\n', snId)
        throwAsWarning(err)
    end
end
disp('Done initializing. Check command line for warnings.')