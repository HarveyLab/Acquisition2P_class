%% Using the ROI selection tool

% This guide explains how to use the ROI selection tool contained within the acq2P framework
% The tool is designed to work optimally with a dual-monitor setup,
% although that is not strictly necessary. The tool is designed to handle
% selection of ROIs using semi-automated pixel-pixel correlation based
% algorithms, assignment of ROIs into various user-defined groupings, and
% correction for contamination of single-cell traces by various noise
% sources (i.e. 'neuropil' correction) using individualized ROI fits, as
% well as offering interactive trace examination tools for semi-automatic
% and/or manually defined ROIs to determine signal quality.

%% Theory of Operation

% The gist of ROI selection is to identify 'sources' of
% fluorescence in your acquisition (cell bodies, processes, etc.). A source
% of fluorescence should cause changes in pixel intensity correlated across
% multiple pixels. This source may or may not be visible in a reference
% image, such as a mean projection (e.g. a dendrite that briefly lights up across a FOV). 
% Additionally, visible objects in a mean projection may or may not be viable sources.
% (e.g. a cell that is silent). Empirically, there is often substantial 
% deviation between sources and visible objects, and it is often not
% trivial to identify truly silent cells, due to neuropil contamination
% creating artifactual transients in a silent cell's trace.

% The ideal means of identifying sources would be to scroll through every
% frame of an acquisition and identify neighboring pixels that light up simultaneously.
% Since this is unreasonably labor intensive, we have approximated this
% step by calculating covariances of neighboring pixel's timeseries with
% each other. We can then use a segmentation algorithm, specifically
% normalized cuts followed by kmeans, to divide pixels into a user-defined
% number of clusters. Each cluster is chosen to maximize the ratio of each pixels average
% correlation that is preserved within its cluster. We do NOT attempt to
% determine the number of clusters automatically; determining this number is one of the
% primary user tasks. The number of clusters corresponds to the number of
% 'cuts' made by the algorithm: one cut creates two clusters, each
% additional cut adds a cluster. The number of clusters should be adjusted
% to match the approximate number of sources, e.g. 2 cells and 2 dendritic
% processes would require 4 cuts, leading to 5 clusters (4 sources and one
% 'neuropil' region). The user is aided in determining appropriate clusters
% by a number of features for comparing fluorescence traces from proposed
% clusters, utilizing methods for rapidly extracting timeseries from very
% large datasets (specifically, memory mapping of uncompressed binary files
% organized in pixel-major format). Clusters can also be defined manually,
% and examined using the same interactive features.

% As appropriate clusters are selected, we also obtain a 'neuropil'
% cluster, corresponding to a region without prominent sources. This
% cluster can be used to correct for contamination of nearby sources'
% signals by out-of-focus sources. Exploiting the sparsity of neural
% activity (in L2/3 of mamallian neocortex at least), we can examine the
% joint timeseries of a source and nearby neuropil and create a linear
% predictor of source fluorescence as a function of neuropil fluorescence,
% using a robust-fit algorithm which is insensitive to brief transients in
% the source signal. This predicted fluorescence encapsulates contamination
% of the source signal, and by subtracting it from the raw source signal we
% obtain a signal approximating flourescence changes due exclusively to the
% source itself, i.e. signal not predictable from background intensity.
% Empirically, the robust fit algorithm is very accurate, but tools for visual
% examination of a neuropil-source intensity scatter plot and comparison of
% raw and subtracted traces provide verification, and interactive
% modification of the fit parameters when desired.

% ROIs corresponding to individual sources (whether defined
% semi-automatically or manually) as well as their  neuropil-pairing and
% correction-coefficients if desired can then be saved within the
% acquisition2P object. Since the user may be selecting different types of
% sources (e.g. cells in a FOV with a labeled subset) and will have
% accumulated information on varying signal quality via the interactive
% tools, each ROI can be saved with a specific grouping, enabling selective
% extraction and/or identification of user-defined ROI groups in later
% analysis.

%% Getting Started

% I will assume you have read the general tutorial up through calling the
% selectROIs method, copied below:

myObj.selectROIs(img,sliceNum,channelNum,smoothWindow,excludeFrames);

% This will open two new windows: the first, titled 'ROI Selection', will
% be maximized on one of your monitors. The second, called 'tracePlotsGUI,
% is a grouping of 4 figures, and will be docked near the matlab command
% line. Undock the entire grouping (e.g. Click on this figure grouping and
% press Ctrl+Shift+U). The first time the tool is used, you will have to
% arrange the figures in the tracePlotsGUI to fit your monitor setup and
% preferences, as described below. Subsequently, this configuration is
% tracked by MATLAB, and the figure grouping will be initialized according to
% the last used arrangement. A standard arrangement in our lab is to full
% screen the tracePlotsGUI window on a second monitor, and then arrange the
% four figures within the grouping in either a 2x2 or 4x1 pattern,
% depending on monitor orientation, using the 'tile' option in the upper right
% of the figure grouping window. But you can arrange these figures in
% any way you see fit, so experiment.

%% Typical Workflow

% Starting with the main 'ROI Selection' figure, you should see an image
% titled 'overview' showing potential ROIs from your acquisition.
% The basic workflow is to click on a presumed cell location in this
% overview image, which will load precalculated information about
% neighboring pixels into memory, and then to use a number of interactive
% features to refine your ROI selection. 

% Zoom in to an image region with cell bodies, and then click on a cell
% (the zoom tool must be disabled for a click to register). The
% neighborhood near the clicked point on the overview image will turn
% slightly pink, useful for keeping track of where the user has previously
% looked for cells. 

