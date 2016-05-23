function scanAndAcquire_Minimal(DeviceID)
% Minimal code needed to acquire data from one channel of a 2-photon microscope
%
% function scanAndAcquire_Minimal(DeviceID)
%
% Purpose
% Stripped down code containing the minimum necessary to get data out of a 2p microscope
% All parameters are hard-coded within the function to keep code short and focus on the 
% DAQ stuff. No Pockels blanking, all the waveform is used, etc.
%
%
% Instructions
% Simply call the function with device ID of your NI acquisition board. 
% Quit by closing the window showing the scanned image stream.
%
%
% Inputs
% hardwareDeviceID - a string defining the device ID of your NI acquisition boad. Use the command
%                    "daq.getDevices" to find the ID of your board.
%
%
% Example
% The following example shows how to list the available DAQ devices and start
% scanAndAcquire_Polished using the ID for the NI PCI-6115 card with the default. 
% scanning options. 
%
% >> daq.getDevices
%
% ans = 
%
% Data acquisition devices:
%
% index Vendor Device ID          Description          
% ----- ------ --------- ------------------------------
% 1     ni     Dev1      National Instruments PCI-6115
% 2     ni     Dev2      National Instruments PCIe-6321
% 3     ni     Dev3      National Instruments PCI-6229
%
% >> scanAndAcquire_Minimal('Dev1')
% 
%
%
% Rob Campbell - Basel 2015


	% Scan parameters
	galvoAmp   = 2 ;     % Galvo amplitude (actually, this is amplitude/2). Increasing this increases the area scanned (CAREFUL!)
	imSize     = 256 ;   % Number of pixel rows and columns. Increasing this value will decrease the frame rate and increase the resolution.
	sampleRate = 128E3 ; % Increasing the sampling rate will increase the frame rate (CAREFUL!)
	AI_range = 2; % Digitise over +/- this range. This is a setting we are unlikely to change often

	%- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
	% CONNECT TO THE HARDWARE
	s=daq.createSession('ni'); %Create a session using NI hardware
	s.Rate = sampleRate;  % The sample rate is fixed, so changing it will alter the frame rate

	AI=s.addAnalogInputChannel(DeviceID, 'ai0', 'Voltage');	%Add an analog input channel for the PMT signal
	AI.Range = [-AI_range,AI_range];

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
	

	%Determine when to read in the data
	addlistener(s,'DataAvailable', @plotData); 	% Add a listener to get data back from this channel
	s.NotifyWhenDataAvailableExceeds=size(dataToPlay,1); %Pull in the data when the frame has been acquired


	%- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
	% SET UP THE FIGURE WINDOW THAT WILL DISPLAY THE DATA
	hFig=clf;
	hIm=imagesc(zeros(imSize)); %keep a handle to the image plot object
	imAx=gca;
	colormap gray
	set(imAx,'XTick',[], 'YTick',[], 'Position',[0,0,1,1]) %Fill the window
	axis square


	%- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
	% START!
	set(hFig,'CloseRequestFcn', @(~,~) figCloseAndStopScan(s,hFig));
	s.startBackground %start the acquisition in the background
	fprintf('Close window to stop scanning\n')




	%- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
	% Nested functions follow
	function plotData(src,event)
		% This callback function is run each time one frame's worth of data have been acquired
		% It reads the data off the board and plots to screen.
		% For convenience we nest this callback in the main function body. It therefore
		% shares the same scope as the main function

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
% The following functions are not nested within the main function body and so their
% contents do not share the same scope as the main function.
function figCloseAndStopScan(s,hFig)
	%Runs on scan figure window close
	delete(hFig)
	stopAcq(s)
	
end

function stopAcq(s)
	fprintf('Shutting down DAQ connection and zeroing scanners\n')
	s.stop; % Stop the acquisition

	% Zero the scanners
	s.IsContinuous=false; %
	s.queueOutputData([0,0]); %Queue zero volts on each channel
	s.startForeground; % Set analog outputs to zero

	release(s);	% Release control of the board
end %stopAcq

