classdef selectRoisGui < handle
    properties
        % The GUI is associated with an acq2p object, and specifically one
        % slice in that object:
        acq = Acquisition2P.empty;
        slice = 1;
        
        % Structure for all handles:
        h = struct('fig', [], 'ax', [], 'img', [], 'ui', [], 'timers', []);
        
        % Disp contains all data relevant for display, such as which areas
        % have been viewed already. (Most of the fields of disp used to be
        % fields of the "gui" struct in the old GUI code.)
        disp = struct;
        
        % Memory maps to binary files::
        covMap;
        movMap;
    end
    
    properties (Dependent)
        % The roiInfo data of the GUI is identical with the roiInfo in the
        % acq object. Therefore, it is defined as a dependent property that
        % simply points to the data in the acq object.
        roiInfo;
    end
    
    methods
        % Construct gui:
        function sel = selectRoisGui(acq, img, sliceNum, channelNum, smoothWindow, excludeFrames)
            % Error checking and default arguments:
            if ~exist('img','var') || isempty(img)
                img = acq.meanRef([],sliceNum);
                img(img<0) = 0;
                img(isnan(img)) = 0;
                img = sqrt(img);
                img = adapthisteq(img/max(img(:)));
            end
            if ~exist('sliceNum','var') || isempty(sliceNum)
                sliceNum = 1;
            end
            if ~exist('channelNum','var') || isempty(channelNum)
                channelNum = 1;
            end
            if ~exist('smoothWindow','var') || isempty(smoothWindow)
                smoothWindow = 15;
            end
            if ~exist('excludeFrames','var')
                excludeFrames = [];
            end
            % Errors:
            if isempty(acq.roiInfo)
                ME = MException('selectRoisGui:inputError', 'No ROI info is associated with this Acquisition');
                throw(ME)
            elseif ~isfield(acq.roiInfo.slice(sliceNum),'covFile')
                ME = MException('selectRoisGui:inputError', 'Pixel-Pixel correlation matrix has not been calculated');
                throw(ME)
            end
            
            % Warnings:
            if isempty(acq.indexedMovie)
                warning('No indexed movie is associated with this Acquisition. Attempting to load traces will throw an error'),
            end
            
            % The constructor code is outsourced to createGui:
            sel.createGui(acq, img, sliceNum, channelNum, smoothWindow, excludeFrames);
        end
        
        % Getter and setter for roiInfo:
        function roiInfo = get.roiInfo(sel)
            roiInfo = sel.acq.roiInfo.slice(sel.slice);
        end
        function set.roiInfo(sel, value)
            selFields = fieldnames(value);
            % We assign values field by field in case some fields don't
            % exist yet in the acq object:
            for field = selFields(:)'
               sel.acq.roiInfo.slice(sel.slice).(field{:}) = ...
                   value.(field{:});
            end
        end
    end
end