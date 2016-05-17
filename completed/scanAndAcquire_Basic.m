function scanAndAcquire_Basic(hardwareDeviceID,saveFname)
% Basic useful 2-photon microscope acquisition for one channel: acquires nice images that can be saved to disk
%
% function scanAndAcquire_Basic(hardwareDeviceID)
%
%
% Purpose
% Acquires a 2-photon image stream from channel 1 of a DAQ card. All parameters are hard-coded within 
% the function to keep code short and focus on the DAQ stuff. This function is based on 
% scanAndAcquire_Minimal but adds the following:
%  1) Correction of the X-mirror turn-around artefact
%  2) Ability to acquire multiple samples per pixel to decrease noise
%  3) Optionally save the image stream to disk
%
% No Pockels blanking.
%
%
% Instructions
% Simply call the function with device ID of your NI acquisition board. 
% Quit with ctrl-C.
%
%
% Inputs
% hardwareDeviceID - a string defining the device ID of your NI acquisition boad. Use the command
%                    "daq.getDevices" to find the ID of your board.
% saveFname - A string defining the relative or absolute path of a file to which data should be written. 
%             Data will be written as a TIFF stack. If not supplied, no data are saved to disk. 
%
%
% Instructions
% Simply call the function. Quit with ctrl-C.
%
%
% Examples
% ONE
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
% >> scanAndAcquire_Basic('Dev1')
% 
% TWO
% Save data to a file called '2pStream.tif'
% >> scanAndAcquire_Basic('Dev1','2pStream.tif')
% 
% 
% Rob Campbell - Basel 2015


	if ~ischar(hardwareDeviceID)
		fprintf('hardwareDeviceID should be a string\n')
		return
	end

	if nargin<2
		saveFname='';
	end

	if ~ischar(saveFname)
		fprintf('The input argument saveFname should be a string. Not saving data to disk.\n')
		saveFname='';
	end

	if ~isempty(saveFname)
		tiffWriteParams={saveFname, 'tiff',   ...
						'Compression', 'None', ... %Don't compress because this slows IO
	    				'WriteMode', 'Append'};
	end



	%Define a cleanup object that will release the DAQ gracefully when the user presses ctrl-c
	tidyUp = onCleanup(@stopAcq);


	%----------------------------------
	% Scan parameters
	galvoAmp = 2; %Scanner amplitude (actually, this is amplitude/2)
	linesPerFrame = 256;
	pointsPerLine = 256;
	samplesPerPoint = 4;
	sampleRate 	= 512E3; 
	fillFraction = 0.9; %1-fillFraction is considered to be the turn-around time and is excluded from the image
	%----------------------------------


	%- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
	% CONNECT TO THE HARDWARE

	%Create a session using NI hardware
	s=daq.createSession('ni');


	%Add an analog input channel for the PMT signal
	AI=s.addAnalogInputChannel(hardwareDeviceID, 'ai1', 'Voltage');
	AI.Range = [-2,2];


	%Add a listener to get data back from this channel
	addlistener(s,'DataAvailable', @plotData); 


	%Add analog two output channels for scanners 0 is x and 1 is y
	s.addAnalogOutputChannel(hardwareDeviceID,0:1,'Voltage');





	%- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
	% BUILD THE GALVO WAVEFORMS

	% Calculate the number of samples per line. We want to produce a final image composed of
	% pointsPerLine data points on each line. However, if the fill fraction is less than 1, we
	% need to collect more than this then trim it back. 
	correctedPointsPerLine = ceil(pointsPerLine*(2-fillFraction)); %collect more points
	samplesPerLine = correctedPointsPerLine*samplesPerPoint;

	%So the Y waveform is:
	yWaveform = linspace(galvoAmp,-galvoAmp,samplesPerLine*linesPerFrame);

	%Produce the X waveform
	xWaveform = linspace(-galvoAmp, galvoAmp, samplesPerLine);
	xWaveform = repmat(xWaveform,1,length(yWaveform)/length(xWaveform));

	%Assemble the two waveforms into an N-by-2 array
	dataToPlay = [xWaveform(:),yWaveform(:)];
	fprintf('Data waveforms have length %d\n',size(dataToPlay,1))
	



	%- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
	% PREPARE TO ACQUIRE

	%The sample rate is fixed, so we report the frame rate
	s.Rate = sampleRate;
	frameRate = length(yWaveform)/sampleRate;
	fprintf('Scanning at %0.2f frames per second\n',1/frameRate)

	%The output buffer is re-filled for the next line when it becomes half empty
	s.NotifyWhenScansQueuedBelow = round(length(yWaveform)*0.5); 

	%This listener tops up the output buffer
	addlistener(s,'DataRequired', @(src,event) src.queueOutputData(dataToPlay));

	s.IsContinuous = true; %needed to provide continuous behavior
	s.queueOutputData(dataToPlay); %queue the first frame

	%Pull in the data when the frame has been acquired
	s.NotifyWhenDataAvailableExceeds=size(dataToPlay,1); %when to read back




	%- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
	% SET UP THE FIGURE WINDOW THAT WILL DISPLAY THE DATA

	%We will plot the data on screen as they come in, so make a blank image
	hFig=clf;
	hIm=imagesc(zeros(linesPerFrame,pointsPerLine));
	imAx=gca;
	colormap gray
	set(gca,'XTick',[],'YTick',[],'Position',[0,0,1,1])




	%- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
	% START!
	s.startBackground %start the acquisition in the background

	%Block. User presses ctrl-C to to quit, this calls stopAcq
	while 1
		pause(0.1)
	end


	%-----------------------------------------------
	function stopAcq
		% This function is called when the user presses ctrl-C or if the acquisition crashes
		fprintf('Zeroing AO channels\n')
		s.stop;
		s.IsContinuous=false;
		s.queueOutputData([0,0]);
		s.startForeground;

		fprintf('Releasing NI hardware\n')
		release(s);
	end %stopAcq


	function plotData(src,event)
		%This function is called every time a frame is acquired
		x=event.Data;

		if length(x)<=1
			return
		end

		x = decimate(x,samplesPerPoint); %This effectively averages and down-samples
		im = reshape(x,correctedPointsPerLine,linesPerFrame);
		im = im(end-pointsPerLine:end,:); %trim according to the fill-fraction to remove the turn-around 
		im = rot90(im); %So the fast axis (x) is show along the image rows
		im = -im; %because the data are negative-going

		set(hIm,'CData',im);
		set(imAx,'CLim',[0,2]);
		if ~isempty(saveFname) %Optionally write data to disk
			imwrite(uint16(im),tiffWriteParams{:}) %This will wipe the negative numbers (the noise)
		end

 	end %plotData

end %scanAndAcquire
