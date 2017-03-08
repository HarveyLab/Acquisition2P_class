function [ h5struct ] = readWSfile(  )
%This adds the uigetfile to wavesurfer's built in loadDataFile.


%% ask user to choose h5 file
filename = uigetfile('*.h5');
h5struct = ws.loadDataFile(filename);

end
