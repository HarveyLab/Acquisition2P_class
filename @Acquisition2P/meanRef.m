function ref = meanRef(obj,movNums,sliceNum,channelNum)
    % Constructs a mean reference image of an acquisition after motion 
    % correction using the derived data structure, without requiring
    % loading movie files
    %
    % ref = meanRef(obj,movNums,sliceNum,channelNum)
    %
    % movNums input can be an arbitrary index vector, or by default
    % includes all movies with derived data
    if isempty(obj.derivedData)
        error('This Acquisition is not associated with derived data')
    end
    if ~exist('movNums','var') || isempty(movNums)
        movNums = 1:length(obj.derivedData);
    end
    if ~exist('sliceNum','var') || isempty(sliceNum)
        sliceNum = 1;
    end
    if ~exist('channelNum','var') || isempty(channelNum)
        channelNum = 1;
    end
    
    %Initialize zero matrix, sum in loop over movies and normalize by number of movies summed
    ref = zeros(size(obj.derivedData(1).meanRef.slice(sliceNum).channel(channelNum).img));
    nMovies = length(movNums);
    for nMovie = movNums
        ref = ref + obj.derivedData(nMovie).meanRef.slice(sliceNum).channel(channelNum).img;
    end
    ref = ref / nMovies;
end