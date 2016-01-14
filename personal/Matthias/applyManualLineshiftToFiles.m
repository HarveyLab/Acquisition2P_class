function applyManualLineshiftToFiles(folder, fileId)
% applyManualLineshiftToFiles(folder, fileId, lineShift) applies LINESHIFT
% to all files in FOLDER that match FILEID.

lst = dir(fullfile(folder, [fileId '*']));

for i = 1:numel(lst)
    fprintf('Correcting file %s...\n', lst(i).name);
    fullfileHere = fullfile(folder, lst(i).name);
    mov = tiffRead(fullfileHere);
    mov = correctLineShift(mov);
    tiffWrite(mov, lst(i).name, folder);
end