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

% Write to log file:
fid = fopen(ajp.logFileName, 'a');
fprintf(fid, '%s', msgFull);
fclose(fid);

% Write to command line:
fprintf('%s', msgFull);