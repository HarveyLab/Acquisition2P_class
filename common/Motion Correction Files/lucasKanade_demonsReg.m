function movStruct = lucasKanade_demonsReg(...
    obj, movStruct, scanImageMetadata, movNum, opMode)
% movStruct = withinFile_withinFrame_lucasKanade(obj, movStruct, scanImageMetadata, movNum, opMode)
% finds/corrects in-frame motion with an algorithm that takes into account
% that images are acquired by raster scanning (Greenberg and Kerr, 2009)

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
                % reference movie does not need global alignment
                demonsGlobal = zeros([size(ref), 2]);
                thisRef = nanmean(movTemp,3);
                obj.motionRefImage.slice(iSl).img = ...
                    thisRef;
                obj.derivedData(movNum).meanRef.slice(iSl).channel(refCh).img = thisRef;
                
            else                
                refGlobal = obj.motionRefImage.slice(iSl).img;
                refHere = nanmedian(movTemp, 3); 
                demonsGlobal = imregdemons(refHere,refGlobal,[100 50 25],...
                    'AccumulatedFieldSmoothing',25,'DisplayWaitbar',false);               
            end
            
            % These functions take the height-by-1 lineShift arrays and
            % expand them along the width and nFrames-dimensions. At the
            % same time, they add values corresponding to the
            % grid-positions of each pixel (same as if we created grid
            % matrixes with MESHGRID, but more efficient).
            obj.shifts(movNum).slice(iSl).x = createDispFieldFunctionX(h, w, z, basisFunctions, dpx, single(demonsGlobal(:,:,1)));
            obj.shifts(movNum).slice(iSl).y = createDispFieldFunctionY(h, w, z, basisFunctions, dpy, single(demonsGlobal(:,:,2)));
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
                thisMov = movStruct.slice(iSl).channel(iCh).mov;
                parfor f = 1:z
                    thisMov(:,:,f) = ...
                        interp2(...
                            thisMov(:,:,f), ...
                            Dx(:,:,f), ...
                            Dy(:,:,f), ...
                            'linear', nan);
                end
                movStruct.slice(iSl).channel(iCh).mov = thisMov;
                obj.derivedData(movNum).meanRef.slice(iSl).channel(iCh).img = ...
                    nanmean(movStruct.slice(iSl).channel(iCh).mov, 3);
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
function fn = createDispFieldFunctionX(h, w, z, basisFunctions, dpx, demonsGlobal)
fn = @dispFieldX;
    function dx = dispFieldX
        % Get local displacement field:
        lineShiftX = zeros(h, z);
        for f = 1:z
            lineShiftX(:, f) = basisFunctions*dpx(:, f);
        end
        dx = bsxfun(@plus, 1:w, permute(lineShiftX, [1, 3, 2]));        
        dx = bsxfun(@plus, dx, demonsGlobal);
    end
end

function fn = createDispFieldFunctionY(h, w, z, basisFunctions, dpy, demonsGlobal)
fn = @dispFieldY;
    function dy = dispFieldY
        % Get local displacement field:
        lineShiftY = zeros(h, z);
        for f = 1:z
            lineShiftY(:, f) = basisFunctions*dpy(:, f);
        end
        dy = bsxfun(@plus, zeros(1, w), permute(bsxfun(@plus, (1:h)', lineShiftY), [1, 3, 2]));
        dy = bsxfun(@plus, dy, demonsGlobal);
    end
end