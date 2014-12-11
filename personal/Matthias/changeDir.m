function fileList = changeDir(fileList, newDir)
% fileList = changeDir(fileList, newDir) takes a path or cell-aray of paths
% and changes the directory-part of the paths to newDir.

if ischar(fileList)
    fileList = {fileList};
end

for ii = 1:numel(fileList)
    [~, f, e] = fileparts(fileList{ii});
    fileList{ii} = fullfile(newDir, [f e]);
end