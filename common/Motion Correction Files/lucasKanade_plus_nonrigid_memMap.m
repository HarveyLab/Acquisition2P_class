function movStruct = lucasKanade_plus_nonrigid_memMap(...
    obj, movStruct, scanImageMetadata, movNum, opMode)
% movStruct = withinFile_withinFrame_lucasKanade(obj, movStruct, scanImageMetadata, movNum, opMode)
% finds/corrects in-frame motion with an algorithm that takes into account
% that images are acquired by raster scanning (Greenberg and Kerr, 2009)

dsFactor = 40;
nSlice = numel(movStruct.slice);
nChannel = numel(movStruct.slice(1).channel);

switch opMode
    case 'identify'
        refCh = obj.motionRefChannel;
        refMov = obj.motionRefMovNum;
        for iSl = 1:nSlice
            [h, w, z] = size(double(movStruct.slice(iSl).channel(refCh).mov));
            movTemp = movStruct.slice(iSl).channel(refCh).mov;
            
            % Perform whole-frame translation correction (this is fast and
            % improves the quality of the reference used for the Lucas
            % Kanade step):
            % Use the old wholeframe code rather than the recursive
            % function that builds up a mean image, because the recursive
            % function can fail catastrophically if individual frames are
            % very low SNR:
            [xTrans, yTrans] = track_subpixel_wholeframe_motion_fft_forloop(...
                movTemp, mean(movTemp, 3));
            movTemp = translateAcq(movTemp, xTrans, yTrans, 0);
            
            % Calculate reference on full-frame-corrected movie:
            ref = mean(movTemp, 3);
            ref = single(ref);
            
            % Find within-frame displacements:
            [movTemp, dpx, dpy, basisFunctions] = ...
                doLucasKanadeSPMD(single(movTemp), ref);
            
            % Combine full-frame and within-frame displacements:
            dpx = bsxfun(@minus, dpx, xTrans);
            dpy = bsxfun(@minus, dpy, yTrans);
                        
            % Find global displacement with respect to global reference
            % image:
            if movNum == refMov
                % Reference movie does not need global alignment
                T_affine_global = affine2d;
                D_nonrigid_global = zeros(h, w, 2);
                
                thisRef = nanmean(movTemp,3);
                obj.motionRefImage.slice(iSl).img = thisRef;
                obj.derivedData(movNum).meanRef.slice(iSl).channel(refCh).img = thisRef;
                
                % Create a memory-mapped data file
                movSize = size(thisRef);
                mapFn = fullfile(obj.defaultDir,'dsMemMap.mat');
                memMap = matfile(mapFn,'Writable',true);
                obj.indexedMovie.slice(iSl).channel(1).memMap = mapFn;
                memMap.Y = zeros([movSize,0],'single');
                memMap.Yr = zeros([prod(movSize),0],'single');
                memMap.sizY = [movSize,0];
                memMap.dsRatio = size(movTemp,3)/dsFactor;
                
            else                
                refGlobal = obj.motionRefImage.slice(iSl).img;
                refGlobal(isnan(refGlobal)) = 0; % imregtform can't deal with nans.
                refHere = nanmedian(movTemp, 3); 
                
                % First, we find translation only. The subsequent affine
                % step only works robustly if the translation has already
                % been removed:
                [xTrans, yTrans] = track_subpixel_wholeframe_motion_fft_forloop(...
                    refHere, refGlobal);
                Tinit = affine2d;
                Tinit.T = [1 0 0; 0 1 0; xTrans yTrans 1];
                
                % Second, find affine transformation using mutual
                % information metric:
                opt = imregconfig('Monomodal');
                opt.MaximumIterations = 50;
                met = registration.metric.MattesMutualInformation;
                R = imref2d([h, w], [-(w/2-0.5), w/2-0.5], [-(h/2-0.5), h/2-0.5]);      
                T_affine_global = imregtform(refHere, R, refGlobal, R, ...
                    'affine', opt, met, ...
                    'InitialTransformation', Tinit, 'PyramidLevels', 1);
                
                % Third, perform nonrigid registration. It is necessary to
                % perfrom rigid and affine first to get a good
                % registration.
                epsilon = 1e-2; % Avoid div by small number.
                highpass = @(i) i ./ (imgaussfilt(i, round(w*0.02)) + epsilon);
                fixed = highpass(refGlobal);
                moving = highpass(imwarp(refHere, R, T_affine_global, ...
                    'outputview', R));
                
                % Pad the image to cover up the black edges that are due to
                % previous correction steps, which cause issues with the
                % registration quality at the image edges. Copying a strip
                % from further inside the image will preserve much of the
                % local deformation flow:
                margin = round(w*0.05);
                moving(:,1:margin) = moving(:,(1:margin)+margin);
                moving(:,w-(1:margin)+1) = moving(:,w-(1:margin)+1-margin);
                moving(1:margin, :) = moving((1:margin)+margin, :);
                moving(h-(1:margin)+1, :) = moving(h-(1:margin)+1-margin, :);
                moving(:,1:margin) = moving(:,(1:margin)+margin); % Re-do first to cover the last corner.
                D_nonrigid_global = imregdemons(moving, fixed, 'AccumulatedFieldSmoothing', 5, ...
                    'DisplayWaitbar', false);
            end
            
            % Convert affine transformation matrix into displacement
            % field:
            [xGrid, yGrid] = meshgrid((1:w)-0.5-w/2, (1:h)-0.5-h/2);
            [xAffine, yAffine] = transformPointsInverse(T_affine_global, xGrid, yGrid);
            D_affine = cat(3, xAffine-xGrid, yAffine-yGrid);
                           
            % Combine affine and nonrigid displacement fields:
            D_global = combineDisplacementFields(D_affine, D_nonrigid_global);
            
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
            obj.shifts(movNum).slice(iSl).D = createDispFieldFunction(...
                h, w, z, basisFunctions, dpx, dpy, D_global);
        end
        
    case 'apply'
        for iSl = 1:nSlice
            [h, w, z] = size(movStruct.slice(iSl).channel(1).mov);
            
            % Get full displacement fields:
            % D is a stack of displacement fields of size h * w * 2 * nFrames:
            D = obj.shifts(movNum).slice(iSl).D();
            [xGrid, yGrid] = meshgrid((1:w)-0.5-w/2, (1:h)-0.5-h/2);

            for iCh = 1:nChannel
                % This for-loop is faster than using interpn without a
                % loop, both on the CPU and the GPU. Re-evaluate this if we
                % have a GPU that can fit an entire movie into RAM.
                for f = 1:z
                    movStruct.slice(iSl).channel(iCh).mov(:,:,f) = ...
                        interp2(xGrid, yGrid, ...
                            movStruct.slice(iSl).channel(iCh).mov(:,:,f), ...
                            xGrid + D(:,:,1,f), ...
                            yGrid + D(:,:,2,f), ...
                            'bicubic', nan);
                end
                obj.derivedData(movNum).meanRef.slice(iSl).channel(iCh).img = ...
                    nanmean(movStruct.slice(iSl).channel(iCh).mov, 3);
                
                % Downsample data and save to memmap
                if iCh == 1
                    tStart = tic;
                    memMap = matfile(...
                        obj.indexedMovie.slice(iSl).channel(1).memMap,'Writable',true);
                    movSize = size(memMap,'Y');
                    framesOffset = size(memMap,'Yr',2);%movSize(3);
                    validFrames = 1:(floor(z/memMap.dsRatio)*memMap.dsRatio);
                    thisMov = movStruct.slice(iSl).channel(iCh).mov;
                    dsMov = squeeze(mean(reshape(single(thisMov(:,:,validFrames)),...
                        movSize(1), movSize(2), memMap.dsRatio, length(validFrames)/memMap.dsRatio),3));
                    theseFrames = framesOffset+(1:size(dsMov,3));
                    memMap.Y(:,:,theseFrames) = dsMov;
                    memMap.Yr(:,theseFrames) = reshape(dsMov,prod(movSize(1:2)),size(dsMov,3));
                    fprintf('Saving to memmap took %1.1f seconds.\n', toc(tStart));
                end
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
function fn = createDispFieldFunction(h, w, z, basisFunctions, dpx, dpy, D_global)

