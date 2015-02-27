cd('Z:\Laura\DATA\imaging\Current Imaging\LD169')
mouseDir = pwd;
sessionList = dir('LD*');
% 
for session = [3:4 58:size(sessionList,1)-1]
cd(fullfile(mouseDir,sessionList(session).name))
% acq = Acquisition2P([],@lnd_init);
% acq.motionCorrect;
output_dir = fullfile('Z:\Laura\code_workspace\',mouseDir(end-4:end),...
    sessionList(session).name);
if ~exist(output_dir,'dir')
    mkdir(output_dir)
end
load([sessionList(session).name '_001.mat']);
eval(['acq = ' sessionList(session).name '_001;'])
channelNum = 1;
acq.metaDataSI = metaDataSI;
sizeArray = repmat(sizeBit,[size(acq.Movies,2) 1]);
for sliceNum = 2:4;
acq.correctedMovies.slice(sliceNum).channel(1).size = sizeArray;
acq.indexMovie(sliceNum,channelNum,output_dir);
acq.calcPxCov([],[],[],sliceNum,channelNum,output_dir);
save(fullfile(output_dir,sessionList(session).name),'acq','-v7.3')
end
clear acq
eval(['clear ' sessionList(session).name '_001'])
end
