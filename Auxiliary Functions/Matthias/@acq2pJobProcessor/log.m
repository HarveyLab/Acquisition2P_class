function log(ajp, msg)
% Writes log message to the command line and to disk.

% Log if we're in debug mode:
if ajp.debug
    msg = ['DEBUG MODE: ', msg];
end

% Log which computer we're on:
[~, host] = system('hostname');
host = strtrim(host);

% Combine information into tabular form:
msgFull = sprintf('%s\t%s\t%s\t%s\n', ...
    datestr(now, 'yymmdd HH:MM:SS'), ...
    host, ...
    ajp.currentAcq.acqName, ...
    msg);

% Write to command line:
fprintf('%s', msgFull);

% Write to log file:
success = false;
try
    fid = fopen(ajp.logFileName, 'a');
    success = true;
catch err
    if strcmp(err.identifier, 'MATLAB:badfid_mx')
        warning('Couldn''t open log file. Will try again once, then proceed without logging.');
        pause(60); % Wait a minute to let network connection reset.
    else
        rethrow(err)
    end
end

% Try again if writing to log file failed (probably due to intermittent
% network error).
if ~success
    try
        fid = fopen(ajp.logFileName, 'a');
    catch err
        if strcmp(err.identifier, 'MATLAB:badfid_mx')
            warning('Retry failed. Proceeding without writing to log file.');
        else
            rethrow(err)
        end
    end
end

if success
    fprintf(fid, '%s\n', msgFull);
    fclose(fid);
end