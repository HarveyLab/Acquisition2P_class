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
        function ajp = acq2pJobProcessor(jobDir, debug)
            if nargin==2
                ajp.debug = debug;
            end
            
            ajp.jobDir = jobDir;
            ajp.logFileName = fullfile(jobDir, 'acqJobLog.txt');
            
            ajp.run;            
        end
    end
end