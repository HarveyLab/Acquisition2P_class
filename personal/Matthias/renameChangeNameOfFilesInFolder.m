folder = '\\research.files.med.harvard.edu\Neurobio\HarveyLab\Matthias\data\imaging\raw\MM085\MM085_151128';

oldStr = 'MM085_151128_VESSEL_002';
newStr = 'MM085_151128_MAIN_001';

lst = dir(fullfile(folder, '*.tif'));

for f = lst(:)'
    if isempty(strfind(f.name, oldStr))
        continue
    end
    newName = strrep(f.name, oldStr, newStr);
    newFullName = fullfile(folder, newName);
    oldFullName = fullfile(folder, f.name);
    java.io.File(oldFullName).renameTo(java.io.File(newFullName));
    fprintf('Renamed %s to %s.\n', f.name, newName);
end