% After a brief lag, the 8 subplots to the left of the overview image should become
% populated and titled. 6 plots correspond to the first 6 proposed 'cuts'
% in the segmentation algorithm; contrast in each plot represents proposed
% segmentation. The upper right subplot provides information on the current
% number of cuts used, as well as the resulting clusters. The plot below
% this shows a zoom-in of the overview image in greyscale, with the
% currently selected cluster overlayed in orange, existing ROIs in green,
% and overlap between the two in red.

% At this point, the number of cuts used should be adjusted using the mouse
% scroll wheel, using both the cut plots and the resulting clusters for
% evaluation. The tab key may be used to cycle the current ROI selection
% through the current clustering results. Additionally, a manual ROI can be
% defined by pressing the 'm' key, which initiates drawing of a polygon on
% the overview image. On completion, this manual ROI placed on top of the current
% clustering results in the subplot display, and is deleted if the number
% of cuts is further adjusted.

% The following keypresses allow interactive examination of clustering results and
% neuropil fits, each corresponding to one of the tracePlotsGUI figures
% (note the ROI Selection figure must be selected for these keypresses to
% register)
% 'f' - plots traces for all current clusters to 'Cluster Traces' (this
%       feature can be called automatically, at the expense of some lag, by
%       checking the 'auto load' box in the bottom left of the window
% 't' - plots raw fluorescence traces for the currently selected ROI to
%       'Raw Trace Overlays'. Additional ROIs can be selected and the
%       number of cuts can be adjusted, each additional press will add the
%       current ROI to the trace plot. This plot is reset only when a new
%       click occurs on the overview image (or the 'c' key is pressed)
% 'space' - Selects the current ROI as a source, and initiates selection of
%       a corresponding neuropil region. The user then cycles through ROIs
%       to select a neuropil before pressing space a second time. After the
%       second press, two plots are created. 'Neuropil-sub Scatter' plots
%       the fluorescence of the neuropil (x) vs the source (y), displays
%       the fitted linear coefficient in the title, and overlays a red line
%       corresponding to this fit. 'Neuropil-sub Traces' shows the dF/F
%       trace for the selected source after neuropil subtraction according
%       to the current fit. This trace (in orange) can be compared to the
%       non-subtracted trace (in blue) by checking the 'Raw Plot' box in
%       the figure bottom left. Additionally, the fit-coefficient can be
%       adjusted by using the scroll wheel while the 'Neuropil-sub Scatter'
%       figure is selected (hold the control key to make coarser
%       adjustments). This updates the coefficient, line overlay, and
%       orange 'subtracted' trace in real time for visualization.

% After examination, ROIs can be saved by pressing a number key from
% 1-9. This keypress is only registered if either the 'ROI Selection' or
% the 'Neuropil-sub Scatter' figures are selected.
% If a neuropil pairing has been selected, and the zoomed-in
% subplot title still reads 'This pairing loaded', the ROI will be saved
% along with its neuropil and fitted coefficient. Otherwise, only the
% curent ROI is saved (the title will be reset if a new ROI or cut number
% is selected). The ROI will be assigned the grouping corresponding
% to the digit pressed. If an ROI is saved accidentally, or you change your
% mind immediately after saving, press 'delete' to get rid of the most
% recent one (a better option is available for less recent ROIs).
       
% Once saved, a patch object is overlayed on the overview image
% corresponding to the ROI, color corresponding to grouping number. 
% This patch object persists indefinitely, and can be used to modify and/or
% delete the object. Right clicking on the patch opens a menu allowing the
% ROI to be deleted, the grouping number to be changed, or the neuropil-sub
% trace and scatter plot for that ROI to be displayed (if it was saved w/ a
% neuropil pairing)

% The ROI selection tool modifies the corresponding acq2P object as it is
% used, so the GUI can be exited at anytime by closing any one of the plot
% windows. However the updated acq2P object needs to be saved to disk. If
% you just want to update the file in its default directory, call:

myObj.save,

%% Expected Results

% If it's not clear how things are 'supposed' to look, I've included
% example screenshots (.tif) of the GUI in action in the same directory as this
% help file
%
% 'ex ROI Selection' - I've clicked on a cell which I think could be
%       a source, and adjusted the number of cuts to 4, which resulted in a
%       reasonable segmentation of the region into two previously selected
%       ROIs (yellow + orange clusters), an unidentified process (light blue),
%       a large region of 'neuropil' (dark blue), and my targeted cell
%       (green).
%  'ex Raw Trace Overlay' - I've plotted the raw cell body trace from the last
%       figure in orange on top of the neuropil trace, using the 't'
%       keypress, and zoomed in to a particularly problematic region of the
%       trace, showing a mix of 'true' signal (where orange increases
%       without blue) and contamination (where blue and orange co-modulate)
% 'ex Neuropil-sub Scatter' - I've selected the cell from the last figure
%       and paired it with the surrounding neuropil. The scatter plot shows
%       that many points in the joint timeseries lie on a line, with occasional excursions from this
%       line. The robust fit algorithm has estimated the slope of this
%       line as neuropil fluorescence * 0.723 (plus an irrelevent intercept) equals
%       cell body fluorescence, and plots this in red over the scatter.
%       Empirically, coefficients often lie between 0.5 and 1.1 or so.
% 'ex Neuropil-sub Traces' - The 'space' keypresses used to produce the scatter also
%       produce the subtracted trace plot here. The subtracted dF/F trace
%       is overlayed on the un-subtracted dF/F trace, and I've zoomed in to
%       the same region as the 'Raw Trace Overlay' image. The subtracted
%       trace isolates signal increases not shared between cell body and
%       neuropil, decreases background variation, and increases the SNR.