%% Using the Acquisition2P class:
%
%% -----Setup-------
% All software in the acq2P package has been extensively tested on Matlab
% 2014b. Using earlier versions may cause bugs and will certainly degrade
% appearance.

% You will need a number of functions from the harveylab helper functions
% repository, so I suggest you add the full repository to your path.

% In addition to these functions, you need to add certain folders from
% within the 'Acquisition2P_class' repository to your path. Specifically,
% the classes folder (without the @ subdirectories) and the common folder
% (with all subdirectories). You may choose to add folders from
% 'personal' as appropriate, and place custom initialization / scripts
% there.

%% Overview
% In a typical imaging experiment, we image activity at one field-of-view for some 
% duration. This FOV may be subdivided into multiple axial slices, each of which 
% consist of an arbitrary number of channels, and the data corresponding to the entire 
% 'acquisition' is a list of TIFF files named according to the user's convention, which 
% may or may not have been acquired with pauses between certain movies. If we later 
% move the sample or microscope to a new position, in this terminology we start a 
% new 'acquisition'.
% 
% For data capture within one acquisition, we almost always want to motion correct 
% all frames for each slice with respect to each other, select appropriate ROIs, and 
% extract corresponding fluorescence traces. The Acquisition2P class is designed 
% to completely manage this pipeline from raw acquisitions to traces, and nothing 
% more (i.e. no thresholding, analysis...).
% 
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
% involves functions not mentioned in this overview script. Look at the method newDir, and an 
% example of the function 'acq2server' (in selmaan's personal folder) using this method, 
% if you want to see an eample of my typical workflow, or use newDir and matlab's copyfile
% function to build your own. Alternately the acq2pJobProcessor is a class
% designed to handle automated processing of acq2p objects, very useful if
% you have masses of data to deal with. It has a readme file documenting
% usage in the @acq2pJobProcessor.

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
% (e.g. the function/algorithm to use, the channel to use as reference for 
% motion correction). If this succeeds, it assigns the object to a variable in the base 
% workspace with the name created by the automatic procedure. The function also
% outputs the object if you prefer that syntax, but having the
% initialization automatically assign the variable ensures that the
% object's internal name matches its matlab variable name. 

Acquisition2P([],@SC2Pinit);

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
% flexibly modified but here we will use defaults. The SC2Pinit by default
% selects a computationally intensive lucas-kanade based algorithm, which
% intelligently incorporates knowledge of the serially-acquired structure of
% raster-scanning data to correct for within-frame non-rigid deformations
% in addition to standard whole-frame translations. Faster algorithms are
% included or can be incorporated if within-frame correction is deemed
% unnecessary

% Note, I can't predict the name of your acquisition object, so instead I'm
% going to write 'myObj', and just replace this with...the name of your acquisition2p obj...

myObj.motionCorrect;

%% Reading data into workspace
% The Acquisition2P object now contains metainformation pertaining to both
% corrected and raw data, and we can use the readCor and readRaw methods, 
% respectively, to load them. These methods are the only methods without
% their own .m file, and they are located in the Acquisition2P file
% directly. Both only need the object and movie number as inputs, but we can
% specify additional arguments as I'll do here.

movNum = 2;
castType = 'single';
sliceNum = 1;
channelNum = myObj.motionRefChannel;
mov = readCor(myObj,movNum,castType,sliceNum,channelNum);
rawMov = readRaw(myObj,movNum,castType);
implay(cat(2,mov,rawMov)/1e3,30),

% help Acquisition2P.readCor
% help Acquisition2P.readRaw
%% Precalculations for ROI selection and trace extraction

% If you're happy with the motion corrected movies, the next step is to
% make precalculations that will be used for interactive ROI selection in
% the next step. We will calculate pixel-pixel correlations, and also save a
% large file containing the total movie information in a 16-bit binary file
% format. Note that both of these functions require re-reading the
% corrected movies from disk into memory. You can save time by
% rolling these steps into the motion correction function itself, before
% the movie is written to disk and cleared from memory, but for clarity I
% avoid that here. Note also that these functions will save very large
% files to disk, and you may want to make a habit of deleting them after
% getting your traces, since they can always be recreated from corrected movies.

% First we will calculate pixel-pixel covariances. We want to do this for
% the GCaMP signal for some slice, so be sure the following variables match
% your settings (all arguments here are optional, but provided for clarity).

sliceNum = 1; %Choose a slice to analyze
channelNum = 1; %Choose the GCaMP channel
movNums = []; %this will default to all movie files
radiusPxCov = 15; %default, may need zoom level adjustment
temporalBin = 8; %default (tested w/ 15-30hz imaging), may need adjustment based on frame rate
writeDir = []; %empty defaults to the directory the object is saved in (the 'defaultDir')

% Now call the function:
myObj.calcPxCov(movNums,radiusPxCov,temporalBin,sliceNum,channelNum,writeDir);

% Now we will create the binary file 'indexed movie' for the same
% slice and channel. 

myObj.indexMovie(sliceNum,channelNum,writeDir);

% These functions do not automatically save the Acquisition object to disk.
% I suggest you overwrite the old object with the new one as you progress with each stage, so
% that you don't have to manually enter in filenames into fields of the
% 'old' object if you load the object again in the future. The
% acquisition2P class has a save method, with optional arguments, but
% default behavior is to overwrite the acqName file in defaultDir 

%help Acquisition2P.save
myObj.save;
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

% An alternative is to use an 'activity overview image', which has been
% precalculated in the calcPxCov call. This image highlights pixels which
% share strong correlations with neighboring pixels, and can be used
% independently or shared with an anatomical image, e.g.

actImg = myObj.roiInfo.slice(sliceNum).covFile.activityImg;
% img = img/2 + actImg/2;

% Note that the reference image is only used for display purposes, and has no impact
% on the segmentation algorithm itself.

% Now start the ROI selection GUI. This tool is complex enough to have its
% own tutorial, located in the same folder as this file. Again, all
% arguments are optional, provided here just for clarity.
smoothWindow = 15; % Gaussian window with std = smoothWin/5, for displaying traces
excludeFrames = []; %List of frames that need to be excluded, e.g. if they contain artifacts
myObj.selectROIs(img,sliceNum,channelNum,smoothWindow,excludeFrames);

% Take the time to read through 'Using the ROI selection tool', and then
% select your cells. Once you've selected ROIs, be sure to save the acquisition again
myObj.save;
%% Extracting ROIs

% Now we want to get fluorescence traces from the motion corrected movies
% corresponding to each ROI. There are two options, extractROIsBin and
% extractROIsTIFF. The bin method is generally faster, but the TIFF method
% is included primarily in case the bin file has been deleted.

% extractROIs reads in the grouping information output by selectROIs, and by
% default will process all groups. Here I specify to grab only grouping
% '1' and '3', but adjust this for your usage
roiGroups = [1];

%Now get traces
[dF,traces,rawF,roiList] = extractROIsBin(myObj,roiGroups,sliceNum,channelNum);

% traces is the fluorescence signal including neuropil correction, for
% whatever subset of ROIs neuropil is specified for. rawF is the fluorescence
% signal ignoring neuropil correction, i.e. just averaging in the ROI. This
% is important because we need to use the uncorrected
% fluorescence value to calculate the F in dF/F normalization, since e.g.
% the neuropil-corrected fluorescence can take on near zero or even
% possibly negative values. The recommended means of calculating is to
% subtract the baseline of the corrected traces but divide by the baseline
% of the uncorrected traces. This is accomplished automatically in the
% extractROIs method (using a call to dFcalc), and returned as dF.


%% Pulling it all together

% If you want to see all the necessary code in one place, instead of split
% up by all the comments, this is what we just did, slightly abridged:

Acquisition2P([],@SC2Pinit);
myObj.motionCorrect;

sliceNum = 1;
channelNum = 1;
myObj.calcSeedCov([],[],[],[],sliceNum,channelNum);
myObj.indexMovie(nSlice,nChannel);
myObj.save,

myObj.selectROIs([],sliceNum,channelNum);
myObj.save,

dF = extractROIsBin(obj,roiGroups,sliceNum,channelNum);
