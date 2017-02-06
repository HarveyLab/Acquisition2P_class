classdef Acquisition2P < handle
    %Class definition file for Acquisition2P class
    %Includes constructer methods, and functions for reading raw (readRaw) or
    %corrected (readCor) tiff's associated with acquisition
    %
    %obj = Acquisition2P;
    %obj = Acquisition2P('acqName');
    %Acquisition2P('acqName',@myInitFun);
    
    properties
        %At present all of these properties can be freely modified by the user
        acqName             %Name of the acquisition, used for saving metadata and variable in worksapce
        dateCreated         %Date the acquisition was created
        defaultDir          %Default directory for saving motion corrected data and metadata
        Movies = {};        %Cell array containing full filepaths to raw movie data
        metaDataSI          %Metadata structure derived from scanimage tiff file
        binFactor           %Spatial bin of pixels, defaults to 1
        motionRefChannel    %Channel to use for identifying motion correction, defaults to 1 in constructer
        motionRefMovNum     %Movie to which other movies will be aligned during motion correction
        motionCorrectionFunction %Function handle for motion correction function
        motionRefImage      %Reference image from above movie
        derivedData         %Structure in slice.channel format for maintaining useful information (e.g. mean images)
        shifts              %Slice.channel structure containing output of motion correction
        correctedMovies     %Structure formatted by slice and channel, each containing a cell array of filenames
        indexedMovie        %Structure formatted by slice and channel, each containing filename for mat file
        syncInfo            %Empty structure for adding synchronization information relevant to acquisition
        roiInfo             %Slice structure containing rois and related calculations
    end
    
    methods
        %Note, most methods defined in seperate files
        function obj = Acquisition2P(varargin)
            %Constructs new Acq instance
            %Can be passed with zero arguments to create a blank object and
            %bypass safety checks
            %Otherwise two optional arguments can be provided, the first a
            %string specifying the acquisition name, the second a handle to
            %an initialization function. The init function must create an
            %acquisition name if it is not provided as first argument.
            %After running initialization function, constructer checks all
            %fields necessary for motion correction, fills in blanks with
            %defaults when possible and otherwise raises warnings for
            %missing fields. If passing an initialization function with
            %multiple arguments, pass a cell array with the function handle
            %as the first element, the second argument as the object or as
            %empty to fill in the object, and additional arguments as
            %subsequenct elements. Ex. {@initFunc,[],arg1,arg2}
            
            if nargin == 0
                warning('Blank Acquisition Object Created'),
                return
            elseif nargin == 1
                obj.acqName = varargin{1};
            elseif nargin == 2
                obj.acqName = varargin{1};
                initFunction = varargin{2};
                if iscell(initFunction)
                    if isempty(initFunction{2})
                        initFunction{2} = obj;
                    end
                    feval(initFunction{:});
                else
                    initFunction(obj);
                end
            else
                error('Unsupported number of input arguments'),
            end
            
            %Check necessary fields and fill in defaults
            if isempty(obj.acqName)
                error('Acquisition Unnamed')
            end
            if isempty(obj.defaultDir)
                warning('Default Directory needs to be specified')
            end
            if isempty(obj.motionRefChannel)
                display('Setting motion correction channel to 1'),
                obj.motionRefChannel = 1;
            end
            if isempty(obj.motionRefMovNum)
                display('Setting reference movie to 1'),
                obj.motionRefMovNum = 1;
            end
            if isempty(obj.binFactor)
                display('Setting binFactor to 1'),
                obj.binFactor = 1;
            end
            if ~isa(obj.motionCorrectionFunction,'function_handle')
                warning('Motion Correction will fail without valid function handle')
            end
            
            %Fill in date created field
            obj.dateCreated = date;
        end       
        
        function [movie, metaMovie] = readRaw(obj,movNum,castType)
            %Reads in raw data from an acquisition
            %
            % [movie, metaMovie] = readRaw(obj,movNum,castType)
            if ~exist('castType', 'var') || isempty(castType)
                castType = 'int16';
            end
            [movie, metaMovie] = tiffRead(obj.Movies{movNum},castType);
        end
        
        function movie = readCor(obj,movNum,castType,sliceNum,chanNum)
            %Reads in motion corrected data from an acquisition. Defaults
            %to slice 1 channel 1 if none specified
            %
            % movie = readCor(obj,movNum,castType,sliceNum,chanNum)
            if isempty(obj.correctedMovies)
                error('This Acquisition Object is not Associated with Motion Corrected Data')
            end
            if ~exist('castType', 'var') || isempty(castType)
                castType = 'int16';
            end
            if ~exist('sliceNum', 'var') || isempty(sliceNum)
                sliceNum = 1;
            end
            if ~exist('chanNum', 'var') || isempty(chanNum)
                chanNum = 1;
            end
            movName = obj.correctedMovies.slice(sliceNum).channel(chanNum).fileName{movNum};
            movie = tiffRead(movName,castType);
        end
    end
    
end