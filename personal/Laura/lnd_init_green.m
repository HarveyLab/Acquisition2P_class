function lnd_init_green(acq)
    movPath = pwd;
    fileList = dir('LD*tif');
    movNames = cell(1,10*floor(size(fileList,1)/10));%cell(1,size(fileList,1));%
    for file = 1:10*floor(size(fileList,1)/10)%size(fileList,1)%
    movNames{file} = fileList(file).name;
    end
    
%Set default directory to folder location,
acq.defaultDir = movPath;

%sort movie order alphabetically for consistent results
movNames = sort(movNames);

%Attempt to automatically name acquisition from movie filename, raise
%warning and create generic name otherwise
acqNamePlace = find(movNames{1} == '_',1,'last');
try
    acq.acqName = movNames{1}(1:acqNamePlace-1);
catch
    acq.acqName = sprintf('%s_%.0f',date,now);
    warning('Automatic Name Generation Failed, using date_time')
end

%Attempt to add each selected movie to acquisition in order
for nMov = 1:length(movNames)
    acq.addMovie(fullfile(movPath,movNames{nMov}));
end

%Automatically fill in fields for motion correction
acq.motionRefMovNum = round(size(acq.Movies,2)/2);
acq.motionRefChannel = 1;
acq.binFactor = 1;
acq.motionCorrectionFunction = @withinFile_withinFrame_lucasKanade;

%Assign acquisition object to acquisition name variable in workspace
assignin('base',acq.acqName,acq);

%Notify user of success
fprintf('Successfully added %03.0f movies to acquisition: %s\n',length(movNames),acq.acqName),

% end
