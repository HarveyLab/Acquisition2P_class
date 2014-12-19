function movStruct = withinFile_withinFrame_lucasKanade(...
    obj, movStruct, ~, movNum, opMode)
% movStruct = withinFile_withinFrame_lucasKanade(obj, movStruct, scanImageMetadata, movNum, opMode)
% finds/corrects in-frame motion with an algorithm that takes into account
% that images are acquired by raster scanning (Greenberg and Kerr, 2009)

nSlice = numel(movStruct.slice);
nChannel = numel(movStruct.slice(1).channel);
isGpu = gpuDeviceCount>0;
if isGpu
    gpu = gpuDevice;
    reset(gpuDevice);
    wait(gpu)
end

switch opMode
    case 'identify'
        refCh = obj.motionRefChannel;
        refMov = obj.motionRefMovNum;
        for iSl = 1:nSlice
            [h, w, z] = size(double(movStruct.slice(iSl).channel(refCh).mov));
            
            % First, find within-movie displacements:
            ref = mean(single(movStruct.slice(iSl).channel(refCh).mov), 3);
            [movTemp, dpx, dpy, basisFunctions] = ...
                doLucasKanadeParfeval(single(movStruct.slice(iSl).channel(refCh).mov), ref);
                        
            % Second, find global displacement with respect to reference
            % image:
            if movNum == refMov
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
            % THIS IS NOW DONE IN THE FUNCTIONS BELOW TO SAVE STORAGE SPACE.
%             lineShiftX = zeros(h, z);
%             lineShiftY = zeros(h, z);
%             for f = 1:z
%                 lineShiftX(:, f) = basisFunctions*dpx(:, f) - xGlobal;
%                 lineShiftY(:, f) = basisFunctions*dpy(:, f) - yGlobal;
%             end
            
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
            obj.shifts(movNum).slice(iSl).x = createDispFieldFunctionX(h, w, z, basisFunctions, dpx, xGlobal);
            obj.shifts(movNum).slice(iSl).y = createDispFieldFunctionY(h, w, z, basisFunctions, dpy, yGlobal);
        end
        
    case 'apply'
        for iSl = 1:nSlice
            z = size(movStruct.slice(iSl).channel(1).mov, 3);
            
            % Get full displacement fields:
            Dx = obj.shifts(movNum).slice(iSl).x();
            Dy = obj.shifts(movNum).slice(iSl).y();
            
            % Using GPU?
            isGpu = gpuDeviceCount > 0;
            if isGpu
                gpu = gpuDevice(1); % Select first GPU.
                memAvailable = gpu.AvailableMemory;
                mov = movStruct.slice(1).channel(1).mov;  %#ok<NASGU>
                movInfo = whos('mov');
                if memAvailable < 2.5 * movInfo.bytes % Need at least 2.5 * moviesize.
                    isGpu = 0;
                end
            end
            
            for iCh = 1:nChannel
                if isGpu
                    mov_g = gpuArray(movStruct.slice(iSl).channel(iCh).mov);
                    cor_g = gpuArray.zeros(size(mov_g));
                    for f = 1:z
                        cor_g(:,:,f) = ...
                            interp2(...
                                mov_g(:,:,f), ...
                                Dx(:,:,f), ...
                                Dy(:,:,f), ...
                                'linear');
                    end
                    movStruct.slice(iSl).channel(iCh).mov = gather(cor_g);
                else
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
                    nanmean(movStruct.slice(iSl).channel(iCh).mov,3);
            end
        end
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
function fn = createDispFieldFunctionX(h, w, z, basisFunctions, dpx, xGlobal)
fn = @dispFieldX;
    function dx = dispFieldX
        lineShiftX = zeros(h, z);
        for f = 1:z
            lineShiftX(:, f) = basisFunctions*dpx(:, f) - xGlobal;
        end
        dx = bsxfun(@plus, 1:w, permute(lineShiftX, [1, 3, 2]));
    end
end

function fn = createDispFieldFunctionY(h, w, z, basisFunctions, dpy, yGlobal)
fn = @dispFieldY;
    function dy = dispFieldY
        lineShiftY = zeros(h, z);
        for f = 1:z
            lineShiftY(:, f) = basisFunctions*dpy(:, f) - yGlobal;
        end
        dy = bsxfun(@plus, zeros(1, w), permute(bsxfun(@plus, (1:h)', lineShiftY), [1, 3, 2]));
    end
end