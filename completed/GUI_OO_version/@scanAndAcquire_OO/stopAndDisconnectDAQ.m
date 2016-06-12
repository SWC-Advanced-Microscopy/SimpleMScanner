function stopAndDisconnectDAQ(obj)
	% Stop the DAQ device, zeros the scanners, and disconnects from it
	% This method is called by the destructor, but maybe the user will 
	% want to call it independently. 

	fprintf('Zeroing AO channels\n')
	obj.stopScan(false) %Silently stop the scanners
	obj.hDAQ.IsContinuous=false;
	obj.hDAQ.queueOutputData([0,0]);
	obj.hDAQ.startForeground;

	fprintf('Releasing NI hardware\n')
	obj.hDAQ.release;
    if ~isempty(obj.hDIO)
        obj.hDIO.release;
    end
	

end %close stopAndDisconnectDAQ
