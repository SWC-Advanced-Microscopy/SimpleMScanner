classdef scannerGUI < handle

% The scannerGUI class is used to build a GUI that controls scanAndAcquire_OO
%
% scannerGUI(paramFile)
% 
% Purpose
% scannerGUI is a GUI wrapper for scanAndAcquire_OO. It is not complete. 
% The purpose of scannerGUI is to show how a graphical interface and be written
% around an existing object in a modular manner. In this case there are three modules:
% 1) The GUI (figure window) itself that is built by scannerGUI_fig
% 2) scanAndAcquire_OO that controls the scanner and shows the images on screen.
% 3) This scannerGUI class that links the UI elements in the figure with methods 
%    and properties in the scanAndAcquire_OO object. 
%
% Usage
% There are two ways of starting scannerGUI. One is to first create an instance of 
% scanAndAcquire_OO and then to call scannerGUI. In this scenario, scannerGUI finds
% the scanAndAcquire_OO object in the base workspace and connects to it:
% >> S=scanAndAcquire_OO;
% >> S=scannerGUI;
%
% The other scenario is to call scannerGUI directly. If you do this, an instance 
% of scanAndAcquire_OO is created and then the GUI loads:
% >> S = scannerGUI;
%
%
% Rob Campbell - Basel 2016
%
% Also see:
% scannerGUI_fig, scanAndAcquire_OO


    properties % These are the properties ("variables") associated with the scannerGUI class
        gui      %Stores the GUI handles
        scanner  %Stores the scanAndAcquire_OO object
    end %close properties

    properties (Hidden)
        frameAcquiredListener
    end %close properties (Hidden)
        

    methods % Here are the methods ("functions") available to the user

        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
        %CONSTRUCTOR
        function obj=scannerGUI(paramFile)
            if nargin<1
                paramFile=[];
            end
            
            %Import BakingTray object from base workspace           
            obj.scanner = getScannerObjectFromBaseWorkSpace; %function in "private" directory
            
            if isempty(obj.scanner)
                obj.gui.statusBar.String = 'Creating instance of scanAndAcquire_OO';
                disp(obj.gui.statusBar.String)
                obj.scanner = scanAndAcquire_OO(paramFile);
            end

            if isempty(obj.scanner)
                error('FAILED TO CONNECT TO SCANNER -- obj.scanner is empty')
            end

            obj.gui = scannerGUI_fig; %Build GUI and return handles

            %Update the GUI UI based pn the state of the scanner object
            obj.updateGUIfromScanner


            %Attach callback functions to UI interactions
            set(obj.gui.startStopScan,'Callback',@(~,~) obj.startStopScan);
            set(obj.gui.bidi,'Callback',@(~,~) obj.bidiScan);
            set(obj.gui.bidiPhase,'Callback',@(~,~) obj.bidiPhaseUpdate);
            set(obj.gui.saveFname,'Callback',@(~,~) obj.saveFnameUpdate);
            set(obj.gui.invert,'Callback', @(~,~) obj.invert)
            set(obj.gui.AIrange,'Callback', @(~,~) obj.AIrange)
            set(obj.gui.sampRate,'Callback', @(~,~) obj.sampleRate)
            set(obj.gui.samplesPix,'Callback', @(~,~) obj.samplesPix)           
            set(obj.gui.imSize,'Callback', @(~,~) obj.imSize)
            set(obj.gui.scannerAmp,'Callback', @(~,~) obj.scannerAmp)
            set(obj.gui.fillFraction,'Callback', @(~,~) obj.fillFraction)
            set(obj.gui.ai0,'Callback', @(~,~) obj.ai0)
            set(obj.gui.ai1,'Callback', @(~,~) obj.ai1)
            set(obj.gui.ai2,'Callback', @(~,~) obj.ai2)
            set(obj.gui.ai3,'Callback', @(~,~) obj.ai3)
            
            %Run method scannerGUIClose if the GUI's figure window is closed by the user
            set(obj.gui.hFig,'CloseRequestFcn', @obj.scannerGUIClose);

            % Listen to the FrameAcquired notifier on scanAndAcquire_OO so that we can update info
            % in the GUI. 
            obj.frameAcquiredListener = addlistener(obj.scanner, 'frameAcquired', @(~,~) obj.frameAcquiredCallBack);

            obj.gui.statusBar.String = 'Ready to acquire';
        end  %close constructor



        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
        function scannerGUIClose(obj,~,~)
            %This callback function is run when the GUI figure window is closed
            delete(obj.scanner);
            delete(obj.gui.hFig) %Close the GUI figure window
        end



        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
        %The following are callback functions that are linked to UI elements

        function startStopScan(obj)
            %This callback function is run when the user clicks the START/STOP scan button
            isRunning = obj.scanner.hDAQ.IsRunning;

            if isRunning
                %If the scanner is running, then stop scanning and change the button text
                obj.scanner.stopScan
                set(obj.gui.startStopScan, ...
                    'Value', isRunning, ...
                    'ForeGroundColor', 'g', ...
                    'String', 'START SCAN');
                %update the reporting of the save state and the save dialog
                obj.updateSaveUIelements
                obj.gui.statusBar.String = 'Ready to acquire';
            else
                %If the scanner is not running, then start scanning, and change the button text.
                obj.gui.statusBar.String = 'Preparing to scan';
                obj.scanner.startScan
                set(obj.gui.startStopScan, ...
                    'Value', isRunning, ...
                    'ForeGroundColor', 'r', ...
                    'String', 'STOP SCAN');
    
                %update the reporting of the save state and the save dialog
                obj.updateSaveUIelements
            end
        end %close startStopScan

        function invert(obj)
            %This callback function is run when the user clicks the invert checkbox
            obj.scanner.invertSignal = obj.gui.invert.Value;
        end %close invert

        function bidiScan(obj)
            %This callback function is run when the user clicks the bidi checkbox
            if obj.gui.bidi.Value
                obj.scanner.scanPattern='bidi';
                obj.gui.bidiPhase.Enable='on';
            else
                obj.scanner.scanPattern='uni';
                obj.gui.bidiPhase.Enable='off';
            end
        end %close bidiScan

        function bidiPhaseUpdate(obj)
            %This callback function is run when the user updates the bidirectional phase edit box
            newBidiPhase = obj.gui.bidiPhase.String;
            newBidiPhaseAsNumber = str2double(newBidiPhase);

            %Report to command line if the new bidi phase value is not a number
            if isempty(newBidiPhaseAsNumber)
                fprintf('\n ** The value %s is not a number ** \n\n',newBidiPhase)
                return
            end
            obj.scanner.bidiPhase = newBidiPhaseAsNumber;
        end %close bidiPhaseUpdate

        function saveFnameUpdate(obj)
            %This callback function is run when the user updates the save file name

            if isempty(obj.gui.saveFname.String)
                obj.gui.save.Enable='off';
            else
                obj.gui.save.Enable='on';
            end
            obj.scanner.saveFname = obj.gui.saveFname.String;           
        end %close saveFnameUpdate


        function AIrange(obj)
            newAIrange = obj.gui.AIrange.String;
            newAIrangeAsNumber = str2double(newAIrange);
            if isempty(newAIrangeAsNumber)
                fprintf('\n ** The value %s is not a number ** \n\n',newAIrange)
                return
            end
            obj.scanner.AIrange = newAIrangeAsNumber;
        end %close AIrange

        function sampleRate(obj)
            newSampRate = obj.gui.sampRate.String;
            newSampRateAsNumber = str2double(newSampRate);
            if isempty(newSampRateAsNumber)
                fprintf('\n ** The value %s is not a number ** \n\n',newSampRate)
                return
            end
            obj.scanner.sampleRate = newSampRateAsNumber;
        end %close sampleRate

        function imSize(obj)
            newImSize = obj.gui.imSize.String;
            newImSizeAsNumber = str2double(newImSize);
            if isempty(newImSizeAsNumber)
                fprintf('\n ** The value %s is not a number ** \n\n',newImSize)
                return
            end
            obj.scanner.imSize = newImSizeAsNumber;
        end %close imSize

        function samplesPix(obj)
            newsamplesPix = obj.gui.samplesPix.String;
            newsamplesPixAsNumber = str2double(newsamplesPix);
            if isempty(newsamplesPixAsNumber)
                fprintf('\n ** The value %s is not a number ** \n\n',newsamplesPix)
                return
            end
            obj.scanner.samplesPerPixel = newsamplesPixAsNumber;
        end %close samplesPix

        function scannerAmp(obj)
            newScannerAmp = obj.gui.scannerAmp.String;
            newScannerAmpAsNumber = str2double(newScannerAmp);
            if isempty(newScannerAmpAsNumber)
                fprintf('\n ** The value %s is not a number ** \n\n',newScannerAmp)
                return
            end
            obj.scanner.scannerAmplitude = newScannerAmpAsNumber;
        end %close scannerAmp

        function fillFraction(obj)
            newfillFraction = obj.gui.fillFraction.String;
            newfillFractionAsNumber = str2double(newfillFraction);
            if isempty(newfillFractionAsNumber)
                fprintf('\n ** The value %s is not a number ** \n\n',newfillFraction)
                return
            end
            obj.scanner.fillFraction = newfillFractionAsNumber;
        end %close fillFraction



        %Channels
        function ai0(obj)
            processInputChannel(obj,'ai0')
        end %close ai0
        function ai1(obj)
            processInputChannel(obj,'ai1')
        end %close ai1
        function ai2(obj)
            processInputChannel(obj,'ai2')
        end %close ai2
        function ai3(obj)
            processInputChannel(obj,'ai3')
        end %close ai3



    end %close methods



    methods (Hidden)

        function updateSaveUIelements(obj)
            %reports whether the scanner will save data, etc
            if obj.scanner.hDAQ.IsRunning;
                obj.gui.saveFname.Enable='off';
                obj.gui.save.Enable='off';
            else
                obj.gui.saveFname.Enable='on';
                obj.gui.save.Enable='on';
            end

            if ~obj.gui.save.Value
                obj.gui.save.String='Save';
                return
            end
            if obj.scanner.hDAQ.IsRunning;
                obj.gui.save.String='** SAVING **';
            else
                obj.gui.save.String='Save';
            end
        end %close updateSaveUIelements

        function frameAcquiredCallBack(obj)
            % This callback is run once each frame has been acquired. 
            % It updates the status bar in the GUI to show the current number of frames
            % plus other parameters.
            msg = sprintf('Frame #%d - %0.1f FPS - %dx%d - %d samples/pix - %0.1f V - fillFrac=%0.2f',...
                obj.scanner.numFrames, ...
                obj.scanner.fps,...
                obj.scanner.imSize, obj.scanner.imSize,...
                obj.scanner.samplesPerPixel, ...
                obj.scanner.scannerAmplitude, ...
                obj.scanner.fillFraction);
            obj.gui.statusBar.String = msg;
        end %close frameAcquiredCallBack



        function updateGUIfromScanner(obj)
            obj.gui.invert.Value = obj.scanner.invertSignal;

            obj.gui.bidiPhase.String = obj.scanner.bidiPhase;
            if strcmpi(obj.scanner.scanPattern,'bidi')
                obj.gui.bidi.Value=true;
                obj.gui.bidiPhase.Enable='on';
            else
                obj.gui.bidi.Value=false;
                obj.gui.bidiPhase.Enable='off';
            end

            obj.gui.saveFname.String = obj.scanner.saveFname;
            if isempty(obj.gui.saveFname.String)
                obj.gui.save.Enable='off';
            else
                obj.gui.save.Enable='on';
            end

            obj.gui.AIrange.String = obj.scanner.AIrange;
            obj.gui.sampRate.String = obj.scanner.sampleRate;
            obj.gui.imSize.String = obj.scanner.imSize;
            obj.gui.samplesPix.String = obj.scanner.samplesPerPixel;
            obj.gui.scannerAmp.String = obj.scanner.scannerAmplitude;
            obj.gui.fillFraction.String = obj.scanner.fillFraction;

            obj.gui.ai0.Value = any(strncmp('ai0',obj.scanner.inputChans,3));
            obj.gui.ai1.Value = any(strncmp('ai1',obj.scanner.inputChans,3));
            obj.gui.ai2.Value = any(strncmp('ai2',obj.scanner.inputChans,3));
            obj.gui.ai3.Value = any(strncmp('ai3',obj.scanner.inputChans,3));
        end

    end %close hidden methods



end %close scannerGUI



function processInputChannel(obj,inChan)
    if obj.gui.(inChan).Value
        %Add channel
        if any(strncmpi(inChan,obj.scanner.inputChans,3))
            return
        end
        obj.scanner.inputChans = [obj.scanner.inputChans,inChan];
    else
        %Remove channel
        ind=strncmpi(inChan,obj.scanner.inputChans,3);       
        if length(ind)==1
            fprintf('Must have at least one active channel!\n')
            obj.gui.(inChan).Value=true;
            return
        end
            
        if any(ind)
            obj.scanner.inputChans = obj.scanner.inputChans(~ind);
        end
    end
end %close processInputChannel


