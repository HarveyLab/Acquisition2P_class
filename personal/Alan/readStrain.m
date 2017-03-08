function [ strain, frames, scale ] = readStrain(  )
%This reads the strain gauge output and the frame grabber output and
%truncates both to the frames that are captured.
%[strain,frames,strainScale] = readStrain();

%% ask user to choose h5 file
[filename,pathname,~] = uigetfile('*.h5');


%% read out strain and frame grabber
output = h5read(strcat(pathname,filename),'/sweep_0001/analogScans'); %choose h5 file
strain = output(:,1);
frames = output(:,2);
first = find(frames>25,1,'first');
last = find(frames>25,1,'last');
strain = strain(first:last);
frames = frames(first:last);

%% making time scale based on acquisition sample rate
samplerate = h5read(filename,'/header/Acquisition/SampleRate');
scale = 0:1/samplerate:((numel(strain)-1)/samplerate);

end

