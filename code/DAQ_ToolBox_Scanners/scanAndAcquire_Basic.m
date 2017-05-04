function scanAndAcquire_Basic(hardwareDeviceID,saveFname)
% Basic useful 2-photon microscope acquisition for one channel: acquires nice images that can be saved to disk
%
% function scanAndAcquire_Basic(hardwareDeviceID,saveFname)
%
%
% Purpose
% This is a tutorial function. Its goal is to show the minimal possible code necessary
% to get good images from a 2-photon microscope and stream the to disk. This function 
% produces uni-directional galvo waveforms to scan the beam across the sample. It acquires data 
% from one photo-detector (a PMT or a photo-diode) through one analog input channel. 
%
% All parameters are hard-coded within the function to keep things brief and focus on how 
% the acquisition is being done. Two important parameters are added compared to scanAndAcquire_Minimal:
% 1. The "fillFraction", which is used to remove the turn-around artefact
% 2. "samplesPerPixel", which is used to average multiple samples per pixel and so improve
%    image quality. samplesPerPixel should be changed in association with "sampleRate". 
%
%
% Instructions
% Simply call the function with the device ID of your NI acquisition board. Images are streamed
% to the designated filename if a second input argument is provided. Quit by closing the 
% window showing the scanned image stream.
% The X mirror should be on AO-0
% The Y mirror should be on AO-1
%
% Inputs
% hardwareDeviceID - a string defining the device ID of your NI acquisition board. Use the command
%                    "daq.getDevices" to find the ID of your board.
% saveFname - An optional string defining the relative or absolute path of a file to which data 
%             should be written. Data will be written as a TIFF stack. If not supplied, no data 
%             are saved to disk. 
%
%
%
% Examples
% ONE
% The following example shows how to list the available DAQ devices and start
% scanAndAcquire_Basic using the ID for the NI PCI-6115 card with the default. 
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
% Requirements
% Data Acquisition Toolbox
%
% 
% Rob Campbell - Basel 2015


    if nargin==0
        %Print help and quit if no input arguments provided
        help(mfilename)
        return
    end

    %- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
    % Check input arguments
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



    %----------------------------------
    % Scan parameters
    galvoAmp = 2; % Scanner amplitude (defined as peak-to-peak/2) 
    imSize = 256; % Number pixel rows and columns
    samplesPerPixel = 4; % Number of samples to take at each pixel. These will be averaged.
    sampleRate  = 512E3; 
    fillFraction = 0.85; % 1-fillFraction is considered to be the turn-around time and is excluded from the image
    AIrange = 2; % Digitise over +/- this range. 
    invertSigal = false; % Set to true if using a non-inverting amp with a PMT
    %----------------------------------


    %- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
    % CONNECT TO THE HARDWARE
    % For details on the following see the equivalent lines in scanAndAcquire_Minimal

    s=daq.createSession('ni');
    s.Rate = sampleRate;

    AI=s.addAnalogInputChannel(hardwareDeviceID, 'ai0', 'Voltage'); % The PMT signal
    AI.Range = [-AIrange,AIrange]; % Digitize over this range of values

    %Add analog two output channels for scanners 0 is x and 1 is y
    s.addAnalogOutputChannel(hardwareDeviceID,0:1,'Voltage');


    %- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
    % BUILD THE GALVO WAVEFORMS

    % Calculate the number of samples per line taking into account the fill-fraction. 
    % The fill-fraction is the proportion of each scan line that we keep and use for 
    % image formation. scanAndAcquire_Minimal keeps the whole line. Images from that
    % function show a "turn-around artefact". This occurs when data acquired during the 
    % x-mirror fly-back are used for image formation. The purpose of the fill-fraction
    % setting is to discard these data points and leave us with a clean image. So, if
    % the fill-fraction is 0.9, we discard 10% of the X data and keep the rest. In order
    % to get the number of pixels asked for by the user regardless of the fill fraction we
    % must obtain more data than needed for the final image. Here is how we do this:

    fillFractionExcess = 2-fillFraction; % The proportional increase in scanned area along X due to the fill-fraction
    % So so it's "2-fillFraction" because what we end up doing is acquiring *more* points and trimming the back so if the 
    % user asked for 512x512 pixels this is what they end up getting.

    correctedPointsPerLine = ceil(imSize*fillFractionExcess); % Actual number of points we will need to collect

    % We also make it possible to acquire multiple samples per pixel. So must
    % multiply correctedPointsPerLine by the number of samples per pixel.
    samplesPerLine = correctedPointsPerLine*samplesPerPixel;


    % Now that we know how many samples per line we have, we can produce the X and Y 
    % waveforms as before.  For details on the following see the equivalent lines in
    % scanAndAcquire_Minimal
    yWaveform = linspace(galvoAmp,-galvoAmp,samplesPerLine*imSize);

    xWaveform = linspace(-galvoAmp, galvoAmp, samplesPerLine); 
    xWaveform = repmat(xWaveform,1,length(yWaveform)/length(xWaveform));

    dataToPlay = [xWaveform(:),yWaveform(:)];

    %Report frame rate to screen
    fps = sampleRate/length(dataToPlay);
    fprintf('Scanning with a frame size of %d by %d at %0.2f frames per second\n',imSize,imSize,fps)



    %- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
    % PREPARE TO ACQUIRE 
    % Set up for continuous acquisition and pull in data after each frame.
    % For details on the following see the equivalent lines in scanAndAcquire_Minimal

    % Re-fill output buffer when it's half empty
    s.NotifyWhenScansQueuedBelow = round(length(yWaveform)*0.5); 
    addlistener(s,'DataRequired', @(src,event) src.queueOutputData(dataToPlay));

    s.IsContinuous = true; %needed to provide continuous behavior
    s.queueOutputData(dataToPlay); %queue the first frame

    % Pull in the data when the frame has been acquired
    s.NotifyWhenDataAvailableExceeds=size(dataToPlay,1); 
    addlistener(s,'DataAvailable', @plotData);  



    %- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
    % SET UP THE FIGURE WINDOW THAT WILL DISPLAY THE DATA
    hFig=clf;
    hIm=imagesc(zeros(imSize));
    imAx=gca;
    colormap gray
    set(imAx, 'XTick',[], 'YTick',[], 'Position',[0,0,1,1]) %Fill the window
    axis square

    % Use a callback to stop the acquisition gracefully when the user closes the plot window
    set(hFig,'CloseRequestFcn', @(~,~) figCloseAndStopScan(s,hFig));



    %- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
    % START!
    s.startBackground %start the acquisition in the background
    fprintf('Close window to stop scanning\n')





    %- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
    % Nested functions follow
    function plotData(~,event)
        %This function is called every time a frame is acquired
        x=event.Data;

        if length(x)<=1
            return
        end

        %First we average together all points associated with the same pixel
        x = mean(reshape(x,samplesPerPixel,[]),1)'; 
        im = reshape(x,correctedPointsPerLine,imSize);

        % Now keep only "imSize" pixels from each row. This trims off the excess
        % That comes from fill-fractions less than 1. If the fill-fraction is chosen
        % correctly, the X mirror turn-around artefact is now gone. 
        im = im(end-imSize:end,:); 

        im = rot90(im);

        if invertSigal
            im = -im;
        end

        set(hIm,'CData',im);
        set(imAx,'CLim',[0,AIrange]);
        if ~isempty(saveFname) %Optionally write data to disk
            im = im * 2^16/AIrange ; %ensure values span 16 bit range
            im = uint16(im); %Convert to unsigned 16 bit integers. Negative numbers will be gone.
            imwrite(im, saveFname, 'tiff', ...
                    'Compression', 'None', ... %Don't compress because this slows IO
                    'WriteMode', 'Append') 
        end
    end %close plotData

end %close scanAndAcquire_Basic



%-----------------------------------------------

function figCloseAndStopScan(s,hFig)
    %Runs on scan figure window close
    fprintf('Shutting down DAQ connection and zeroing scanners\n')
    s.stop; % Stop the acquisition

    % Zero the scanners
    s.IsContinuous=false; %
    s.queueOutputData([0,0]); %Queue zero volts on each channel
    s.startForeground; % Set analog outputs to zero

    release(s); % Release control of the board
    delete(hFig)
end %close figCloseAndStopScan
