function movStruct = withinFile_segmentConsensus(obj,movStruct, metaMov, movNum, opMode)
%Example of a motion correction function compatable with Acquisition2P class,
%calculates full frame translations within each file independently, then adds
%these to shifts calculated between each file

% Clips off pockels-blanked region. Roughly set manually for Si4 default
% blanking fraction and 512x512 movie, should be generalized in future

binFactor = obj.binFactor;
clipOn = round(50/binFactor);
clipOff = round(470/binFactor);
M = length(clipOn:clipOff);
N = 512/binFactor;

% Define Segments, set manually to handle 6-segment grid (more segments in
% y than in x)
segPos = [];
xSegInd = [];
ySegInd = [];
xind = floor(linspace(1,M/2,2));
yind = floor(linspace(1,N/2,3));
for x=1:length(xind)
    for y=1:length(yind)
        segPos(end+1,:) = [xind(x) yind(y)  floor(M/2) floor(N/2)];
        ySegInd(end+1,:) = segPos(end,2):segPos(end,2)+segPos(end,4);
        xSegInd(end+1,:) = segPos(end,1):segPos(end,1)+segPos(end,3);
    end
end
nSeg = size(segPos,1);

nSlices = numel(movStruct.slice);
nChannels = numel(movStruct.slice(1).channel);

switch opMode
    case 'identify'
        motionRefChannel = obj.motionRefChannel;
        motionRefMovNum = obj.motionRefMovNum;
        x=[];
        y=[];        
        for nSlice = 1:nSlices
            for nSeg = 1:size(segPos,1)
                tMov = sqrt(movStruct.slice(nSlice).channel(motionRefChannel).mov(ySegInd(nSeg,:),xSegInd(nSeg,:),:));
                [x(nSeg,:),y(nSeg,:)] = track_subpixel_wholeframe_motion_fft_forloop(...
                    tMov, mean(tMov,3));
            end
            tempSlice = translateAcq(movStruct.slice(nSlice).channel(motionRefChannel).mov, median(x), median(y));
            if movNum == motionRefMovNum
                obj.motionRefImage.slice(nSlice).img = nanmean(tempSlice,3);
                xFile = 0;
                yFile = 0;
            else
                [xFile,yFile] = track_subpixel_wholeframe_motion_fft_forloop(...
                    nanmean(tempSlice(:,clipOn:clipOff,:),3),obj.motionRefImage.slice(nSlice).img(:,clipOn:clipOff,:));
            end

           obj.shifts(movNum).slice(nSlice).x = x+xFile;
           obj.shifts(movNum).slice(nSlice).y = y+yFile;
        end
    case 'apply'
        for nSlice = 1:nSlices
            for nChannel = 1:nChannels
                mov = translateAcq(movStruct.slice(nSlice).channel(nChannel).mov,...
                    median(obj.shifts(movNum).slice(nSlice).x), median(obj.shifts(movNum).slice(nSlice).y));
            end
                obj.derivedData(movNum).meanRef.slice(nSlice).channel(nChannel).img = mean(mov,3);
                movStruct.slice(nSlice).channel(nChannel).mov = mov;
        end
end