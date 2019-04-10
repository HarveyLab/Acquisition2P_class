%% Using the Acuisition2P class:


%% Overview
% NOTE: this file is part of a *reduced* complexity version of the Acq2P
% software, simplified to handle only file handling and motion correction. See the 'master'
% branch of the following repo to get full codebase, which includes source
% extraction as well as all motion correction capabilities included here:
% https://github.com/HarveyLab/Acquisition2P_class/tree/master

% The general idea is that the processing pipeline is hard-coded into the class 
% properties/methods, but particulars (e.g. naming formats, initializations, the specific algorithm for 
% motion correction used) are flexible and user-modifiable outside the class structure.  
% Hopefully this allows easy sharing of code and data and provides a standard for 
% long-term storage of metadata, without being overly fascistic about particular details 
% of how a user names, organizes, or processes their data.
% 
% The code below is a simple step-by-step script illustrating how you can use the class 
% on a group of raw files stored on a local hard drive. Moving Acquisition2P objects, 
% from a rig to a server or a server to an analysis computer is straightforward, but 
% involves functions not mentioned in this overview script. Look at the method 'newDir', and an 
% example of the function 'acq2server' using this method, if you want to see an example of my typical workflow, 
% or use newDir and matlab's copyfile function to build your own. Alternately the acq2pJobProcessor is a class
% designed to handle automated processing of acq2p objects, very useful if
% you have masses of data to deal with. It has a readme file documenting
% usage in the @acq2pJobProcessor.

%% Initialize an Acquisition2P object

% Acquisitions can be constructed a number of ways, fully documented in the
% Acquisition2P.m file. The most typical way is to pass a handle to an initialization
% function. Here, I use the 'initSC' initialization function, which is provided 
% as an example for what initialization is supposed to do. Once you
% understand how it works, you can design your own initialization function
% to match whatever naming/organizing convention you already use.

% The function is commented in detail, but basically it allows graphical 
% user selection of a group of files, uses the filenames to name a new
% acquisition2P object, adds the selected files to the object as raw data,
% and fills in properties of the object necessary for motion correction
% (e.g. the motion correction function/algorithm to use, the channel to use as reference for 
% motion correction). If this succeeds, it assigns the object to a variable in the base 
% workspace with the name created by the automatic procedure. The function also
% outputs the object if you prefer that syntax, but having the
% initialization automatically assign the variable ensures that the
% object's internal name matches its matlab variable name. 

Acquisition2P([],@initSC); %this returns a *handle* to the object, i.e. all edits to any copy of this var apply to all versions


% The Acquisition2P constructer has a series of error checks to ensure that
% necessary properties are not left blank by accident. Practically, this
% means that with whatever custom initialization function you use, the code
% will automatically check to see if fields are provided. If they are not,
% it will issue a warning, and either fill in the field with a default
% value or alert the user to manually fill the field. (For hardcore users,
% you can bypass these error checks using a different constructer syntax)

%% Motion Correction

% Now we can motion correct the acquisition. The motionCorrect method takes
% optional arguments we wont use here, since all necessary information has
% been provided by the initialization. It's going to read in each movie serially,
% motion correct it first within-file, then align that file to the master
% reference file, apply the shifts with a single interpolation call, and
% write the result to disk in a folder in the raw data directory called
% 'Corrected'. These files will correspond to splitting each original file
% into independent slices and channels, and will all be TIFFs. The
% filenames of all these files will be recorded in the 'correctedMovies'
% field of the object for hassle-free reading of the data later

% The motion correction algorithm and write locations can be
% flexibly modified but here we will use defaults. "initSC" by default
% selects a computationally intensive lucas-kanade based algorithm, which
% intelligently incorporates knowledge of the serially-acquired structure of
% raster-scanning data to correct for within-frame non-rigid deformations
% in addition to standard whole-frame translations, and further uses a
% hierarchical sequence of non-linear warping to correct for long timescale
% sample deformation. Faster algorithms are
% included or can be incorporated if simpler procedures are appropriate for
% the data

% Note, I can't predict the name of your acquisition object, so instead I'm
% going to write 'obj', and just replace this with...the name of your acquisition2p obj...

obj.motionCorrect;

% Note: an important assumption of the software is that data from
% acquisitions are split into multiple smaller files, so that we can
% approximate long-timescale non-rigid deformations as approximately
% constant within a file, and independent across files. This is reasonable
% for typical settings on the harvey lab microscopes (e.g. 1,000
% frames-per-file, at 30fps). The code is not designed to work well for acquisitions
% written entirely to a single file, but it should be robust on the order
% of 500-5,000 frames per file.

%% Reading data into workspace
% The Acquisition2P object now contains metainformation pertaining to both
% corrected and raw data, and we can use the readCor and readRaw methods, 
% respectively, to load them. These methods are the only methods without
% their own .m file, and they are located in the 'Acquisition2P.m' file
% directly. Both only need the object and movie number as inputs, but we can
% specify additional arguments as I'll do here.

movNum = 2;
castType = 'single';
sliceNum = 1;
channelNum = obj.motionRefChannel;
mov = readCor(obj,movNum,castType,sliceNum,channelNum);
rawMov = readRaw(obj,movNum,castType);
implay(cat(2,mov,rawMov)/1e3,30),

% help Acquisition2P.readCor
% help Acquisition2P.readRaw

% Acq2P uses a super efficient tiff reading utility provided by the
% scanimage team. This reader is called by a light wrapper function
% 'tiffRead'. In the future, it's possible this func will need to be
% updated, but it works on most systems as tested on April 2019.

%% Further utilities

%'viewAcq' is a handy utility function for creating highly sped-up movies
%for an entire acquitision. It outputs an intensity-normalized movie, as
%well as a trace of average fluorescence values before normalization
nSlice = []; %defaults to 1
nChannel = []; %defaults to 1
[mov, mF] = viewAcq(obj,nSlice,nChannel)

% 'acq2server' demonstrates how to use Acq2P's newDir and matlab copyfile
% functions to process data and move it around. This is much more effective than
% copy/pasting things around in windows, without decrease in transfer
% speeds! It has default locations which should be changed for individual
% users, however these are only used if fileDestination is unspecified
fileDestination = ; % where the data should go on the server
rawTransfer = 1; % logical, if we should transfer the raw data
acq2server(obj,fileDestination,rawTransfer)

% 'eventTriggeredMovie' demonstrates how to create an event-average movie by
% rapidly/efficiently loading motioncorrected data. See documentation for
% use:
[avgMov, dFmov] = eventTriggeredMovie(obj,avgMovFrames,nSlice,nChannel)

% Acq2P objects have an overloaded 'save' function to save an object from workspace.
% to disk. The object is automatically saved after motionCorrection, or
% after file transfer when using the 'newDir' method, but it can be
% manually called when needed:
