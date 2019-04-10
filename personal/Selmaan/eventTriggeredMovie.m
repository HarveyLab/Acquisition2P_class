function [avgMov, dFmov] = eventTriggeredMovie(obj,avgMovFrames)

% avgMovFrames should be a 1xf cell array, where f is the number of frames
% in the average movie, and each cell contains the (data) frame numbers to
% be averaged together for each triggered movie frame

% Note that the code will not allow 'double counting' of movie frames
% within individual average-bins. That is, no matter how many times a
% single frame appears within a single cell/bin, it will only be added once
% and it will only add 1 to the denominator used for converting sum to avg

allFrames = sort(unique([avgMovFrames{:}]));
fileFrames = cumsum(obj.correctedMovies.slice.channel.size(:,3));
fileFrameIDs = nan(size(allFrames));
for i=1:length(fileFrameIDs)
    fileFrameIDs(i) = find(allFrames(i)<=fileFrames,1,'first');
end
% filesToLoad = unique(fileFrameIDs);

fprintf('\n Pre-Determining Frame-Bin Memberships...'),
masterFrameMember = false(length(allFrames),length(avgMovFrames));
parfor i = 1:length(avgMovFrames)
    masterFrameMember(:,i) = any(allFrames == avgMovFrames{i}(:)',2);
end
fprintf('DONE! \n'),

avgMov = zeros(512,512,length(avgMovFrames));
thisFile = 0;
for frame = 1:length(allFrames)
    if thisFile ~= fileFrameIDs(frame)
        if thisFile ~=0
            t.close;
        end
        thisFile = fileFrameIDs(frame);
        fprintf('\n file %d up to %d',thisFile,max(fileFrameIDs)),
        t = ScanImageTiffReader(obj.correctedMovies.slice(1).channel(1).fileName{thisFile});
        fileData = single(data(t));
        fileData = permute(fileData,[2 1 3]);
    end
    
    if thisFile > 1
        imgDir = allFrames(frame)-fileFrames(thisFile-1);
    else
        imgDir = allFrames(frame);
    end

    thisFrame = fileData(:,:,imgDir);
    thisFrameMem = masterFrameMember(frame,:);
    avgMov(:,:,thisFrameMem) = avgMov(:,:,thisFrameMem) + thisFrame;
end

for avgFrame = 1:length(avgMovFrames)
    avgMov(:,:,avgFrame) = avgMov(:,:,avgFrame) / length(unique(avgMovFrames{avgFrame}));
end
dFmov = bsxfun(@rdivide,avgMov,meanRef(obj));
