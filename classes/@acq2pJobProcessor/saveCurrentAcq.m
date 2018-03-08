function saveCurrentAcq(ajp)
% Saves the current acq both in its default dir and in the inProgress dir.

try
    % Rename acq object before saving:
    if verLessThan('matlab', 'R2014a')
        acqVarName = genvarname(ajp.currentAcq.acqName);
    else
        acqVarName = matlab.lang.makeValidName(ajp.currentAcq.acqName);
    end
    eval(sprintf('%s=ajp.currentAcq;', acqVarName));
    
    % Save in acq's default dir:
    save(fullfile(ajp.currentAcq.defaultDir, [ajp.currentAcq.acqName, '_acq.mat']), ...
        acqVarName);
    
    % Save in inProgress dir:
    save(fullfile(ajp.dir.inProgress, ajp.currentAcqFileName), ...
        acqVarName);
    
    ajp.log('Saving updated Acq2P object.');
catch err
    msg = sprintf('Attempt to save acq2p failed: %s', err.message);
    ajp.log(msg);
    printStack(ajp, err.stack);
end