classdef scannerGUI < handle

% The scannerGUI class is used to build a GUI that controls
% scanAndAcquire_OO
%
% simply run "scannerGUI" to start.
% if scanAndAcquire_OO has not already been started, scannerGUI will do so


	properties
		gui 	 %Stores the GUI handles
		scanner  %Stores the scanAndAcquire_OO object
	end

	methods

		function obj=scannerGUI(deviceID,varargin)

			%Import BakingTray object from base workspace			
			obj.scanner = getScannerObjectFromBaseWorkSpace; %function in "private" directory
			if isempty(obj.scanner)
				obj.scanner = scanAndAcquire_OO(deviceID,varargin{:});
			end
			%Build GUI and return handles
			obj.gui = scannerGUI_fig;

			%Call hMover_KeyPress on keypress events
			set(obj.gui.hFig,'KeyPressFcn', {@hMover_KeyPress,obj})

			%Attach callbacks to buttons is BT is available
			if isempty(obj.scanner)
				fprintf('Not attaching button callbacks: BakingTray is not available')
				return
			end

    		set(obj.gui.startStopScan,'Callback',@(~,~) obj.startStopScan);


		    set(obj.gui.hFig,'CloseRequestFcn', @(~,~) obj.figClose); %TODO: stop scanning, etc when the figure closes

		end

		function delete(obj)

		end

		function figClose(obj)
			%Close figure then run destructor
			delete(obj.gui.hFig)
			obj.scanner.stopScan
			obj.delete
		end

		function startStopScan(obj)
			disp('START/STOP')
			%TODO
		end

	end

end


function checkNumeric(src,~)
	%Check that inputs to text boxes are numeric
	str=get(src,'String');
	if isempty(str2num(str))
	    set(src,'string','0');
	end
end
