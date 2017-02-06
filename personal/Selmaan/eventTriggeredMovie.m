function [avgMov, dFmov] = eventTriggeredMovie(obj,avgMovFrames)

% avgMovFrames should be a 1xf cell array, where f is the number of frames
% in the average movie, and each cell contains the (data) frame numbers to
% be averaged together for each triggered movie frame

allFrames = sort(unique([avgMovFrames{:}]));
fileFrames = cumsum(obj.correctedMovies.slice.channel.size(:,3));
fileFrameIDs = nan(size(allFrames));
for i=1:length(fileFrameIDs)
    fileFrameIDs(i) = find(allFrames(i)<=fileFrames,1,'first');
end
% filesToLoad = unique(fileFrameIDs);

avgMov = zeros(512,512,length(avgMovFrames));
thisFile = 0;
for frame = 1:length(allFrames)
    if thisFile ~= fileFrameIDs(frame)
        if thisFile ~=0
            t.close
        end
        thisFile = fileFrameIDs(frame);
        fprintf('\n file %d up to %d',thisFile,max(fileFrameIDs)),
        t = Tiff(obj.correctedMovies.slice(1).channel(1).fileName{thisFile});
    end
    
    if thisFile > 1
        imgDir = allFrames(frame)-fileFrames(thisFile-1);
    else
        imgDir = allFrames(frame);
    end
    t.setDirectory(imgDir);
    
    thisFrame = double(t.read);
    frame2avgFrame = find(cellfun(@(x) ismember(allFrames(frame),x),avgMovFrames));
    
    for avgFrame = frame2avgFrame
        avgMov(:,:,avgFrame) = avgMov(:,:,avgFrame) + thisFrame;
    end
end

for avgFrame = 1:length(avgMovFrames)
    avgMov(:,:,avgFrame) = avgMov(:,:,avgFrame) / length(avgMovFrames{avgFrame});
end
dFmov = bsxfun(@rdivide,avgMov,meanRef(obj));
