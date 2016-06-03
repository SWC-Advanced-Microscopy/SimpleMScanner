function scanAndAcquire_Skeleton(DeviceID)
% Skeleton function comprised mainly of comments that indicate the steps required to acquire data from one channel of a 2-photon microscope
%
% function scanAndAcquire_Skeleton(DeviceID)
%
% Purpose
% Comments and pseudocode designed to help guide in the process of writing scanning software 
% without actually giving away too much. Useful for teaching.
%
%
%
%
% Rob Campbell - Basel 2015


	% First you will need to define some scan parameters. Below are the obvious ones. 
	% Scan parameters
	galvoAmp   = 2 ;     % Galvo amplitude (actually, this is amplitude/2). Increasing this increases the area scanned (CAREFUL!)
	imSize     = 256 ;   % Number of pixel rows and columns. Increasing this value will decrease the frame rate and increase the resolution.
	sampleRate = 128E3 ; % Increasing the sampling rate will increase the frame rate (CAREFUL!)




	% Next you will need to connect to the hardware
	s=daq.createSession('ni'); %Create a session using NI hardware

	%Set the sample rate on your hardware


	%Add an analog input channel for the PMT signal and scale it appropriately


	% Add analog two output channels for scanners:  0 is x and 1 is y
	

	%- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
	% BUILD THE GALVO WAVEFORMS

	% Use the galvo amplitude and the image size to build the x and y waveforms. 
	% For now we will start with a uni-directional raster scan. i.e. acquire data 
	% along the fast (x) axis going from left to right, then flick back to the start
	% (left side) to acquire the next line.

	yWaveform = [];  

	xWaveform = []; 

	% Assemble the two waveforms into an N-by-2 array that can be sent to  the 
	% DAQ device output buffer. You might find it helpful to plot this when developing
	% the code.
	dataToPlay = [xWaveform(:),yWaveform(:)]; 




	%- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
	% PREPARE TO ACQUIRE

	% You will need to play the waveforms continuously. This achieved
	% by topping up the output buffer as it approaches becoming empty

	% use the "NotifyWhenScansQueuedBelow" property to specify when to top up the buffer

	% Create a listener (addlistener) on the 'DataRequired' notify event to queue data to the output buffer
	% use the queueOutputData method to send data to the device

	%make the IsContinuous property true

	%queue your first batch of output data (queueOutputData)
	

	%Set up a listener on 'DataAvailable' to run plotData. This will pull in data and process it after each frame
	addlistener(s,'DataAvailable', @plotData); 	% Add a listener to get data back from this channel
	
	%set the NotifyWhenDataAvailableExceeds property to determine when you will pull in data

	%- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
	% SET UP THE FIGURE WINDOW THAT WILL DISPLAY THE DATA
	hFig=clf;



	%- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
	% START!
	set(hFig,'CloseRequestFcn', @(~,~) figCloseAndStopScan(s,hFig)); %Run a function that stops the acquisition when the figure window closes
	s.startBackground %start the acquisition in the background
	fprintf('Close window to stop scanning\n')



	%- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
	% Nested functions follow
	function plotData(src,event)
		% This will be a callback function that will run each time one frame's worth
		% of data have been acquired. 
		% For convenience we nest this callback in the main function body. It therefore
		% shares the same scope as the main function

		% Get data off the board
		x=event.Data; % x is a vector (the NI card obviously doesn't know we have a square image)

		%Error checking to ensure we have data

		%Data are a vector so reshape to form a square image


		%Plot (e.g. by setting the CData property)

 	end %plotData


end %scanAndAcquire




%-----------------------------------------------
% The following functions are not nested within the main function body and so their
% contents do not share the same scope as the main function.
function figCloseAndStopScan(s,hFig)
	%Runs on scan figure window close
	delete(hFig) %closes the figure
	stopAcq(s) %calls the stopAcq function to stop the acquisition
end

function stopAcq(s)
	fprintf('Shutting down DAQ connection and zeroing scanners\n')
	s.stop; % Stop the acquisition

	% Zero the scanners
	% <YOUR CODE HERE>


	release(s);	% Release control of the board
end %stopAcq

