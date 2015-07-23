function mMov = avgMov(obj, keyFrames, frameWin)

%% Input handling

sliceNum = 1;
channelNum = 1;

%% Make memory map
movSizes = obj.correctedMovies.slice(sliceNum).channel(channelNum).size;
movLengths = movSizes(:, 3);
% if ~exist(obj.indexedMovie.slice(sliceNum).channel(channelNum).fileName, 'file')
%     error('Cannot find binary movie file at path specified in obj2p object.');
% end
% movMap = memmapfile(obj.indexedMovie.slice(sliceNum).channel(channelNum).fileName,...
%     'Format', {'int16', [sum(movLengths), movSizes(1,1)*movSizes(1,2)], 'mov'});
% movDat = movMap.Data.mov;

%% Make frame selection

keyFrames = reshape(keyFrames,1,[]);
frameWin = reshape(frameWin,1,[]);
frameSelect = repmat(keyFrames,length(frameWin),1) ...
    + repmat(frameWin',1,length(keyFrames));

%% Extract and Average over Frames
% frameSelect = reshape(frameSelect,[],1);
% tMov = nan(length(frameSelect),size(movDat,2),'single');
% tic,
% for px = 1:size(movDat,2)
%     tMov(:,px) = movDat(frameSelect,px);
% end
% toc,
% tMov = reshape(tMov,length(frameWin),length(keyFrames),size(tMov,2));
% mMov = shiftdim(squeeze(mean(tMov,2)),1);
% mMov = reshape(mMov,movSizes(1),movSizes(2),length(frameWin));
% mMov = permute(mMov,[2 1 3]);

% clear movDat,

%% Extract frames from TIFF
frameSelect = reshape(frameSelect,[],1);
framesPerMov = mode(movLengths);
fileID = ceil(frameSelect/framesPerMov);
frameID = mod(frameSelect-1,framesPerMov)+1;
tMov = nan(movSizes(1,1),movSizes(1,2),length(frameSelect),'single');

for fl = unique(fileID)'
    frames = frameID(fileID==fl);
    fName = obj.correctedMovies.slice(sliceNum).channel(channelNum).fileName{fl};
    tf = Tiff(fName);
    img = nan(movSizes(1,1),movSizes(1,2),length(frames),'single');

    for i = 1:length(frames)
        tf.setDirectory(frames(i));
        img(:,:,i) = tf.read;
    end
    
    tMov(:,:,fileID==fl) = img;
end

mMov = squeeze(mean(reshape(tMov,movSizes(1,1),movSizes(1,2),length(frameWin),length(keyFrames)),4));
