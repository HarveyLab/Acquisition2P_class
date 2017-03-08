function [ Force, Length, Frames, Trigger, scale] = readAurora(  )
%This reads the channels recorded in h5 files where data from the Aurora Scientific length and force instrument has been used.



%% ask user to choose h5 file
filename = uigetfile('*.h5');

ws.loadDataFile


%% making time scale based on acquisition sample rate
samplerate = h5read(filename,'/header/Acquisition/SampleRate');
scale = 0:1/samplerate:((numel(strain)-1)/samplerate);

numSweeps = h5read(filename,'/header/NSweepsPerRun');




%% read out strain and frame grabber

for i = 1:numSweeps

    output = h5read(filename,'/sweep_0001/analogScans'); %choose h5 file
    strain = output(:,1);
frames = output(:,2);
first = find(frames>25,1,'first');
last = find(frames>25,1,'last');
strain = strain(first:last);
frames = frames(first:last);



end
