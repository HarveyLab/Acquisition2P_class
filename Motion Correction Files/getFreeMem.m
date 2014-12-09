function free = getFreeMem
%MONITOR_MEMORY grabs the memory usage from the feature('memstats')
%function and returns the amount (1) in use, (2) free, and (3) the largest
%contiguous block.

memtmp = regexp(evalc('feature(''memstats'')'),'(\w*) MB','match'); 
memtmp = sscanf([memtmp{:}],'%f MB');
% in_use = memtmp(1);
free = memtmp(2);
% largest_block = memtmp(10);
end