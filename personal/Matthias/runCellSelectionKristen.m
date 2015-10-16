function runCellSelectionKristen(acq)

dirTemp = fullfile('C:\data\Matthias\imaging\processed', acq.acqName);
acq2tempDir(acq, dirTemp);
acq.selectROIs(getOverviewImg(acq));