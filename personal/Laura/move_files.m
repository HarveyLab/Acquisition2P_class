cd('Z:\Laura\code_workspace\LD187')
mouseDir = pwd;
sessionList = dir('LD*');
destDir = ['C:\DATA\Laura\code_workspace\' sessionList(1).name(1:5)];
for session = 7:9%:size(sessionList)
    cd(fullfile(mouseDir,sessionList(session).name))
    load(['selected_rois_' sessionList(session).name(1:12)],'acq')
    if ~exist(fullfile(destDir,sessionList(session).name),'dir')
    mkdir(fullfile(destDir,sessionList(session).name))
    end
    newDir(acq,fullfile(destDir,sessionList(session).name),0,1,1)
    cd(fullfile(destDir,sessionList(session).name))
end