function [stimMov, dFmov] = getStimEvokedMovie(stimExpt, nROI, nTarg, winSize)

if nargin < 4
    winSize = 30;
end
% 
% if nargin < 3
%     nTarg = nROI;
% end

% tV = stimExpt.tV;

mov = getRoiMovie(stimExpt.acq, stimExpt.cIds(nROI), winSize);
stimTimes = [];
for nBlock = 1:stimExpt.numStimBlocks
   blockOffsetFrame = length(cat(1,stimExpt.frameTimes{1:nBlock-1}));
   theseStim = stimExpt.psych2frame{nBlock}(stimExpt.stimOrder{nBlock}==nTarg);
   theseStim = theseStim + blockOffsetFrame;
   stimTimes = cat(1,stimTimes,theseStim(:));
end
% stimTimes = cellfun(@min,tV.stimFrames(tV.nTarg==nTarg));

stimFrames = [];
for i=1:length(stimTimes)
    stimFrames(i,:) = stimTimes(i)-30:stimTimes(i)+90;
end
stimFrames(stimFrames<1)=1;
stimFrames(stimFrames>size(mov,3))=size(mov,3);
stimMov = mov(:,:,stimFrames(:));
stimMov = squeeze(mean(reshape(stimMov,...
    [size(mov,1) size(mov,2) size(stimFrames,1) size(stimFrames,2)]),3));
% implay((stimMov-min(stimMov(:)))/max(stimMov(:)))
dFmov = (bsxfun(@rdivide,stimMov,mean(mov,3))-1);
% implay(dFmov/max(dFmov(:)))