% We don't need double precision for displacement fields (single still
% provides pixel*1e-7 resolution):
basisFunctions = single(basisFunctions);
dpx = single(dpx);
dpy = single(dpy);
D_global = single(D_global);

fn = @dispField;
function D = dispField
    % Get local displacement field:
    lineShiftX = zeros(h, z, 'single');
    lineShiftY = zeros(h, z, 'single');
    
    % Discard unrealistically large shifts (note that whole-frame
    % translation has already been corrected). Large shifts are assumed to
    % be artefacts and are completely ignored (set to zero):
    threshold = 10;
    isExtremeShift = abs(dpx)>threshold | abs(dpy)>threshold;
    if any(isExtremeShift(:))
       dpx(isExtremeShift) = 0;
       dpy(isExtremeShift) = 0; 
       fprintf('%1.1f%% of shifts were greater than %1.1f pixels and were set to zero since they are probably artefactual.\n', ...
           mean(isExtremeShift(:))*100, threshold)
    end
    
    for f = 1:z
        lineShiftX(:, f) = basisFunctions*dpx(:, f);
        lineShiftY(:, f) = basisFunctions*dpy(:, f);
    end
    dx = permute(repmat(permute(lineShiftX, [1, 3, 2]), [1, w, 1]), [1, 2, 4, 3]);
    dy = permute(repmat(permute(lineShiftY, [1, 3, 2]), [1, w, 1]), [1, 2, 4, 3]);
    
    % At this point, D is of size h * w * 2 * nFrames:
    D = cat(3, dx, dy);
    clear dx dy
    
    % Add global transformation:
    D = combineDisplacementFields(D, D_global);
