function movStruct = withinFile_withinFrame_lucasKanade(...
    obj, movStruct, scanImageMetadata, movNum, opMode)
% movStruct = withinFile_withinFrame_lucasKanade(obj, movStruct, scanImageMetadata, movNum, opMode)
% finds/corrects in-frame motion with an algorithm that takes into account
% that images are acquired by raster scanning (Greenberg and Kerr, 2009)

nSlice = numel(movStruct.slice);
nChannel = numel(movStruct.slice(1).channel);
isGpu = gpuDeviceCount>0;
if isGpu
    gpu = gpuDevice;
    pctRunOnAll reset(gpuDevice);
    wait(gpu)
    memAvailable = gpu.AvailableMemory;
end

switch opMode
    case 'identify'
        refCh = obj.motionRefChannel;
        for iSl = 1:nSlice
            [h, w, z] = size(double(movStruct.slice(iSl).channel(refCh).mov));
            
            % First, find within-movie displacements:
            ref = mean(single(movStruct.slice(iSl).channel(refCh).mov), 3);
            [movTemp, dpx, dpy, basisFunctions] = ...
                doLucasKanadeSPMD(single(movStruct.slice(iSl).channel(refCh).mov), ref);
                        
            % Second, find global displacement with respect to reference
            % image:
            if movNum == refCh
                xGlobal = 0;
                yGlobal = 0;
                obj.motionRefImage.slice(iSl).img = nanmedian(movTemp, 3);
            else
                medianThis = nanmedian(movTemp, 3);
                [xGlobal, yGlobal] = track_subpixel_wholeframe_motion_fft_forloop(...
                    medianThis, ...
                    obj.motionRefImage.slice(iSl).img);
            end
            
            % Third, combine local and global shifts and store them as
            % displacement fields. A displacement field specifies how each
            % pixel is shifted in each dimension.
            lineShiftX = zeros(h, z);
            lineShiftY = zeros(h, z);
            for f = 1:z
                lineShiftX(:, f) = basisFunctions*dpx(:, f) - xGlobal;
                lineShiftY(:, f) = basisFunctions*dpy(:, f) - yGlobal;
            end
            
            % The motion correction algorithm calculates a rigid shift for
            % each line (because lines are scanned fast, so there is
            % probably no shift within a line). The displacement field for
            % the entrie frame is created by expanding the line shifts
            % across the entire frame (as if multiplying them with a
            % meshgrid). However, saving them in full matrices would
            % require as much space as the movie itself. Therefore, we
            % simply save them as anonymous functions that calculate the
            % full matrix on demand. This works because anonymous function
            % handles contain all the data that is present in the workspace
            % in which they were created. The functions are evaluated by
            % using empty parentheses, like this: fullMatrix = Dx(). Such
            % empty parentheses are also allowed after normal numeric
            % matrices. So to write a function that can deal with both
            % matrix and functional inputs, we can simply add () after the
            % relevant variables.
            
            % These functions take the height-by-1 lineShift arrays and
            % expand them along the width and nFrames-dimensions. At the
            % same time, they add values corresponding to the
            % grid-positions of each pixel (same as if we created grid
            % matrixes with MESHGRID, but more efficient).
            obj.shifts(movNum).slice(iSl).x = createDispFieldFunctionX(w, lineShiftX);
            obj.shifts(movNum).slice(iSl).y = createDispFieldFunctionY(w, h, lineShiftY);
        end
        
    case 'apply'
        for iSl = 1:nSlice
            for iCh = 1:nChannel
                z = size(movStruct.slice(iSl).channel(iCh).mov, 3);
                
                % Get full displacement fields:
                Dx = obj.shifts(movNum).slice(iSl).x();
                Dy = obj.shifts(movNum).slice(iSl).y();
                
                % This for-loop is faster than using interpn without a
                % loop, both on the CPU and the GPU. Re-evaluate this if we
                % have a GPU that can fit an entire movie into RAM.
                for f = 1:z
                    movStruct.slice(iSl).channel(iCh).mov(:,:,f) = ...
                        interp2(...
                            movStruct.slice(iSl).channel(iCh).mov(:,:,f), ...
                            Dx(:,:,f), ...
                            Dy(:,:,f), ...
                            'linear');
                end
            end
            obj.derivedData(movNum).meanRef.slice(iSl).channel(iCh).img = ...
                mean(movStruct.slice(iSl).channel(iCh).mov,3);
        end
end

% The following two functions create and return the function handles that
% calculate displacement fields on-demand. The handles are created in
% separate functions, rather than in the main function, because the handles
% will contain copies of the entire workspace of their parent function,
% even including variables that are not used by the anonymous function. By
% putting them into separate functions, we can isolate them from all the
% larger movie-related variables that are in the workspace of the main
% function:
function fn = createDispFieldFunctionX(w, lineShiftX)
fn = @() bsxfun(@plus, 1:w, permute(lineShiftX, [1, 3, 2]));
function fn = createDispFieldFunctionY(w, h, lineShiftY)
fn = @() bsxfun(@plus, zeros(1, w), permute(bsxfun(@plus, (1:h)', lineShiftY), [1, 3, 2]));

function [mov, dpx, dpy, B] = correctMotionLucasKanadeLoop(mov, refImg)

if ~exist('refImg', 'var')
    refImg = mean(mov, 3);
end

z = size(mov, 3);

% Sub-pixel correction including within-frame motion:
nBasis = 16;
dpx = zeros(nBasis+1, z);
dpy = zeros(nBasis+1, z);
for f = 1:z
    f
    % Do warping using Lucas-Kanade:
    [mov(:,:,f), dpx(:, f), dpy(:, f)] = doLucasKanade(refImg, mov(:,:,f));
end

% Get basis functions for manual correction:
[~, ~, ~, B] = doLucasKanade(refImg, mov(:,:,1));