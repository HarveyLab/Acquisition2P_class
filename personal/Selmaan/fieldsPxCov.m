function fieldsPxCov(obj, movNums, radiusPxCov, temporalBin, sliceNum, channelNum, writeDir)

% Function to fill in acq2p object fields for a pixCov file
% Function mimics setup of calcPxCov and fields in fields as if function
% were called ordinarily

%% Input handling / Error Checking
if ~exist('sliceNum','var') || isempty(sliceNum)
    sliceNum = 1;
end
if ~exist('channelNum','var') || isempty(channelNum)
    channelNum = 1;
end
if ~exist('movNums','var') || isempty(movNums)
    movNums = 1:length(obj.correctedMovies.slice(sliceNum).channel(channelNum).fileName);
end
if ~exist('radiusPxCov','var') || isempty(radiusPxCov)
    radiusPxCov = 11;
end 
if ~exist('temporalBin','var') || isempty(temporalBin)
    temporalBin = 8;
end 
if ~exist('writeDir','var') || isempty(writeDir)
    writeDir = obj.defaultDir;
end


%% Fill in structure fields
movSize = obj.correctedMovies.slice.channel.size(1,:);
h=movSize(1);
w=movSize(2);
nPix = w*h;
nh = 2*round(radiusPxCov)+1;
diags = bsxfun(@plus, (-nh+1:nh-1)', 0:h:h*(nh-1));
diags = diags(:)';
diags(diags<0) = [];
nDiags = numel(diags);
obj.roiInfo.slice(sliceNum).covFile.nh = nh;
obj.roiInfo.slice(sliceNum).covFile.nPix = nPix;
obj.roiInfo.slice(sliceNum).covFile.nDiags = nDiags;
obj.roiInfo.slice(sliceNum).covFile.diags = diags;
obj.roiInfo.slice(sliceNum).covFile.channelNum = channelNum;
obj.roiInfo.slice(sliceNum).covFile.temporalBin = temporalBin;