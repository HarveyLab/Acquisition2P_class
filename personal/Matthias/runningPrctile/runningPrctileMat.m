function resultArray = runningPrctileMat(dataArray, winLength, nth)

runningWindow = sort(dataArray(1:winLength));
dataArrayLength = numel(dataArray);
resultArray = dataArray;
iWinInsert = floor(winLength/2);

for iWinStart = 1:(dataArrayLength-winLength)
    iNextDataPoint = iWinStart + winLength;
    resultArray(iWinStart+iWinInsert) = runningWindow(nth+1);
    
    % Find "oldest" element:
    iOldest = ismembc2(dataArray(iWinStart), runningWindow);
    
    if iOldest==0
        iOldest = iNext;
    end
    
    iNext = find(runningWindow>=dataArray(iNextDataPoint), 1);
        
    if iOldest < iNext
        iNext = iNext-1;
        runningWindow(iOldest:iNext-1) = runningWindow(iOldest+1:iNext);
    elseif iOldest > iNext
        runningWindow(iNext+1:iOldest) = runningWindow(iNext:iOldest-1);
    end
    runningWindow(iNext) = dataArray(iNextDataPoint);
end