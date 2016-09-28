folder = '\\harvey-rotScope-scanimage\C\data\Matthias\MM102\MM102_160730';

oldStr = 'MM102_160730_depthstart_00002';
newStr = 'MM102_160730_main_00001';

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

