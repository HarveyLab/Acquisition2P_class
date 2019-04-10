classdef ScanImageTiffReader < handle
    % ScanimageTiffReader provides fast access to the data in ScanImage Tiff.
    %
    % ScanImage stores different kinds of metadata.  Configuration data and
    % frame-varying data are stored in the image description tags
    % associated with each image plane in the Tiff.  Additionally, we store
    % some metadata in another data block within the tiff.  This metadata
    % is usually a binary-blob that encodes data that needs to be
    % interpreted by scanimage.    
    
    properties(Access=private)
        h_ % A pointer to the internal file context.
    end
    
	methods(Static)
		function out=apiVersion()
			out=mexScanImageTiffReaderAPIVersion;
		end
	end

    methods
        function obj=ScanImageTiffReader(filename)
            % obj=ScanimageTiffReader(filename)
            % Opens the file
            obj.h_=uint64(0);
            if(nargin>0)
                open(obj,filename);
            end
        end
        
        function delete(obj)
            % delete(obj)
            % Closes the file.
            close(obj);
        end
        
        function obj=open(obj,filename)
            % obj=open(filename)
            % Opens the file.  If this object already refers to an open
            % file, it is closed before opening the new one.
            if(obj.h_)
                close(obj)
            end
            obj.h_=mexScanImageTiffOpen(filename);
        end
                      
        function obj=close(obj)
            % obj=open(filename)
            % Closes the file.
            if(~obj.h_), return; end
            h=obj.h_;
            obj.h_=uint64(0);
            mexScanImageTiffClose(h);
        end
        
        function tf=isOpen(obj)
            % tf=isOpen(obj)
            % returns true if the file is open, otherwise false.
            tf=obj.h_~=0;
        end
        
        function desc=descriptions(obj)
            % desc=descriptions(obj)
            % Returns the image description for each frame in a cell array.
            ensureOpen(obj);
            desc=mexScanImageTiffImageDescriptions(obj.h_);
        end
        
        function desc=metadata(obj)
            % desc=metadata(obj)
            % Returns the metadata as a byte string
            ensureOpen(obj);
            desc=mexScanImageTiffMetadata(obj.h_);
        end
        
        function stack=data(obj)
            % stack=data(obj)
            % Returns the data in the tiff as a stack.
            ensureOpen(obj);
            stack=mexScanImageTiffData(obj.h_);
        end
    end
    
    methods(Access=private)
        function ensureOpen(obj)
            if(~obj.h_)
                error('File is not open for reading.');
            end
        end
    end
end