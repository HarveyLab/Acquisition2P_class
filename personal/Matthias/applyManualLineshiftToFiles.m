function applyManualLineshiftToFiles(folder, fileId, lineShift)
% applyManualLineshiftToFiles(folder, fileId, lineShift) applies LINESHIFT
% to all files in FOLDER that match FILEID.

% lst = dir(fullfile(folder, [fileId '*']));
% 
% for i = 1:numel(lst)
%     fprintf('Correcting file %s...\n', lst(i).name);
%     fullfileHere = fullfile(folder, lst(i).name);
%     mov = tiffRead(fullfileHere);
%     mov = correctLineShift(mov, lineShift);
%     tiffWrite(mov, lst(i).name, folder);
% end



function getLineShift(mov)
m = mean(mov, 3);
odd = m(1:2:end, :);
even = m(2:2:end, :);
