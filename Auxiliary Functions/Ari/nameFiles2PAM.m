function fileName = nameFiles2PAM(acqName,sliceNum,channelNum,movieNum)
%defaultNameFiles.m Creates default file name 


switch channelNum
    case 1 
        channelName = 'green';
    case 2
        channelName = 'red';
    otherwise
        error(sprintf('No name for channel %d',channelNum));
end

fileName = sprintf('%s_%03d_Plane%03d_%s.tif', acqName, movieNum, sliceNum, channelName);