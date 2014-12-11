function populateMovieList(obj,firstMov) 
    %Function to add all movies with same base name to the Movies field,
    %using the addMovie method for error checking
    [movDir, movName movExt] = fileparts(firstMov);
    movName = [movName,movExt];

    trueCounters = [];
    potentialCounters = find(movName == '1');
    for pcount = potentialCounters
        if movName(pcount-2:pcount-1) == '00'
            trueCounters(end+1) = pcount;
        end
    end

    nCounters = length(trueCounters);
    tempName = movName;
    for c1=1:999
        idxCounter1 = trueCounters(1)-2:trueCounters(1);
        tempName(idxCounter1) = sprintf('%03.0f',c1);
        if nCounters>1
            for c2=1:999
                idxCounter2 = trueCounters(2)-2:trueCounters(2);
                tempName(idxCounter2) = sprintf('%03.0f',c2);
                fullMovie = fullfile(movDir,tempName);
                try 
                    obj = addMovie(obj,fullMovie);
                catch
                    break
                end 


            end
            if c2 == 1
                display(sprintf('Stopped at %s',tempName)),
                break
            end                    
        elseif nCounters == 1
            fullMovie = fullfile(movDir,tempName);
            try
                obj = addMovie(obj,fullMovie);
            catch
                display(sprintf('Stopped at %s',tempName)),
                break
            end
        end
    end
    if isempty(obj.acqName) %if there is not currently a name for the acquisition object
        obj.acqName = movName(1:trueCounters(1)-3);
        if obj.acqName(end) == '_'
            obj.acqName(end) = [];
        end
    end
end