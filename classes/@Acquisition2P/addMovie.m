function addMovie(obj, pathToTiff) 
    %Function to add a file to the acquisition object, checking for errors
    try Tiff(pathToTiff);
        if sum(strcmp(pathToTiff,obj.Movies)) > 0
            error('Duplicate'),
        end
        obj.Movies{end+1} = pathToTiff;
    catch err
        if strcmp(err.message,'Duplicate')
            error('File %s is already part of Acquisition',pathToTiff)
        elseif exist(pathToTiff,'file') == 2
            error('File %s Exists but is not Valid',pathToTiff)
        elseif exist(pathToTiff,'file') == 0
            error('File %s Was Not Found',pathToTiff)
        else
            error('File %s Unknown Error',pathToTiff)
        end
    end
end