end
end

function D = combineDisplacementFields(D1, D2)
% Combines two sequential transformations D1 and D2 into one displacement
% field. The output D is a displacement field that has the same effect as
% appling first D1 and then D2 to an image.
% Multiple displacement fields can be provided by stacking them in the 4th
% dimension of the D arrays. Broadcasting is supported.

h = size(D1, 1);
w = size(D1, 2);
n1 = size(D1, 4);
n2 = size(D2, 4);

% For broadcasting of stacks of displacement fields:
if n1>1 && n2>1 && n1~=n2
    error('Numbers of displacement fields don''t match!')
else
    n = max(n1, n2);
end
if n1==1
    ind1 = ones(1, n);
    D1 = reshape(D1, h, w, 2, 1);
else
    ind1 = 1:n;
end
if n2==1
    ind2 = ones(1, n);
    D2 = reshape(D2, h, w, 2, 1);
else
    ind2 = 1:n;
end  

% Untransformed pixel coordinates:
[xGrid, yGrid] = meshgrid((1:w)-0.5-w/2, (1:h)-0.5-h/2);
xGrid = single(xGrid);
yGrid = single(yGrid);

% For interpolation/resampling of displacement fields, it
% makes sense to represent the x and y coordinates as
% complex numbers, so that only one interpolation step is
% necessary.
C1 = squeeze(complex(bsxfun(@plus, D1(:,:,1,:), xGrid), ...
                     bsxfun(@plus, D1(:,:,2,:), yGrid)));
clear D1

D = zeros(h, w, 2, n, 'like', D2);
for i = 1:n
    % Apply nonrigid transformation to affine-transformed
    % coordinates:
    C = interp2(xGrid, yGrid, C1(:,:,ind1(i)), ...
        xGrid+D2(:,:,1,ind2(i)), yGrid+D2(:,:,2,ind2(i)), 'cubic');

    % Convert from pixel coordinates to displacement field:
    D(:,:,:,i) = cat(3, real(C)-xGrid, imag(C)-yGrid);
end

if n==1
    D = squeeze(D);
end

end