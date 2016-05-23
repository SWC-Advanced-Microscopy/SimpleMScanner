function scanAndAcquire_Polished(hardwareDeviceID,varargin)
% Simple function for acquiring data with a 2-photon microscope
%
% scanAndAcquire(deviceID,'param1',val1,'param2',val2,...)
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
%				 NOTE: if a TIFF  with this name already exists, data will be appended to it.
% 'scannerAmplitude'  - The amplitude of the voltage waveform. [2 by default, meaning +/- 2V]
% 'imSize'  - The number of pixels in x/y. Square frames only are produced. [256 by default.]
% 'sampleRate' - The samples/second for the DAQ to run. [256E3 by default]
% 'fillFraction' 	 - The proportion of the scan range to keep. 1-fillFraction 
%	    			   is discarded due to the scanner turn-around. [0.9 by default]
% 'samplesPerPixel'  - Number of samples per pixel. [4 by default]
% 'scanPattern'  - A string defining whether we do uni or bidirectional scanning: 'uni' or 'bidi'
%				 'uni' by default
% 'bidiPhase' - a scalar that defines the offset in pixels between the outgoing and return lines
% 			    in bidirectional scanning. 26 by default. This parameter needs changing often and is sensitive.
% 'enableHist'   - A boolean. True by default. If true, overlays an intensity histogram on top of the image.
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


	% - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
	%Parse optional arguments (varargin) using an inputParser object

	%Define the possible parameter/value pairs
	params = inputParser;
	params.CaseSensitive = false;
	params.addParameter('inputChans', 0, @(x) isnumeric(x));
	params.addParameter('saveFname', '', @(x) ischar(x));
	params.addParameter('scannerAmplitude', 2, @(x) isnumeric(x) && isscalar(x));
	params.addParameter('imSize', 256, @(x) isnumeric(x) && isscalar(x));
	params.addParameter('samplesPerPixel', 4, @(x) isnumeric(x) && isscalar(x));
	params.addParameter('sampleRate', 512E3, @(x) isnumeric(x) && isscalar(x));
	params.addParameter('fillFraction', 0.9, @(x) isnumeric(x) && isscalar(x));
	params.addParameter('scanPattern', 'uni', @(x) ischar(x));
	params.addParameter('bidiPhase', 26,  @(x) isnumeric(x) && isscalar(x));
	params.addParameter('enableHist', true, @(x) islogical (x) || x==0 || x==1);

	%Process the input arguments in varargin using the inputParser object we just built
	params.parse(varargin{:});

	%Extract values from the inputParser
	inputChans = params.Results.inputChans;
	saveFname =  params.Results.saveFname;
	amp = params.Results.scannerAmplitude;
	imSize = params.Results.imSize;
	samplesPerPixel = params.Results.samplesPerPixel;
	sampleRate = params.Results.sampleRate;
	fillFraction = params.Results.fillFraction;
	scanPattern = params.Results.scanPattern;
	bidiPhase = params.Results.bidiPhase;
	enableHist = params.Results.enableHist;

	if ~strcmpi(scanPattern,'bidi')
		bidiPhase=[];
	end
	% - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 



	%- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
	% CONNECT TO THE HARDWARE

	%Create a session (using NI hardware by default)
	s=daq.createSession('ni');
	s.Rate = sampleRate;


	%Add one or more analog input channels for the PMT signals
	AI=s.addAnalogInputChannel(hardwareDeviceID, inputChans, 'Voltage'); 
	AI_range = 2; % Digitise over +/- this range
	for ii=1:length(AI)
		AI(ii).Range = [-AI_range,AI_range]; %very likely this is fine to leave hard-coded like this.
	end

	%Add a listener to get data back after each frame
	addlistener(s,'DataAvailable', @plotData); 

	%Add analog two output channels for scanners 0 is x and 1 is y
	s.addAnalogOutputChannel(hardwareDeviceID,0:1,'Voltage'); 



	%- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
	% BUILD THE GALVO WAVEFORMS (using function in "private" sub-directory)
	dataToPlay = generateGalvoWaveforms(imSize,amp,samplesPerPixel,fillFraction,scanPattern); 
	%We want at least 250 ms of data in the queue, to be really certain don't we hit buffer underflows and the scanning stops
	secondsOfDataInQueue = length(dataToPlay)/s.Rate;
	minDataThreshold = 0.25; %Must have at least this much data in the queue
	nFramesToQueue = ceil(minDataThreshold/secondsOfDataInQueue);
	dataToPlay = repmat(dataToPlay,nFramesToQueue ,1); %expand queued data accordingly
   
	msOfDataInQueue = round( (length(dataToPlay)/s.Rate)*1000 );
	fprintf('There is %d ms of data in the output queue ', msOfDataInQueue)
	if nFramesToQueue>1
		fprintf('(queuing in blocks of %d frames)',nFramesToQueue)
	end
	fprintf('\n')

	%- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
	% PREPARE TO ACQUIRE
	fps = s.Rate/length(dataToPlay);
	fps = fps * nFramesToQueue;
	fprintf('Scanning with a frame size of %d by %d at %0.2f frames per second\n',imSize,imSize,fps)

	%The output buffer is re-filled when it becomes half empty
	s.NotifyWhenScansQueuedBelow = round(length(dataToPlay)*0.5); 

	%This listener tops up the output buffer
	addlistener(s,'DataRequired', @(src,event) src.queueOutputData(dataToPlay));

	s.IsContinuous = true; %needed to provide continuous behavior
	s.queueOutputData(dataToPlay); %queue the first frame

	%Pull in the data when each frame has been acquired
	s.NotifyWhenDataAvailableExceeds=length(dataToPlay)/nFramesToQueue; %when to read back




	%- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
	% SET UP THE FIGURE WINDOW THAT WILL DISPLAY THE DATA

	%We will plot the data on screen as they come in
	hFig=clf;


	for ii=1:length(inputChans)
		h(ii).imAx=subplot(1,length(inputChans),ii); %This axis will house the image
		h(ii).hAx=imagesc(zeros(imSize)); %blank image
		set(h(ii).hAx,'Tag',sprintf('ch%02d',inputChans(ii)))

		if enableHist
			%Create axis into which we will place a histogram of pixel value intensities
			pos = get(h(ii).imAx,'Position');
			pos(3) = pos(3)*0.33;
			pos(4) = pos(4)*0.175;
			h(ii).histAx = axes('Position', pos);
		else
			h(ii).histAx=0;
		end
	end

	%Tweak settings on axes and figure elemenents
	set([h(:).imAx], 'XTick',[], 'YTick', [], 'CLim',[0,AI_range]) %note: we store the AI_range here

	colormap gray

	%- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
	% START!

	startTime=now;
	set(hFig,'CloseRequestFcn', @(~,~,~) figCloseAndStopScan(s,startTime,hFig));
	s.startBackground %start the acquisition in the background
	fprintf('Close window to stop scanning\n')

	%-----------------------------------------------


	function plotData(~,event)

		imData=event.Data;

		if size(imData,1)<=1
			fprintf('No data\n')
			return
		end

		%Average all points from the same pixel
		downSampled(:,1) = mean(reshape(imData(:,1),[],samplesPerPixel),2); 
		if size(imData,2)>1
			downSampled = repmat(downSampled,1,size(imData,2));
			for chan=2:size(imData,2)
				downSampled(:,chan) = mean(reshape(imData(:,chan),[],samplesPerPixel),2); 
			end
		end

		%External function call to function in private directory
		plotImageData(downSampled,h,saveFname,bidiPhase)

 	end %plotData


end %scanAndAcquire

function figCloseAndStopScan(s,startTime,hFig)
	%Runs on scan figure window close
	delete(hFig)
	stopAcq(s,startTime)
	
end

function stopAcq(s,startTime)
	fprintf('Acquired %0.1f seconds of data\n',(now-startTime)*60^2*24)
	fprintf('Zeroing AO channels\n')
	s.stop;
	s.IsContinuous=false;
	s.queueOutputData([0,0]);
	s.startForeground;

	fprintf('Releasing NI hardware\n')
	release(s);
end %stopAcq
