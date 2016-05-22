function cleanUp
% Example - run a sub-function automatically when the caller function ends
%
% function cleanUp
%
% Purpose
% Demo of how to run a sub-function when the caller function ends. 
% The "cleanUp" function will run even if the caller crashes.
%
% Rob Campbell - Basel 2015
%
% see: http://blogs.mathworks.com/loren/2008/03/10/keeping-things-tidy/
%
% See also windowCloseFunction

%Define a cleanup object that will release the DAQ gracefully
tidyUp = onCleanup(@cleanUpFunction);

fprintf('Press ctrl-C to abort')
	
while 1
	pause(0.5)
	fprintf('.')
end


%-----------------------------------------------
function cleanUpFunction
	fprintf('\n\nTidying up.\n\n')
