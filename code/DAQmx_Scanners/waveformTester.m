classdef waveformTester < handle
    % Generate and test various galvo waveforms
    %
    % waveformTester
    %
    %
    % Description:
    % This is a tutorial class to explore the scan waveform. Parameters are set by editing the properties.
    %
    %
    % Instructions
    % * Edit the "DAQDevice" property so it is the ID of your DAQ card. 
    % * Hook up AO0 to the galvo command (input) voltage terminal.
    % * Wire up the rack to copy AO0 to AI0
    % * Connect AI1 to the galvo position (output) terminal.
    % * Run: S=waveformTester;
    %
    % You will see a sinusoidal black trace overlaid by a red trace. The black is the command signal
    % and the red the position signal. The blue sub-plot shows the position signal as a function of 
    % the command signal. Frequency of the waveform is displayed in the window title and at the 
    % command line. 
    %
    % You can stop acquisition by closing the window. 
    %
    % NOTE with USB DAQs: you will get error -200877 if the AI buffer is too small.
    %
    % 
    % Things try:
    % The scanners have inertia so their ability to follow the command waveform will depend upon
    % its shape and frequency. Let's try changing the frequency. Close the figure window (take 
    % screenshot first if you want to compare before and after) and edit the "sampleRate" property.
    % Increase it to, say 128E3. Re-start the object. Notice the larger lag between the position 
    % and command and how this is reflected in the blue X/Y plot "opening up". 
    %
    % Let's now try having fewer samples per cycle. Stop, set "pixelsPerLine" to 128, and restart.
    % If your scanners can't keep up, try a larger value. At 128 samplesPerLine and 128 kHz sample 
    % rate the scanner runs at 1 kHz. There will be a big lag now. If your scanners will keep up, you
    % can try lines as short as about 32 pixels, which is 4 kHz. Don't push beyond this in case the 
    % scanners can't cope. Also, don't try such high frequencies with other command waveform shapes.
    %
    % Go back to 1 kHz and try different amplitudes. See how the lag is the same across amplitudes. 
    %
    % Now let's explore AO/AI synchronisation. Set pixelsPerLine to 128 and the sample rate to 128E3. 
    % All should look good. Try a range of different, but similar, sample rates. e.g. 117E3. Likely you
    % will see a warning message and precession of the AI waveforms (this is relative to the AO). 
    % You can fix this by setting the AI and AO clocks to be shared as in the polishedScanner class. 
    %
    % Try a sawtooth waveform by modifying the waveformType property. Start with a frequency below 500 Hz 
    % then try higher frequency (e.g. 2 kHz). How well do the scanners follow the command signal?
    %
    %
    % Requirements
    % DAQmx and the Vidrio dabs.ni.daqmx wrapper
    %
    % See Also:
    % minimalScanner



    % Define properties that we will use for the acquisition. The properties are "protected" to avoid
    % the user changing them at the command line. Doing so would cause the acquisition to exhibit errors
    % because there is no mechanism for handling changes to these parameters on the fly.
    properties (SetAccess=private)

        % These properties are common to both tasks
        DAQDevice = 'Dev1'
        sampleRate = 32E3  % The sample rate at which the board runs (Hz)

        waveformType='sine'  % Waveform shape. Valid values are: 'sine', 'sawtooth'

        % These properties are specific to scanning
        galvoAmp = 3          % Scanner amplitude (defined as peak-to-peak/2)
        pixelsPerLine = 256        % Number pixels per line for a sawtooth waveform (for sine wave this defines wavelength)
        waveform                   % The scanner waveform will be stored here
        numReps=10                 % How many times to repeat this waveform in one acquisiion

        % Properties for the analog input end of things
        hAITask %The AI task handle will be kept here

        AIChan = [0,1] 
        AIrange = 10  % Digitise over +/- this range. 

        % Properties for the analog output end of things
        hAOTask % The AO task handle will be kept here
        AOChans = 0

        % These properties hold information relevant to the plot window
        hFig    % The handle to the figure which shows the data is stored here
        hAxes   % Handle for the main axes
        hAxesXY % Handle fo the plot of AI1 as a function of AI0
        hPltDataAO0 % AO0 plot data
        hPltDataAO1 % AO1 plot data
        hPltDataXY  % AO0 vs AO1 plot data
    end




    methods

        function obj=waveformTester
            % This method is the "constructor", it runs when the class is instantiated.

            fprintf('Please see "help waveformTester" for usage information\n')

            % Build the figure window and have it shut off the acquisition when closed.
            obj.hFig = clf;
            set(obj.hFig, 'CloseRequestFcn', @obj.windowCloseFcn)

            %Make an empty axis and fill with blank data
            obj.hAxes = axes('Parent', obj.hFig, 'Position', [0.09 0.1 0.89 0.88], 'NextPlot', 'add', ...
                'YLim',[-obj.galvoAmp*1.15,obj.galvoAmp*1.15]);
            obj.hAxes.XLabel.String = 'Time (ms)';
            obj.hAxes.YLabel.String = 'Voltage';
            obj.hPltDataAO0 = plot(obj.hAxes, zeros(100,1), '-k');
            obj.hPltDataAO1 = plot(obj.hAxes, zeros(100,1), '-r');

            % Call a method to connect to the DAQ. If the following line fails, the Tasks are
            % cleaned up gracefully and the object is deleted. This is all done by the method
            % call and by the destructor
            obj.connectToDAQandSetUpChannels

            if isvalid(obj)
                set(obj.hAxes,'XLim',[0,length(obj.waveform)], 'Box', 'on')
                set(obj.hAxes, 'XLim', [0,length(obj.waveform)/obj.sampleRate*1E3])
                grid on
                legend('command','position')

                % Make the inset plot
                obj.hAxesXY = axes('Parent', obj.hFig, 'Position', [0.8 0.1 0.2 0.2], 'NextPlot', 'add');
                obj.hPltDataXY = plot(obj.hAxesXY, zeros(100,1), '-b.');
                set(obj.hAxesXY, 'XTickLabel', [], 'YTickLabel',[], ...
                    'YLim',[-obj.galvoAmp*1.15,obj.galvoAmp*1.15],'XLim',[-obj.galvoAmp*1.15,obj.galvoAmp*1.15]);
                %Add "crosshairs" to show x=0 and y=0
                plot(obj.hAxesXY, [-obj.galvoAmp*1.15,obj.galvoAmp*1.15], [0,0], ':k');
                plot(obj.hAxesXY, [0,0], [-obj.galvoAmp*1.15,obj.galvoAmp*1.15], ':k');

                obj.hAxesXY.Color=[0.8,0.8,0.95,0.75]; %blue background  and transparent (4th input, an undocumented MATLAB feature)
                grid on
                box on
                axis square

                set(obj.hFig,'Name', sprintf('Close figure to stop acquisition - waveform frequency=%0.1f HZ', 1/obj.linePeriod) )

                % Start the acquisition
                obj.start
                fprintf('Close figure to quit acquisition\n')
            end
        end % close constructor


        function delete(obj)
            % This method is the "destructor". It runs when an instance of the class is deleted.
            fprintf('Running destructor\n');
            if ~isempty(obj.hFig) && isvalid(obj.hFig)
                obj.hFig.delete %Closes the plot window
            end
            obj.stop % Call the method that stops the DAQmx tasks

            obj.hAITask.delete;
            obj.hAOTask.delete;
        end %close destructor


        function connectToDAQandSetUpChannels(obj)
            % Note how we try to name the methods in the most descriptive way possible
            % Attempt to connect to the DAQ and set it up. If we fail, we close the 
            % connection to the DAQ and tidy up
            try 
                % Create separate DAQmx tasks for the AI and AO
                obj.hAITask = dabs.ni.daqmx.Task('signalReceiver');
                obj.hAOTask = dabs.ni.daqmx.Task('waveformMaker');

                %  Set up analog input and output voltage channels
                obj.hAITask.createAIVoltageChan(obj.DAQDevice, obj.AIChan, [], -obj.AIrange, obj.AIrange);
                obj.hAOTask.createAOVoltageChan(obj.DAQDevice, obj.AOChans);


                % * Set up the AI task

                % Configure the sampling rate and the number of samples so that we are reading back data at the end of each waveform
                obj.generateScanWaveform %This will populate the waveforms property

                obj.hAITask.cfgSampClkTiming(obj.sampleRate,'DAQmx_Val_ContSamps', size(obj.waveform,1)*100 );

                % Call an anonymous function function to read from the AI buffer and plot the images once per frame
                obj.hAITask.registerEveryNSamplesEvent(@obj.readAndDisplayScanData, size(obj.waveform,1), false, 'Scaled');


                % * Set up the AO task
                % Set the size of the output buffer
                obj.hAOTask.cfgSampClkTiming(obj.sampleRate, 'DAQmx_Val_ContSamps', size(obj.waveform,1));

                if obj.hAOTask.sampClkRate ~= obj.hAITask.sampClkRate
                    fprintf(['\nWARNING: AI task sample clock rate does not match AO task sample clock rate. Scan lines will precess.\n', ...
                        'This issue is corrected in polishedScanner, which uses a shared sample clock between AO and AI\n\n'])
                end

                % Allow sample regeneration (buffer is circular)
                obj.hAOTask.set('writeRegenMode', 'DAQmx_Val_AllowRegen');

                % Write the waveform to the buffer with a 5 second timeout in case it fails
                obj.hAOTask.writeAnalogData(obj.waveform, 5);

                % Configure the AO task to start as soon as the AI task starts
                obj.hAOTask.cfgDigEdgeStartTrig(['/',obj.DAQDevice,'/ai/StartTrigger'], 'DAQmx_Val_Rising');
            catch ME
                    errorDisplay(ME)
                    %Tidy up if we fail
                    obj.delete
            end
        end % close connectToDAQandSetUpChannels


        function start(obj)
            % This method starts acquisition on the AO then the AI task. 
            % Acquisition begins immediately since there are no external triggers.
            try
                obj.hAOTask.start();
                obj.hAITask.start();
            catch ME
                errorDisplay(ME)
                %Tidy up if we fail
                obj.delete
            end
        end %close start


        function stop(obj)
            % Stop the AI and then AO tasks
            fprintf('Stopping the scanning AI and AO tasks\n');
            obj.hAITask.stop;    % Calls DAQmxStopTask
            obj.hAOTask.stop;
        end %close stop


        function generateScanWaveform(obj)
            % This method builds a simple ("unshaped") galvo waveform and stores it in the obj.waveform

            switch obj.waveformType

            case 'sawtooth'
                % The X waveform goes from +galvoAmp to -galvoAmp over the course of one line.
                xWaveform = linspace(-obj.galvoAmp, obj.galvoAmp, obj.pixelsPerLine); 
                obj.waveform = repmat(xWaveform, 1, obj.numReps)'; % Repeat the X waveform a few times to ease visualisation on-screen

            case 'sine'
                % sine wave
                obj.waveform = obj.galvoAmp *  sin(linspace(-pi*obj.numReps, pi*obj.numReps, obj.pixelsPerLine*obj.numReps))';
            end



            %Report waveform properties
         
            fprintf('Scanning with a waveform of length %d and a line period of %0.3f ms (%0.1f Hz)\n', ...
             obj.pixelsPerLine, obj.linePeriod*1E3, 1/obj.linePeriod);

        end %close generateScanWaveform


        function readAndDisplayScanData(obj,src,evnt)
            % This callback method is run each time data have been acquired.
            % This happens because the of the listener set up in the method connectToDAQandSetUpChannels
            % on the "obj.hAITask.registerEveryNSamplesEvent" line.

            % Read data off the DAQ
            inData = readAnalogData(src,src.everyNSamples,'Scaled');

            timeAxis = (0:length(inData)-1) / obj.sampleRate*1E3;
            obj.hPltDataAO0.YData = inData(:,1);
            obj.hPltDataAO0.XData=timeAxis;
            %Scale the feedback signal so it's the same amplitude as the command
            scaleFactor = max(inData(:,1)) / max(inData(:,2));
            obj.hPltDataAO1.YData = inData(:,2)*scaleFactor;
            obj.hPltDataAO1.XData=timeAxis;

            obj.hPltDataXY.YData = inData(:,2)*scaleFactor;
            obj.hPltDataXY.XData = inData(:,1);
        end %close readAndDisplayScanData



        function windowCloseFcn(obj,~,~)
            % This runs when the user closes the figure window or if there is an error
            % Note it's also possible to run a clean-up callback function with hTask.registerDoneEvent

            fprintf('You closed the window. Shutting down DAQ.\n')
            obj.delete % simply call the destructor
        end %close windowCloseFcn


        function LP = linePeriod(obj)
           if isempty(obj.waveform) 
               LP=[];
                return
            end
            LP = length(obj.waveform) / (obj.sampleRate*obj.numReps);
        end % close linePeriod

    end %close methods block

end %close the vidrio.mixed.waveformTester class definition 



% Private functions not part of the class definition
function errorDisplay(ME)
    fprintf('ERROR: %s\n',ME.message)
    for ii=1:length(ME.stack)
        fprintf(' on line %d of %s\n', ME.stack(ii).line,  ME.stack(ii).name)
    end
    fprintf('\n')
end
