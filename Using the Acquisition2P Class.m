%% Using the Acuisition2P class:
%
%% -----Setup-------
% You will need only two functions outside the class, both from the
% harveylab github account, if you don't already have them. The functions
% are 'tiffRead' and 'tiffWrite'. If you don't want to use the harvey lab
% versions for some reason, just make sure your personal version provides the same
% metadata, in the same format.

% In addition to these functions, you need to add the 'Acquisition2P_class'
% folder to your path (NOT the '@Acquisition2P' folder), as well as
% the "common" directory (with all subdirectories). You can add personal functions 
% to you own folder in the "personal" directory.

%% Overview
% In a typical imaging experiment, we image activity at one field-of-view for some 
% duration. This FOV may be subdivided into multiple axial slices, each of which 
% consist of an arbitrary number of channels, and the data corresponding to the entire 
% 'acquisition' is a list of TIFF files named according to a the user's convention, which 
% may or may not have been acquired with pauses between certain movies. If we later 
% move the sample or microscope to a new position, in this terminology we start a 
% new 'acquisition'.
% 
% For data capture within one acquisition, we almost always want to motion correct 
% all frames for each slice with respect to each other, select appropriate ROIs, and 
% extract corresponding raw fluorescence traces. The Acquisition2P class is designed 
% to completely manage this pipeline from raw acquisitions to traces, and nothing 
% more (i.e. no dF/F, thresholding, analysis...).
% 
% The general idea is that the processing pipeline is hard-coded into the class 
% properties/methods, but particulars (e.g. naming formats, the specific algorithm for 
% motion correction used) are flexible and user-modifiable outside the class structure.  
% Hopefully this allows easy sharing of code and data and provides a standard for 
% long-term storage of metadata, without being overly fascistic about particular details 
% of how a user names, organizes, or processes their data.
% 
% The code below is a simple step-by-step script illustrating how you can use the class 
% on a group of raw files stored on a local hard drive. Moving Acquisition2P objects, 
% from a rig to a server or a server to an analysis computer is straightforward, but 
% involves functions not mentioned in this overview script. Look at the method newDir, and an 
% example of the auxiliary function 'acq2server' using this method, if you want to see 
% an eample of my typical workflow, or use newDir and matlab's copyfile
% function to build your own.

%% Initialize an Acquisition2P object

% Acquisitions can be constructed a number of ways, fully documented in the
% .m file. The most typical way is to pass a handle to an initialization
% function. Here, I use the SC2Pinit initialization function, which is provided 
% as an example for what initialization is supposed to do. Once you
% understand how it works, you can design your own initialization function
% to match whatever naming/organizing convention you already use.

% The function is commented in detail, but basically it allows graphical 
% user selection of a group of files, uses the filenames to name a new
% acquisition2P object, adds the selected files to the object as raw data,
% and fills in properties of the object necessary for motion correction
% (e.g. the function/algorithm to use, the channel to use as reference). If
% this succeeds, it assigns the object to a variable in the base workspace
% with the name created by the automatic procedure. The function also
% outputs the object if you prefer that syntax, but having the
% initialization automatically assign the variable ensures that the
% object's internal name matches its matlab variable name. If passing an
% initialization function with multiple arguments, pass a cell array with
% the function handle as the first element, the second argument as the
% object or as empty to fill in the object, and additional arguments as
% subsequenct elements. Ex. {@initFunc,[],arg1,arg2}

Acquisition2P([],@SC2Pinit);

% Acquisition2P([],{@SC2Pinit,[],arg1,arg2});

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
% flexibly modified but here we will use defaults.

% Note, I can't predict the name of your acquisition object, so instead I'm
% going to write 'myObj', and just replace this with...the name of your acquisition obj...

myObj.motionCorrect;

%% Reading data to workspace
% The Acquisition2P object now contains metainformation pertaining to both
% corrected and raw data, and we can use the readCor and readRaw methods, 
% respectively, to load them. These methods are the only methods without
% their own .m file, and they are located in the Acquisition2P file
% directly. Both only need the object and movie number as inputs, but we can
% specify additional argument as I'll do here.

movNum = 2;
castType = 'single';
sliceNum = 1;
channelNum = myObj.motionRefChannel;
mov = readCor(myObj,movNum,castType,sliceNum,channelNum);
rawMov = readRaw(myObj,movNum,castType);

%% Precalculations for ROI selection and trace extraction

% If you're happy with the motion corrected movies, the next step is to
% make precalculations that will be used for interactive ROI selection in
% the next step. We will calculate pixel-pixel correlations, and also save a
% large file containing the total movie information in a 16-bit binary file
% format. Note that both of these functions require re-reading the
% corrected movies from disk into memory. You can save a lot of time by
% rolling these steps into the motion correction function itself, before
% the movie is written to disk and cleared from memory, but for clarity I
% avoid that here. Note also that these functions will save very large
% files to disk, and you may want to make a habit of deleting them after
% getting your traces, since they can always be recreated from corrected movies.

