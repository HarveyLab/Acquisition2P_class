classdef acq2pJobProcessor < handle
    properties
        debug = false;
        dir
        logFileName
        currentAcq
        currentAcqFileName
        nameFunc
        
    end
    
    properties (Hidden = true, Access = protected)
       flagStop = false; 
    end
    
    methods
        % Constructor:
        function ajp = acq2pJobProcessor(jobDir, debug, isExitAfterOneJob, nameFunc)
            if ~exist('nameFunc','var')
                ajp.nameFunc = [];
            else
                ajp.nameFunc = nameFunc;
            end
            if ~exist('isExitAfterOneJob','var') || isempty(isExitAfterOneJob)
                isExitAfterOneJob = false;
            end
            if nargin==2
                ajp.debug = debug;
            end
            
            % Define directory names:
            ajp.dir.jobs = jobDir;
            ajp.dir.inProgress = fullfile(jobDir, 'inProgress');
            ajp.dir.done = fullfile(jobDir, 'done');
            ajp.dir.error = fullfile(jobDir, 'error');
            
            ajp.logFileName = fullfile(jobDir, 'acqJobLog.txt');
            
            ajp.run(isExitAfterOneJob);            
        end
    end
end