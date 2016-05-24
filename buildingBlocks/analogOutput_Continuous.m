function analogOutput_Continuous
% Play a continuous sine wave out of an analog output
%
% function analogOutput_Continuous
%
%
% Instructions
% Simply call the function. Quit with ctrl-C.
%
%
% Rob Campbell - Basel 2015




%Create a session using NI hardware
s=daq.createSession('ni');


%Add one output channel (channel 0)
s.addAnalogOutputChannel('Dev1',0,'Voltage'); 


%Build one cycle of a sine wave
waveForm=sin(-pi : pi/1000 : pi);


%Set the sample rate to 2000 samples per second, so the waveform plays out in one second
s.Rate = 2000;


%The output buffer is re-filled for the next line when it becomes half empty
s.NotifyWhenScansQueuedBelow = round(length(waveForm)*0.5); 


%This listener tops up the output buffer
addlistener(s,'DataRequired', @(src,event) src.queueOutputData(waveForm));

s.IsContinuous = true; %needed to provide continuous behavior


%queue the first cycle 
s.queueOutputData(dataToPlay); 


% START!
s.startBackground 


%Block. User presses ctrl-C to to quit, this calls stopAcq
fprintf('Press ctrl-c to stop')
while 1
	pause(0.25)
end

