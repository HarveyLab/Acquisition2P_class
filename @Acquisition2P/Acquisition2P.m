classdef Acquisition2P < handle
    
    
    properties
        %At present all of these properties can be freely modified by the user
        acqName             %Name of the acquisition, used for saving metadata and variable in worksapce
        defaultDir          %Default directory for saving motion corrected data and metadata
        Movies = {};        %Cell array containing full filepaths to raw movie data
        binFactor           %Spatial bin of pixels, defaults to 1
        motionRefChannel    %Channel to use for identifying motion correction, defaults to 1 in constructer
        motionRefMovNum     %Movie to which other movies will be aligned during motion correction
        motionCorrectionFunction %Function handle for motion correction function
        motionRefImage      %Reference image from above movie
        derivedData         %Structure in slice.channel format for maintaining useful information (e.g. mean images)
        shifts              %Slice.channel structure containing output of motion correction
        correctedMovies     %Structure formatted by slice and channel, each containing a cell array of filenames
        indexedMovie        %Structure formatted by slice and channel, each containing filename for mat file
        roiInfo             %Slice structure containing rois and related calculations
    end
    
    methods
        %TODO: Change set property so that certain properties have limited
        %values permitted
        function obj = Acquisition2P(varargin)
            %Constructs new Acq instance
            if nargin == 0
                warning('Blank Acquisition Object Created'),
                return
            elseif nargin == 1
                obj.acqName = varargin{1};
            elseif nargin == 2
                obj.acqName = varargin{1};
                initFunction = varargin{2};
                initFunction(obj);
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
        end       
        
        function [movie, metaMovie] = readRaw(obj,movNum,castType)
            %Reads in raw data from an acquisition
            if ~exist('castType', 'var') || isempty(castType)
                castType = 'uint16';
            end
            [movie, metaMovie] = tiffRead(obj.Movies{movNum},castType);
            if isfield(metaMovie,'SI4')
                metaMovie = metaMovie.SI4;
            end
        end
        
        function movie = readCor(obj,movNum,castType,sliceNum,chanNum)
            %Reads in motion corrected data from an acquisition. Defaults
            %to slice 1 channel 1 if non specified
            if isempty(obj.correctedMovies)
                error('This Acquisition Object is not Associated with Motion Corrected Data')
            end
            if ~exist('castType', 'var') || isempty(castType)
                castType = 'uint16';
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