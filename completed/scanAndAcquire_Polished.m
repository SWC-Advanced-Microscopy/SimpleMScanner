function scanAndAcquire_Polished(hardwareDeviceID,varargin)
% Simple function for acquiring data with a 2-photon microscope
%
% Purpose
% A relatively complete function for simple two-photon scanning
%
% Details
% The X mirror should be on AO-0
% The Y mirror should be on AO-1
% No Pockels blanking and all the waveform is used.
%
% Inputs (required)
% hardwareDeviceID - string defining the ID of the DAQ device 
%					 see daq.getDevices for finding the ID of your device.
%
% Inputs (optional, supplied as param/value pairs)
% 'inputChans' - A vector defining which input channels will be used to acquire data 
%  				[0 by default, meaning channel 0 only is used to acquire data]
% 'saveFname'  - A string defining the relative or absolute path of a file to which data should be written. 
%                Data will be written as a TIFF stack. If not supplied, no data are saved to disk. 
% 'amplitude'  - The amplitude of the voltage waveform. [2 by default, meaning +/- 2V]
% 'frameSize'  - The number of pixels in x/y. Square frames only are produced. [256 by default.]
% 'sampleRate' - The samples/second for the DAQ to run. [256E3 by default]
% 'fillFraction' 	 - The proportion of the scan range to keep. 1-fillFraction 
%	    			   is discarded due to the scanner turn-around. [0.9 by default]
% 'samplesPerPoint'  - Number of samples per pixel. [1 by default]
%
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
% >> scanAndAcquire_Polished('Dev1')
% 
%
% TWO
% acquire data on channels 0 and 2
% scanAndAcquire('Dev1','inputChans',[0,2])
%
% Rob Campbell - Basel 2015


	if nargin<1
		help(mfilename)
		return
	end

	if ~ischar(hardwareDeviceID)
		fprintf('hardwareDeviceID should be a string\n')
		return
	end




	%Define a cleanup object that will release the DAQ gracefully when the user presses ctrl-c
	tidyUp = onCleanup(@stopAcq);



	% - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
	%Parse optional arguments (varargin) using an inputParser object

	%Define the possible parameter/value pairs
	params = inputParser;
	params.CaseSensitive = false;
	params.addParamValue('inputChans', 0, @(x) isnumeric(x));
	params.addParamValue('saveFname', '', @(x) ischar(x));
	params.addParamValue('amplitude', 2, @(x) isnumeric(x) && isscalar(x));
	params.addParamValue('frameSize', 256, @(x) isnumeric(x) && isscalar(x));
	params.addParamValue('samplesPerPoint', 1, @(x) isnumeric(x) && isscalar(x));
	params.addParamValue('sampleRate', 256E3, @(x) isnumeric(x) && isscalar(x));
	params.addParamValue('fillFraction', 0.9, @(x) isnumeric(x) && isscalar(x));

	%Process the input arguments in varargin using the inputParser object we just built
	params.parse(varargin{:});

	%Extract values from the inputParser
	inputChans = params.Results.inputChans;
	saveFname =  params.Results.saveFname;
	amp = params.Results.amplitude;
	linesPerFrame = params.Results.frameSize; 
	pointsPerLine = params.Results.frameSize;
	samplesPerPoint = params.Results.samplesPerPoint;
	sampleRate = params.Results.sampleRate;
	fillFraction = params.Results.fillFraction;
	% - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 


	verbose=0;

	%Set up TIFF saving if needed
	if ~isempty(saveFname)
		tiffWriteParams={'tiff',   ...
						'Compression', 'None', ... %Don't compress because this slows IO
	    				'WriteMode', 'Append'};
	end




	%- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
	% CONNECT TO THE HARDWARE

	%Create a session (using NI hardware by default)
	s=daq.createSession('ni');


	%Add an analog input channel for the PMT signal
	AI=s.addAnalogInputChannel(hardwareDeviceID, inputChans, 'Voltage'); 
	for ii=1:length(AI)
		AI(ii).Range = [-2,2]; %very likely this is fine to leave hard-coded like this.
	end


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
	yWaveform = linspace(amp,-amp,samplesPerLine*linesPerFrame);

	%Produce the X waveform
	xWaveform = linspace(-amp, amp, samplesPerLine);
	xWaveform = repmat(xWaveform,1,length(yWaveform)/length(xWaveform));

	%Assemble the two waveforms into an N-by-2 array
	dataToPlay = [xWaveform(:),yWaveform(:)];
	if verbose
		fprintf('Data waveforms have length %d\n',size(dataToPlay,1))
	end
	



	%- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
	% PREPARE TO ACQUIRE

	%The sample rate is fixed, so we report the frame rate
	s.Rate = sampleRate;
	frameRate = length(yWaveform)/sampleRate;


	fprintf('Scanning %d by %d frames at %0.2f frames per second\n', linesPerFrame, pointsPerLine, 1/frameRate)

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
	for ii=1:length(inputChans)
		imAx(ii)=subplot(1,length(inputChans),ii); %This axis will house the image
		hAx(ii)=imagesc(zeros(linesPerFrame,pointsPerLine)); %blank image

		%Create axis into which we will place a histogram of pixel value intensities
		pos = get(imAx(ii),'Position');
		pos(3) = pos(3)*0.33;
		pos(4) = pos(4)*0.175;
		histAx(ii) = axes('Position', pos);
	end

	%Tweak settings on axes and figure elemenents
	set(imAx, 'XTick',[], 'YTick', [])
	colormap gray



	%- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
	% START!
	s.startBackground %start the acquisition in the background

	%Block. User presses ctrl-C to to quit, this calls stopAcq
	while 1
		pause(0.1)
	end


	%-----------------------------------------------
	function stopAcq
		if ~exist('s','var')
			return
		end

		fprintf('Zeroing AO channels\n')
		s.stop;
		s.IsContinuous=false;
		s.queueOutputData([0,0]);
		s.startForeground;

		fprintf('Releasing NI hardware\n')
		release(s);
	end %stopAcq


	function plotData(src,event)
		xData=event.Data;

		if size(xData,1)<=1
			fprintf('No data\n')
			return
		end

		for chan = 1:size(xData,2)
			x=xData(:,chan);
			x=decimate(x,samplesPerPoint);

			if correctedPointsPerLine * linesPerFrame ~= size(x,1)
				fprintf('Can not reshape vector of length %d to a %d by %d matrix\n',size(x,1), correctedPointsPerLine, linesPerFrame)
				return
			end
			im=reshape(x,correctedPointsPerLine,linesPerFrame);
			im=im(end-pointsPerLine:end,:); %trim
			im=rot90(im);
			im=im*-1; %because the data are negative-going

			%Update histogram on this frame
			hist(histAx(chan),im(:),30);
			set(histAx(chan),'YTick',[], 'XLim',[-0.1,2], 'Color','None', 'Box','Off');
			set(get(histAx(chan),'Children'),'EdgeColor','None','FaceColor','r')


			%Update image on this frame
			set(hAx(chan),'CData',im);
			set(imAx(chan),'CLim',[0,2]);

			if ~isempty(saveFname) %Optionally write data to disk
				if length(inputChans)>1
					thisFname = sprintf('ch%02d_%s',inputChans(chan),saveFname);
				else
					thisFname = saveFname;
				end
				imwrite(uint16(im),thisFname,tiffWriteParams{:}) %This will wipe the negative numbers (the noise)
			end

		end %for chan = 1:size(x,2)

 	end %plotData

end %scanAndAcquire