% First we will calculate pixel-pixel covariances. We want to do this for
% the GCaMP signal for some slice, so be sure the following variables match
% your settings (all arguments here are optional, but provided for clarity).
% Make sure you have plenty of free RAM before calling this function!

sliceNum = 1; %Choose a slice to analyze
channelNum = 1; %Choose the GCaMP channel
movNums = []; %this will default to all movie files
seedBin = 4; %default, may need adjustment based on zoom level
radiusPxCov = 10.5; %default, may need zoom level adjustment
temporalBin = 8; %default, may need adjustment based on frame rate
writeDir = []; %empty defaults to the directory the object is saved in (the 'defaultDir')

% Now call the function:
myObj.calcSeedCov(movNums,radiusPxCov,seedBin,temporalBin,sliceNum,channelNum,writeDir);

% Now we will create the binary file 'indexed movie' for the same
% slice and channel. 

myObj.indexMovie(sliceNum,channelNum,writeDir);

% These functions do not automatically save the Acquisition object to disk.
% I suggest you overwrite the old object with the new one as you progress with each stage, so
% that you don't have to manually enter in filenames into fields of the
% 'old' object if you load the object again in the future. 

save(fullfile(myObj.defaultDir,myObj.acqName),'myObj'),
%% ROI selection

% Now we can use these files to select ROIs. We can call the selectROIs
% method without input arguments, but again for clarity I will define some
% inputs here

% Use the built-in function meanRef to get a mean reference image, then
% process its square root with adaptive histogram equalization. Since this
% empirically produces nice looking images, this is actually the default
% behavior if no reference image is passed to the function call, so the
% code below is redundant but provided for demonstration

img = myObj.meanRef;
img(img<0) = 0;
img(isnan(img)) = 0;
img = sqrt(img);
img = adapthisteq(img/max(img(:)));

% Now start the ROI selection GUI. Most details for how to use it are in the .m
% file, or I can explain it in person. Important quirks: select ROIs roughly
% up and down the columns of the image, before moving laterally along the
% rows, to maximize the rapid loading benefit of memory mapping. Also, if
% your movie is really big, check your free RAM while you use the tool.
% Memory mapping can potentially fill up your RAM cache, which wont cause
% anything to crash but loading traces may slow down. If your RAM is full, and you
% are getting slow loads, just close the GUI window and reopen it,
% which will initialize a new cache (progress is automatically saved so
% closing the window doesn't disrupt the process). I don't actually know if
% this is necessary though, so don't obsess about it unless it obviously
% speeds things up!
myObj.selectROIs(img,sliceNum,channelNum);

% Save again to include ROI info...
save(fullfile(myObj.defaultDir,myObj.acqName),'myObj'),
%% Extracting ROIs

% Now we want to get fluorescence traces from the motion corrected movies
% corresponding to each ROI. There are two options; if you have just
% finished ROI selection (so movie information is still stored in the RAM
% cache) or if your movie is comparable to your RAM size (doesn't all have to
% fit though!), the extractROIs function uses the memory-mapped binary file
% to process data much quicker than reading in TIFFs. On the other hand, if
% your movie is huge and no movie data is in the cache, extractROIsTIFF
% will do the job safely/consistently, and is vectorized as matrix multiplication
% for speed, though you do have to load in all TIFF files in order. Here, I
% will assume you just finished selecting ROIs and use the 'fast' function,
% but feel free to experiment.

% extractROIs reads in the grouping information output by selectROIs, and by
% default will process all groups. Here I specify to grab only grouping
% '1' and '3', but adjust this for your usage
roiGroups = [1,3];

%Now get traces
[traces,rawF,roiList] = extractROIs(obj,roiGroups,sliceNum,channelNum);

% traces is the fluorescence signal including neuropil correction, for
% whatever subset of ROIs neuropil is specified for. rawF is the fluorescence
% signal ignoring neuropil correction, i.e. just averaging in the ROI. This
% is important to return ALWAYS because we need to use the uncorrected
% fluorescence value to calculate the F in dF/F normalization, since e.g.
% the neuropil-corrected fluorescence can take on near zero or even
% possibly negative values. So e.g. to get your dF/F:
F_level = prctile(rawF,10,2);
dF = bsxfun(@rdivide,traces,F_level);
dF = bsxfun(@minus,dF,median(dF,2));


%% Pulling it all together

% If you want to see all the necessary code in one place, instead of split
% up by all the comments, this is what we just did, slightly abridged:

Acquisition2P([],@SC2Pinit);
myObj.motionCorrect;

sliceNum = 1;
channelNum = 1;
myObj.calcSeedCov([],[],[],[],sliceNum,channelNum);
myObj.indexMovie(nSlice,nChannel);

myObj.selectROIs([],sliceNum,channelNum);
save(fullfile(obj.defaultDir,obj.acqName),'myObj'),

[traces,rawF,roiList] = extractROIs(obj,roiGroups,sliceNum,channelNum);
