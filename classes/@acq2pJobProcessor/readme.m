%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Help file for acq2pJobProcessor class.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% INTRODUCTION:
%
% acq2pJobProcessor (aka ajp) is a tool for automatic processing (motion
% correction, binary movie file and pixel covariance calculation) of
% Acquisition2p (aka acq2p) objects. While ajp is running, it keeps
% checking a user-defined "to-do directory" for unprocessed acq2p objects
% and starts processing any acq2ps that it finds.

% USAGE:
myJobDir = 'Z:\HarveyLab\Selmaan\Behavior Imaging\AcqsToDo'; % User-defined directory containing unprocessed acq2p objects.
ajp = acq2pJobProcessor(myJobDir);

% HOW TO SUPPLY ACQ2P OBJECTS:
%
% To add acq2p objects to the processing queue, create them with your
% personal acq2p initialization function and save them in myJobDir. Make
% sure that all paths in the acq2p (tiff files, default dir...) are
% accessible from the computer running ajp. The most convenient solution is
% to read/write all files from/to the server, rather than using the local
% disk of the computer running ajp. If everything is read and written on
% the server, then it doesn't matter which computer does the processing and
% you will not need to collect your files from the processing computer
% later. ajp is designed such that you can run it on several computers
% simultaneously, using the same jobsToDo folder for all (must be on the
% server, of course). Different computers will then process different
% acq2ps from myJobDir. IMPORTANT: When using folders on the server, always
% use full network paths, e.g.
% "\\research.files.med.harvard.edu\neurobio\HarveyLab\myFolder...". DO NOT
% use paths with a drive letter such as "W:\myFolder..." because they will
% be different on different computers. This goes for all paths in acq2p and
% ajp and everything else that you intend to be portable across different
% computers.

% HOW TO STOP AJP:
%
% Press Ctrl-C.

% WHAT WILL HAPPEN WHEN AJP RUNS:
%
% ajp will keep checking myJobDir for new acq2p files. When it finds one,
% ajp will first move the acq2p file to the "inProgress" directory
% (subfolder of myJobDir; will be created if necessary). This prevents ajps
% running on different computers from processing the same acq2p. ajp will
% then perform the following processing, using the settings stored in the
% acq2p object:
% 
% 1. Motion correction
% 2. Creation of binary movie file.
% 3. Calculation of pixel covariances.
%
% After each step, the updated acq2p object is saved both in the
% "inProgress" directory and in the defaultDir of the acq2p object. If the
% processing finishes successfully, the acq2p object is moved into a folder
% called "done" (subfolder of myJobDir; will be created if necessary). If
% there is an error at any stage of the processing, the acq2p object will
% be moved to a folder called "error" (subfolder of myJobDir; will be
% created if necessary), such that the user can analyze what went wrong.

% LOGGING AND ERROR HANDLING:
%
% All major steps in the processing will be logged in a text file called
% acqJobLog.txt in myJobDir. The file contains the following tab-delimited
% columns:
% 
% 1. Date and time
% 2. Host computer name
% 3. acq2p.acqName of the acq2p that was being processed when the log
% message was written.
% 4. Log message
%
% If an error happens during processing, it is caught. The error stack
% (incl. line numbers) is then written to the log file. ajp then proceeds
% with the next processing step of the current acq2p or next acq2p file in
% myJobDir.

% SYSTEM REQUIREMENTS:
%
% AJP requires the repositories "helperFunctions" and "Acquisition2P_class"
% from the HarveyLab github account to be on the path. AJP has only been
% tested on Matlab 2014b.

% ADVANCED FUNCTIONS:
%
% Ajp accepts optional inputs for advanced customization. Look at function
% files to see how it works:
% ajp = acq2pJobProcessor(jobDir, debug, shouldContinue, nameFunc)

% Ask Matthias in case of problems.

% CHANGE LOG for this file:
% 141228 Written by Matthias (github: mjlm).
