function varargout = withinFile_fullFrame_fft(obj,movStruct, metaMov, movNum, opMode)
%Example of a motion correction function compatable with Acquisition2P class,
%calculates full frame translations within each file independently, then adds
%these to shifts calculated between each file

nSlices = metaMov.stackNumSlices;
nChannels = numel(metaMov.channelsSave);

switch opMode
    case 'identify'
        motionRefChannel = obj.motionRefChannel;
        motionRefMovNum = obj.motionRefMovNum;
        for nSlice = 1:nSlices
            [x,y] = track_subpixel_wholeframe_motion_fft_forloop(sqrt(movStruct.slice(nSlice).channel(motionRefChannel).mov),...
                sqrt(mean(movStruct.slice(nSlice).channel(motionRefChannel).mov,3)));
            tempSlice = translateAcq(movStruct.slice(nSlice).channel(motionRefChannel).mov, x, y);
            if movNum == motionRefMovNum
                obj.motionRefImage.slice(nSlice).img = nanmean(tempSlice,3);
                xFile = 0;
                yFile = 0;
            else
                [xFile,yFile] = track_subpixel_wholeframe_motion_fft_forloop(nanmean(tempSlice,3),obj.motionRefImage.slice(nSlice).img);
            end

           obj.shifts(movNum).slice(nSlice).x = x+xFile;
           obj.shifts(movNum).slice(nSlice).y = y+yFile;
        end
        varargout{1} = obj;
    case 'apply'
        for nSlice = 1:nSlices
            for nChannel = 1:nChannels
                mov = translateAcq(movStruct.slice(nSlice).channel(nChannel).mov,...
                    obj.shifts(movNum).slice(nSlice).x, obj.shifts(movNum).slice(nSlice).y);
                end
                obj.derivedData(movNum).meanRef.slice(nSlice).channel(nChannel).img = mean(mov,3);
                movStruct.slice(nSlice).channel(nChannel).mov = mov;
            end
        end
        varargout{1} = obj;
        varargout{2} = movStruct;
end