function saveRoiInfoBackup(sel)
% Save temporary roiInfo backup to restore cell selection if there is a
% crash. The roiInfo variable is small so saving is fast.

p = fullfile(sel.acq.defaultDir, [sel.acq.acqId '_roiInfo_backup.mat']);
roiInfo = sel.acq.roiInfo; %#ok<NASGU>
save(p, 'roiInfo');
fprintf('%s: Backed up roiInfo to %s.\n', datestr(now, 'HH:MM:SS'), p);
