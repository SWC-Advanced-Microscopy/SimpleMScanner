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

	%Set up a listener to pull in data when they are available
	addlistener(s,'DataAvailable', @plotData); 	% Add a listener to get data back from this channel


	%define analog output channels
	s.addAnalogOutputChannel(DeviceID,0:1,'Voltage'); % Add analog two output channels for scanners:  0 is x and 1 is y



	%- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
	% BUILD THE GALVO WAVEFORMS
	yWaveform = linspace(galvoAmp,-galvoAmp,imSize^2); % Y waveform is:

	xWaveform = linspace(-galvoAmp, galvoAmp, imSize); % One line of X
	xWaveform = repmat(xWaveform,1,length(yWaveform)/length(xWaveform)); % All the X lines

	dataToPlay = [xWaveform(:),yWaveform(:)]; %Assemble the two waveforms into an N-by-2 array




	%- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
	% PREPARE TO ACQUIRE
	fps = sampleRate/length(dataToPlay);
	fprintf('Scanning with a frame size of %d by %d at %0.2f frames per second\n',imSize,imSize,fps)

	%The output buffer is re-filled when it becomes half empty
	s.NotifyWhenScansQueuedBelow = round(length(yWaveform)*0.5); 

	%This listener tops up the output buffer
	addlistener(s,'DataRequired', @(src,event) src.queueOutputData(dataToPlay));

	s.IsContinuous = true; %needed to provide continuous behavior
	s.queueOutputData(dataToPlay); %queue the first frame
	
	s.NotifyWhenDataAvailableExceeds=size(dataToPlay,1); %Pull in the data when the frame has been acquired


	%- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
	% SET UP THE FIGURE WINDOW THAT WILL DISPLAY THE DATA
	hFig=clf;



	%- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
	% START!
	set(hFig,'CloseRequestFcn', @(~,~) figCloseAndStopScan(s,hFig)); %Run a function that stops the acquisition when the figure window closes
	s.startBackground %start the acquisition in the background
	fprintf('Close window to stop scanning\n')




	function plotData(src,event)
		%For convenience we nest this callback in the main function body. It therefore
		%shares the same scope as the main function
		
		%This function is called every time a frame is acquired
		x=event.Data; % x is a vector (the NI card obviously doesn't know we have a square image)

		if length(x)<=1 %sometimes there are no data. If so, bail out.
			return
		end

		im = reshape(x,imSize,imSize); %Reshape the data vector into a square image
		im = rot90(im); %So the fast axis (x) is show along the image rows
		im = -im; %because the data are negative-going

		set(hIm,'CData',im);
		set(imAx,'CLim',[0,AI_range]);
 	end %plotData


end %scanAndAcquire




%-----------------------------------------------
% The following functions are not nested within the main function body
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

