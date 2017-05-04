function scanAndAcquire_Minimal(DeviceID)
% Minimal code needed to acquire data from one channel of a 2-photon microscope
%
% function scanAndAcquire_Minimal(DeviceID)
%
% Purpose
% This is a tutorial function. Its goal is to show the minimal possible code necessary
% to run a 2-photon microscope. This function produces uni-direction galvo waveforms
% to scan the beam across the sample. It acquires data from one photo-detector (a PMT or
% a photo-diode) through one analog input channel. 
%
% All parameters are hard-coded within the function to keep things brief and focus on how 
% the acquisition is being done. No superfluous things like fast beam-blanking, saving,
% or even artefact correction are performed. The raw images are just streamed to a figure window. 
%
%
% Instructions
% Call the function with the device ID of your NI acquisition board as an input argument. 
% Quit by closing the window showing the scanned image stream. Doing this will gracefully
% stop the acquisition. 
% The X mirror should be on AO-0
% The Y mirror should be on AO-1
%
% Inputs
% hardwareDeviceID - a string defining the device ID of your NI acquisition board. Use the command
%                    "daq.getDevices" to find the ID of your board.
%
%
% Example
% The following example shows how to list the available DAQ devices and start
% scanAndAcquire_Minimal using the ID for the NI PCI-6115 card with the default. 
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

    % Scan parameters
    galvoAmp   = 2 ;     % Galvo amplitude. (defined as peak-to-peak/2) Increasing this increases the area scanned (CAREFUL!)
    imSize     = 256 ;   % Number of pixel rows and columns. Increasing this value will decrease the frame rate and increase the resolution.
    sampleRate = 128E3 ; % Increasing the sampling rate will increase the frame rate (CAREFUL!)
    AIrange = 2; % Digitize over +/- this range. 


    %- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
    % CONNECT TO THE HARDWARE
    s=daq.createSession('ni'); % Create a daq session using NI hardware. "s" is a session object.
    s.Rate = sampleRate;  % Set the sample rate. Note that the sample rate is fixed, so changing it will alter the frame rate

    AI=s.addAnalogInputChannel(DeviceID, 'ai0', 'Voltage'); % Add an analog input channel for the PMT signal
    AI.Range = [-AIrange,AIrange]; % Get the board to digitize over this range of values

    % Add analog two output channels for scanners:  0 is x and 1 is y
    s.addAnalogOutputChannel(DeviceID,0:1,'Voltage'); 


    %- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
    % BUILD THE GALVO WAVEFORMS

    % The Y waveform goes from +galvoAmp to -galvoAmp over the course of one frame. 
    % The mirror is moving continuously.
    yWaveform = linspace(galvoAmp, -galvoAmp, imSize^2); 

    % The X waveform goes from +galvoAmp to -galvoAmp over the course of one line.
    % The mirror is moving continuously. 
    xWaveform = linspace(-galvoAmp, galvoAmp, imSize); % One line of X

    % Repeat the X waveform "imSize" times in order to build a square image
    xWaveform = repmat(xWaveform, 1, length(yWaveform)/length(xWaveform)); 

    % Assemble the two waveforms into an N-by-2 array
    dataToPlay = [xWaveform(:), yWaveform(:)];

    %Report the frame rate to screen. 
    fps = sampleRate/length(dataToPlay);
    fprintf('Scanning with a frame size of %d by %d at %0.2f frames per second\n', imSize, imSize, fps)


    %- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
    % PREPARE TO ACQUIRE
    % Here we will do two things:
    % 1) Set up the DAQ session to continuously play the waveforms.
    % 2) Use a listener and a callback function to pull in the image data at the end of each frame.

    % This line sets the "NotifyWhenScansQueuedBelow" property to half the length of the 
    % of the Y waveform. This tells the session that we want to re-fill the output buffer when
    % half of the data have been played out. If the buffer empties the acquisition will cease, so
    % we must make sure it's always got data in it ready to play.
    s.NotifyWhenScansQueuedBelow = round(length(yWaveform)*0.5); 


    % We now add a "listener" that performs a task when the "DataRequired" "notifier" of the
    % "s" object fires. The notifier will fire when the buffer has only half a frame of data in it.
    % (see line above). When it fires, we run a callback function that queues another copy of 
    % the "dataToPlay" variable.
    addlistener(s,'DataRequired', @(src,event) src.queueOutputData(dataToPlay));

    % Set the "IsContinuous" property to true to enable continuous output
    s.IsContinuous = true; 

    % Finally, queue the first frame of data so we can get started. Nothing happens yet, though.
    s.queueOutputData(dataToPlay); 
    

    % Now we determine when to *read* data. We want to do this after the end of each frame.
    % We do this, like with the filling of the output buffer, using a listener. Here we set up
    % listener that fires when one frame's worth of data is in the input buffer (the input and 
    % output channels of the board are all on the same clock). When it fires, it runs the 
    % callback function "plotData", which define below. 
    s.NotifyWhenDataAvailableExceeds=size(dataToPlay,1); %Pull in the data when the frame has been acquired
    addlistener(s,'DataAvailable', @plotData);  % Add a listener to get data back from this channel



    %- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
    % SET UP THE FIGURE WINDOW THAT WILL DISPLAY THE DATA
    % Here we just make an empty plot window and make handles for the image and the axes. 
    % This will make it easier to modify the plot later, after each frame. 
    hFig=clf; 
    hIm=imagesc(zeros(imSize));
    imAx=gca;
    colormap gray
    set(imAx,'XTick',[], 'YTick',[], 'Position',[0,0,1,1]) %Fill the window with the image
    axis square

    % The last job is to link a callback to the figure's "CloseRequestFcn"
    % When the user tries to close the window, our callback function "figCloseAndStopScan"
    % will run. This function is defined below. It will first stop the scanning and release
    % the DAQ. Then it will close the figure. This keeps things neat.
    set(hFig,'CloseRequestFcn', @(~,~) figCloseAndStopScan(s,hFig));



    %- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
    % START!
    s.startBackground %start the acquisition in the background
    fprintf('Close window to stop scanning\n') %Remind the user how to stop the acquisition




    %- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
    function plotData(~,event)
        % This callback function is run each time one frame's worth of data have been acquired.
        % This happens because the of the listener set up, above. The function reads the data 
        % off the board and plots to screen. For convenience we have nested this callback in 
        % the main function body. It therefore shares the same scope as the main function.

        x=event.Data; % x is a vector (the NI card obviously doesn't know we have a square image)

        if length(x)<=1 %sometimes there are no data. If so, bail out.
            return
        end

        im = reshape(x,imSize,imSize); %Reshape the data vector into a square image
        im = rot90(im); %So the fast axis (x) is show along the image rows
        %im = -im; %You will need to multiply by minus one if you're using a PMT and your amplifier doesn't invert the signal


        % Plot the image data by setting the "CData" property of the image object in the plot window
        set(hIm,'CData',im);
        set(imAx,'CLim',[0,AIrange]);
    end %close plotData


end %close scanAndAcquire_Minimal




%-----------------------------------------------
% The following functions is not nested within the main function body and so their
% contents do not share the same scope as the main function. 
function figCloseAndStopScan(s,hFig)
    % This callback function runs when the scan figure window closes.
    % The purpose of this function is to stop the acquisition gracefully
    % and to then close the figure window.

    fprintf('Shutting down DAQ connection and zeroing scanners\n')
    s.stop; % Stop the acquisition

    % Zero the scanners so the beam is pointing down the middle of the objective.
    % This is useful for alignment. "Real" 2-photon software will usually attempt
    % to park the beam outside of the sample to remove the possibility of bleaching
    % or burning  the sample.
    s.IsContinuous=false; %
    s.queueOutputData([0,0]); %Queue zero volts on each channel
    s.startForeground; % Set analog outputs to zero

    release(s); % Release control of the DAQ board

    delete(hFig) %close the figure
end %close figCloseAndStopScan


