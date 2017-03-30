%{
This script creates a test environment to quickly test new or changed
motion correction functions.
%}

%% Load raw data:
a = MM102_160825_main;
acq = a.acq;

[mov, si] = tiffRead('\\research.files.med.harvard.edu\Neurobio\HarveyLab\Matthias\data\imaging\raw\MM102\MM102_160825\MM102_160825_MAIN_00001_00008.tif');
mov = correctLineShift(double(mov));
[movStruct, nSlices, nChannels] = parseScanimageTiff(mov, si);

%% Identify motion:
movStruct = lucasKanade_plus_nonrigid(acq, movStruct, si, 8, 'identify');
disp('Done identifying.')

%% Apply motion correction:
movStructCorrected = lucasKanade_plus_nonrigid(acq, movStruct, si, 8, 'apply');
meanCorr = mean(movStructCorrected.slice(1).channel(1).mov, 3);
meanUncorr = nanmean(movStruct.slice(1).channel(1).mov, 3);
disp('Done applying.')

%% Compare results:
figure(1)
imagesc(acq.motionRefImage.slice(1).img)
colormap(gray)
axis equal
title('Reference')

figure(2)
imagesc(meanCorr)
colormap(gray)
axis equal
title('Corrected')

figure(3)
imagesc(acq.motionRefImage.slice(1).img-meanCorr)
colormap(gray)
axis equal
title('Difference')

figure(4)
imagesc(meanUncorr)
colormap(gray)
axis equal
title('Uncorrected')

%% Correct whole session:
a = MM104_160730_main;
a.acq.defaultDir = 'G:\mcTest';
a.acq.Movies = changeDir(a.acq.Movies, '\\research.files.med.harvard.edu\Neurobio\HarveyLab\Matthias\data\imaging\raw\MM104\MM104_160730');
a.acq.correctedMovies = [];
a.acq.derivedData = [];
a.acq.motionCorrectionFunction = @lucasKanade_plus_nonrigid;
a.acq.motionCorrect

