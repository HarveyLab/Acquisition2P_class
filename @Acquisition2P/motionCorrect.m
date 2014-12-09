function motionCorrect(obj,writeDir,motionCorrectionFunction,namingFunction)
%Generic wrapper function for managing motion correction of an
%acquisition object
%
%motionCorrect(obj,writeDir,motionCorrectionFunction,namingFunction)
%
%writeDir is an optional argument specifying location to write motion
%   corrected data to, defaults to obj.defaultDir\Corrected
%motionCorrectionFunction is a handle to a motion correction function,
%   and is optional only if acquisition already has a function handle
%   assigned to motionCorectionFunction field. If argument is provided,
%   function handle overwrites field in acq obj.
%namingFunction is a handle to a function for naming. If empty, uses
%   default naming function which is a local function of motionCorrect.
%   All naming functions must take in the following arguments (in
%   order): obj.acqName, nSlice, nChannel, movNum.

%% Error checking and input handling
if ~exist('motionCorrectionFunction', 'var')
    motionCorrectionFunction = [];
end

if nargin < 4 || isempty(namingFunction)
    namingFunction = @defaultNamingFunction;
end

if isempty(motionCorrectionFunction) && isempty(obj.motionCorrectionFunction)
    error('Function for correction not provided as argument or specified in acquisition object');
elseif isempty(motionCorrectionFunction)
    %If no argument but field present for object, use that function
    motionCorrectionFunction = obj.motionCorrectionFunction;
else
    %If using argument provided, assign to obj field
    obj.motionCorrectionFunction = motionCorrectionFunction;
end

if isempty(obj.acqName)
    error('Acquisition Name Unspecified'),
end

if ~exist('writeDir', 'var') || isempty(writeDir) %Use Corrected in Default Directory if non specified
    if isempty(obj.defaultDir)
        error('Default Directory unspecified'),
    else
        writeDir = [obj.defaultDir filesep 'Corrected'];
    end
end

if isempty(obj.defaultDir)
    obj.defaultDir = writeDir;
end

if isempty(obj.motionRefMovNum)
    if length(obj.Movies)==1
        obj.motionRefMovNum = 1;
    else
        error('Motion Correction Reference not identified');
    end
end

%% Load movies and motion correct
%Calculate Number of movies and arrange processing order so that
%reference is first
nMovies = length(obj.Movies);
if isempty(obj.motionRefMovNum)
    obj.motionRefMovNum = floor(nMovies/2);
end
movieOrder = 1:nMovies;
movieOrder([1 obj.motionRefMovNum]) = [obj.motionRefMovNum 1];

%Load movies one at a time in order, apply correction, and save as
%split files (slice and channel)
for m = 1:nMovies
    fprintf('Free memory at start of movie %d: %1.0f MB.\n', m, getFreeMem);
    
    %Load movie:
    if m==1
        % Load first movie conventionally:
        fprintf('\nLoading Movie #%03.0f of #%03.0f\n',movieOrder(m),nMovies)
        distTimer = tic;
        [mov, scanImageMetadata] = obj.readRaw(movieOrder(m),'single');
        fprintf('Done loading (%1.0f s).\n', toc(distTimer));
    else
        if exist('parObjRead', 'var')
            % Following movies: Retrieve movie that was loaded in parallel:
            fprintf('\nRetrieving pre-loaded movie #%03.0f of #%03.0f\n',movieOrder(m),nMovies)
            [mov, scanImageMetadata] = fetchOutputs(parObjRead);
            delete(parObjRead); % Necessary to delete data on parallel worker.
        else
            fprintf('\nLoading Movie #%03.0f of #%03.0f\n',movieOrder(m),nMovies)
            [mov, scanImageMetadata] = obj.readRaw(movieOrder(m),'single');
        end
    end
    
    % Start parallel loading of next movie:
    if m<nMovies && getFreeMem > 3000
        % Start loading on parallel worker:
        isSilent = true;
        parObjRead = parfeval(@obj.readRaw, 2, movieOrder(m+1), 'single', isSilent);
    end
    
    % Spatial binning:
    if obj.binFactor > 1
        mov = binSpatial(mov, obj.binFactor);
    end
    
    % Apply line shift:
    fprintf('Line Shift Correcting Movie #%03.0f of #%03.0f\n', movieOrder(m), nMovies),
    mov = correctLineShift(mov);
    try
        [movStruct, nSlices, nChannels] = parseScanimageTiff(mov, scanImageMetadata);
    catch
        error('parseScanimageTiff failed to parse metadata, likely non SI4 movie, modify function!'),
    end
    clear mov
    
    % Find motion:
    fprintf('Identifying Motion Correction for Movie #%03.0f of #%03.0f\n', movieOrder(m), nMovies),
    obj.motionCorrectionFunction(obj, movStruct, scanImageMetadata, movieOrder(m), 'identify');
    
    % Apply motion correction and write separate file for each
    % slice\channel:
    fprintf('Applying Motion Correction for Movie #%03.0f of #%03.0f\n', movieOrder(m), nMovies),
    movStruct = obj.motionCorrectionFunction(obj, movStruct, scanImageMetadata, movieOrder(m), 'apply');
    for nSlice = 1:nSlices
        for nChannel = 1:nChannels
            movFileName = feval(namingFunction,obj.acqName, nSlice, nChannel, movieOrder(m));
            obj.correctedMovies.slice(nSlice).channel(nChannel).fileName{movieOrder(m)} = fullfile(writeDir,movFileName);
            fprintf('Writing Movie #%03.0f of #%03.0f\n',movieOrder(m),nMovies)
            
            if exist('parObjWrite', 'var')
                wait(parObjWrite); % Make sure it's not deleated before it's done.
                delete(parObjWrite);
            end
            
            parObjWrite = parfeval(@tiffWrite, 0, ...
                movStruct.slice(nSlice).channel(nChannel).mov, ...
                movFileName, ...
                writeDir, ...
                'int16', ...
                isSilent);
            
            if getFreeMem < 3000
                disp('Too little free memory...waiting for write.')
                wait(parObjWrite); % Make sure it's not deleated before it's done.
                delete(parObjWrite);
            end
            
        end
    end
    
    % Store movie dimensions (this is the same for all channels and
    % slices):
    obj.derivedData(movieOrder(m)).size = size(movStruct.slice(nSlice).channel(nChannel).mov);
end

% Clean up data on parallel workers:
delete(parObjWrite)

%Assign acquisition to a variable with its own name, and write to same
%directory
eval([obj.acqName ' = obj;']),
save(fullfile(obj.defaultDir, obj.acqName), obj.acqName)
display('Motion Correction Completed!')

end

function movFileName = defaultNamingFunction(acqName, nSlice, nChannel, movNum)

movFileName = sprintf('%s_Slice%02.0f_Channel%02.0f_File%03.0f.tif',...
    acqName, nSlice, nChannel, movNum);
end

function free = getFreeMem
%MONITOR_MEMORY grabs the memory usage from the feature('memstats')
%function and returns the amount (1) in use, (2) free, and (3) the largest
%contiguous block.

memtmp = regexp(evalc('feature(''memstats'')'),'(\w*) MB','match'); 
memtmp = sscanf([memtmp{:}],'%f MB');
% in_use = memtmp(1);
free = memtmp(2);
% largest_block = memtmp(10);
end