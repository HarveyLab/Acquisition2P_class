classdef acq2pJobProcessor < handle
    properties
        debug = false;
        jobDir
        logFileName
        currentAcq
        
    end
    
    properties (Hidden = true, Access = protected)
       flagStop = false; 
    end
    
    methods
        % Constructor:
        function ajp = acq2pJobProcessor(jobDir, debug, shouldContinue)
            if ~exist('shouldContinue','var') || isempty(shouldContinue)
                shouldContinue = true;
            end
            if nargin==2
                ajp.debug = debug;
            end
            
            ajp.jobDir = jobDir;
            ajp.logFileName = fullfile(jobDir, 'acqJobLog.txt');
            
            ajp.run(shouldContinue);            
        end
    end
end