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
    %Load movie:
    if exist('parallelIo', 'var')
        % A parallelIo object was created in a previous iteration, so we
        % can simply retrieve the pre-loaded movie:
        fprintf('\nRetrieving pre-loaded movie %1.0f of %1.0f...\n',movieOrder(m),nMovies)
        [~, mov, scanImageMetadata] = fetchNext(parallelIo);
        delete(parallelIo); % Delete data on parallel worker.
    else
        % No parallelIo exists, so this is either the first movie or
        % pre-loading is switched off, so we load the movie conventionally.
        fprintf('\nLoading movie %1.0f of %1.0f\n',movieOrder(m),nMovies)
        ticLoad = tic;
        [mov, scanImageMetadata] = obj.readRaw(movieOrder(m),'single');
        fprintf('Done loading (%1.0f s).\n', toc(ticLoad));
    end
    
    % Re-start parallel pool. This is necessary to counteract a memory leak
    % in the parallel workers (this is an issue known to MathWorks): (This
    % will not pre-maturely abort parallelIo because the fetchNext blocks
    % Matlab until the parfeval finishes.)
%     fprintf('Re-starting parallel pool to clear leaked memory:\n');
%     delete(gcp);
%     parpool;
    
    % Start parallel I/O job: This saves the movStruct from the previous
    % iteration and loads the mov for the next iteration:
    if m==1
        % First iteration: no movStruct exists yet that would have to be
        % saved:
        parallelIo = parfeval(@ioFun, 2, ...
            obj, movieOrder, m);
    else
        parallelIo = parfeval(@ioFun, 2, ...
            obj, movieOrder, m, movStruct, writeDir, namingFunction);
    end
    
    % Spatial binning:
    if obj.binFactor > 1
        mov = binSpatial(mov, obj.binFactor);
    end
    
    % Apply line shift:
    fprintf('Line Shift Correcting Movie %1.0f of %1.0f\n', movieOrder(m), nMovies),
    mov = correctLineShift(mov);
    try
        movStruct = parseScanimageTiff(mov, scanImageMetadata);
    catch
        error('parseScanimageTiff failed to parse metadata, likely non SI4 movie, modify function!'),
    end
    clear mov
    
    % Find motion:
    fprintf('Identifying Motion Correction for Movie %1.0f of %1.0f\n', movieOrder(m), nMovies),
    obj.motionCorrectionFunction(obj, movStruct, scanImageMetadata, movieOrder(m), 'identify');
    
    % Apply motion correction:
    fprintf('Applying Motion Correction for Movie %1.0f of %1.0f\n', movieOrder(m), nMovies),
    movStruct = obj.motionCorrectionFunction(obj, movStruct, scanImageMetadata, movieOrder(m), 'apply');
     
    % Save as separate tiff file for each slice\channel:
    if m==nMovies
        % Only the last movie is saved here. All other movies are saved
        % in the background, using parfeval, so that calculations can
        % proceed during slow I/O (the code for this is above, in the
        % beginning of the for-loop).
        saveMovStruct(obj, movStruct, writeDir, namingFunction, obj.acqName, m)
    end
    
    % Store movie dimensions (this is the same for all channels and
    % slices):
    obj.derivedData(movieOrder(m)).size = size(movStruct.slice(1).channel(1).mov);
end

% Clean up data on parallel workers:
wait(parallelIo);
delete(parallelIo);

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
     
function saveMovStruct(obj, movStruct, writeDir, namingFunction, acqName, movNum)
nSlices = numel(movStruct.slice);
nChannels = numel(movStruct.slice(1).channel);
for nSlice = 1:nSlices
    for nChannel = 1:nChannels
        movFileName = feval(namingFunction, acqName, nSlice, nChannel, movNum);
        
        tiffWrite(movStruct.slice(nSlice).channel(nChannel).mov, ...
            movFileName, ...
            writeDir, ...
            'int16', ...
            true);
        
        obj.correctedMovies.slice(nSlice).channel(nChannel).fileName{movNum} = ...
            fullfile(writeDir,movFileName);
    end
end
end

function [mov, siStruct] = ioFun(obj, movieOrder, m, movStruct, writeDir, namingFunction)
% [mov, siStruct] = ioFun(obj, movieOrder, m, movStruct, writeDir, namingFunction)
% This function handles thes disk input/output for one iteration of the
% motion correction loop. By executing this function with parfeval, all I/O
% can be done in the background, while

% Load movie for next iteration:
if m<numel(movieOrder)
    [mov, siStruct] = obj.readRaw(movieOrder(m+1), 'single', true);
else
    % There's nothing to be loaded if we're at the last movie in the
    % movieOrder:
    mov = [];
    siStruct = [];
end

% Stop here if there is nothing to be saved:
if m==1
    return
end

% Save movStruct from last iteration:
saveMovStruct(obj, movStruct, writeDir, namingFunction, obj.acqName, movieOrder(m-1));
end