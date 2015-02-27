cd('Z:\Laura\code_workspace\LD185')
mouseDir = pwd;
sessionList = dir('LD*');

for session = [36 8:34 37:size(sessionList,1)]
output_dir = fullfile('Z:\Laura\code_workspace\',...
    sessionList(session).name(1:5),sessionList(session).name);
if ~exist(output_dir,'dir')
    mkdir(output_dir)
end
cd(fullfile(mouseDir,sessionList(session).name))

selected_rois = dir('*_mary.mat');
if ~isempty(selected_rois)
channelNum = 1;
load(selected_rois.name)
acq1 = acq;
for sliceNum = 1:4;
acq1.indexMovie(sliceNum,channelNum,output_dir);
acq1.calcPxCov([],[],[],sliceNum,channelNum,output_dir);
acq.roiInfo.slice(sliceNum).covFile = acq1.roiInfo.slice(sliceNum).covFile;
acq.indexedMovie.slice(sliceNum) = acq1.indexedMovie.slice(sliceNum);
end
save(fullfile(output_dir,sessionList(session).name),'acq','-v7.3')
end
clear acq
selected_rois = [];
end
