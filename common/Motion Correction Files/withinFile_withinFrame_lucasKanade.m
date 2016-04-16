function movStruct = withinFile_withinFrame_lucasKanade(...
    obj, movStruct, scanImageMetadata, movNum, opMode)
% movStruct = withinFile_withinFrame_lucasKanade(obj, movStruct, scanImageMetadata, movNum, opMode)
% finds/corrects in-frame motion with an algorithm that takes into account
% that images are acquired by raster scanning (Greenberg and Kerr, 2009)

nSlice = numel(movStruct.slice);
nChannel = numel(movStruct.slice(1).channel);
isGpu = false;
if isGpu
    gpu = gpuDevice;
    pctRunOnAll reset(gpuDevice);
    wait(gpu)
    memAvailable = gpu.AvailableMemory;
end
isEqualizeLuminace = true;

switch opMode
    case 'identify'
        refCh = obj.motionRefChannel;
        refMov = obj.motionRefMovNum;
        for iSl = 1:nSlice
            [h, w, z] = size(double(movStruct.slice(iSl).channel(refCh).mov));
            
            % Perform luminance equalization (this may be helpful for
            % movies with very uneven brightness, e.g. one highly
            % overexpressing region besides a healthy region of interest):
            if isEqualizeLuminace
                localLuminance = imgaussfilt(movStruct.slice(iSl).channel(refCh).mov, round(h/12));
                movStruct.slice(iSl).channel(refCh).mov = ...
                    bsxfun(@rdivide, movStruct.slice(iSl).channel(refCh).mov, localLuminance);
            end
            
            % Perform whole-frame translation correction (this is fast and
            % improves the quality of the reference used for the Lucas
            % Kanade step):
            isEdge = (1:w) < 0.1*w | (1:w) > 0.9*w; % Exclude black bars!
            r = detectFullframeRecursive(movStruct.slice(iSl).channel(refCh).mov(:, ~isEdge, :), 1:z);
            movStruct.slice(iSl).channel(refCh).mov = ...
                alignFullframe(movStruct.slice(iSl).channel(refCh).mov, r.T(:, 2), r.T(:, 1));
            
            % Calculate reference on full-frame-corrected movie:
            ref = mean(movStruct.slice(iSl).channel(refCh).mov, 3);
            ref = single(ref);
            
            % Find within-frame displacements:
            [movTemp, dpx, dpy, basisFunctions] = ...
                doLucasKanadeSPMD(single(movStruct.slice(iSl).channel(refCh).mov), ref);
            
            % Combine full-frame and within-frame displacements:
            dpx = bsxfun(@minus, dpx, r.T(:, 2)');
            dpy = bsxfun(@minus, dpy, r.T(:, 1)');
                        
            % Find global displacement with respect to global reference
            % image:
            if movNum == refMov
                tformGlobal = affine2d;
                obj.motionRefImage.slice(iSl).img = nanmedian(movTemp, 3);
            else
                refHere = nanmedian(movTemp, 3);
                refGlobal = obj.motionRefImage.slice(iSl).img;
                
                % It is important to exclude the black bars that are
                % present in older Scanimage files because they don't
                % translate and will bias the results. We simply cut off
                % 10 % on either side:
                isEdge = (1:w) < 0.1*w | (1:w) > 0.9*w;
                
                % First, we find translation only. The subsequent affine
                % step only works robustly if the translation has already
                % been removed:
                [xTrans, yTrans] = track_subpixel_wholeframe_motion_fft_forloop(...
                    refHere(:, ~isEdge), refGlobal(:, ~isEdge));
                refHereTransl = alignFullframe(refHere, xTrans, yTrans);
                
                % Find affine transformation using mutual information
                % metric:
                opt = imregconfig('Monomodal');
                met = registration.metric.MattesMutualInformation;
                RA = imref2d([h, sum(~isEdge)]);      
                tformGlobal = imregtform(refHereTransl(:, ~isEdge), RA, refGlobal(:, ~isEdge), RA, ...
                    'affine', opt, met, ...
                    'InitialTransformation', affine2d, 'PyramidLevels', 1);
                
                % Combine translation and affine transformation:
                tformGlobal.T = tformGlobal.T * [1 0 0; 0 1 0; xTrans yTrans 1];
            end
            
            % The motion correction algorithm calculates a rigid shift for
            % each line (because lines are scanned fast, so there is
            % probably no shift within a line). The displacement field for
            % the entire frame is created by expanding the line shifts
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
            obj.shifts(movNum).slice(iSl).x = createDispFieldFunctionX(h, w, z, basisFunctions, dpx, dpy, tformGlobal);
            obj.shifts(movNum).slice(iSl).y = createDispFieldFunctionY(h, w, z, basisFunctions, dpx, dpy, tformGlobal);
        end
        
    case 'apply'
        for iSl = 1:nSlice
            z = size(movStruct.slice(iSl).channel(1).mov, 3);
            % Get full displacement fields:
            Dx = obj.shifts(movNum).slice(iSl).x();
            Dy = obj.shifts(movNum).slice(iSl).y();
            
            for iCh = 1:nChannel
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
function fn = createDispFieldFunctionX(h, w, z, basisFunctions, dpx, dpy, tformGlobal)
fn = @dispFieldX;
    function dx = dispFieldX
        % Get local displacement field:
        lineShiftX = zeros(h, z);
        lineShiftY = zeros(h, z);
        for f = 1:z
            lineShiftX(:, f) = basisFunctions*dpx(:, f);
            lineShiftY(:, f) = basisFunctions*dpy(:, f);
        end
        dx = bsxfun(@plus, 1:w, permute(lineShiftX, [1, 3, 2]));
        dy = bsxfun(@plus, zeros(1, w), permute(bsxfun(@plus, (1:h)', lineShiftY), [1, 3, 2]));
        
        % Add global transformation:
        [dx, ~] = transformPointsInverse(tformGlobal, dx, dy);
    end
end

function fn = createDispFieldFunctionY(h, w, z, basisFunctions, dpx, dpy, tformGlobal)
fn = @dispFieldY;
    function dy = dispFieldY
        % Get local displacement field:
        lineShiftX = zeros(h, z);
        lineShiftY = zeros(h, z);
        for f = 1:z
            lineShiftX(:, f) = basisFunctions*dpx(:, f);
            lineShiftY(:, f) = basisFunctions*dpy(:, f);
        end
        dx = bsxfun(@plus, 1:w, permute(lineShiftX, [1, 3, 2]));
        dy = bsxfun(@plus, zeros(1, w), permute(bsxfun(@plus, (1:h)', lineShiftY), [1, 3, 2]));
        
        % Add global transformation:
        [~, dy] = transformPointsInverse(tformGlobal, dx, dy);
    end
end