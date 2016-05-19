function dataToPlay = galvoWaveforms(obj,verbose)
% Produce galvo wavorms for 2-photon microscope scanning 
%
% function dataToPlay = gGalvoWaveforms(obj,verbose)
%
% Purpose
% Generates the galvo waveforms for a 2-photon microscope. Patterns for square images only are produced.
% Uses the following properties from scanAndAcquire_OO
% 
% imSize - Scalar defining the number of rows and columns in the image. 
%          e.g. if imSize is 256, then a 256 by 256 image is produced
% obj.scannerAmplitude - Scalar defining the maximum (+/-) voltage of the waveform. 
%          e.g. if obj.scannerAmplitude is 2 then data are acquired using waveform 
%           command voltages going between +/- 2 (but see "fillFraction")
% samplesPerPixel - Scalar defining the number of samples contributing to each pixel. Increasing
%           this value will increase image quality but decrease frame rate.
% fillFraction - Scalar (0 to 1) defining what proportion of the waveform to keep and 
%           use for image formation. This is used to remove the x mirror turn-around 
%           artefacts. e.g. if fillfraction is 0.9, we will remove the outer 10% of the waveform. 
%           In order to maintain a square image, we increase the size of the scanned area to compensate.
% scanPattern - 'bidi' or 'uni' (uni by default)
% verbose     - false by default. If true, print diagnostic messages to screen. 
%
%
% Outputs
% dataToPlay - an N-by-2 array of values corresponding to the galvo waveforms for one frame.
%              First column is X waveform and second is Y waveform.
%
%
% Rob Campbell - Basel 2016
	

	if nargin<2
		verbose=false;
	end

	obj.scannerAmplitude = abs(obj.scannerAmplitude);


	% Calculate the number of samples per line. We want to produce a final image composed of
	% imSize data points on each line. However, if the fill fraction is less than 1, we
	% need to collect more than this then trim it back when we build the image. 
	% The number of samples collected per line will scale with the number of samples per point
	fillFractionExcess = 2-obj.fillFraction; %The proprotional increase in scanned area along X
	pixelsPerLine  = ceil(obj.imSize * fillFractionExcess);
	samplesPerLine = pixelsPerLine * obj.samplesPerPixel;

	if verbose
		if fillFraction<1
			fprintf('Based on a fill-fraction of %0.1f, the number of pixels per line goes up from %d to %d\n',...
				obj.fillFraction, obj.imSize, pixelsPerLine)
		else
			fprintf('There are %d pixels per line\n', obj.imSize)
		end
	end

	%Produce the Y waveform and retain a square image
	yScanAmp = obj.scannerAmplitude*obj.fillFraction; %zoom in with Y to compensate for the region lost in X due to the fill fraction changing
	yWaveform = linspace(yScanAmp, -yScanAmp, samplesPerLine*obj.imSize);


	%Produce the X waveform
	xWaveform = linspace(-obj.scannerAmplitude, obj.scannerAmplitude, samplesPerLine);

	if strcmpi(obj.scanPattern,'bidi')
		if verbose
			fprintf('Building bidirectional scan waveform\n')
		end
		xWaveform = [xWaveform,fliplr(xWaveform)];
	end

	xWaveform = repmat(xWaveform,1,length(yWaveform)/length(xWaveform));

	if length(xWaveform) ~= length(yWaveform)
		error('xWaveform and yWaveform are not the same length. The x is %d long and the y %d long',...
			length(xWaveform), length(yWaveform));
	end

	if verbose
		fprintf('Final waveforms have a length of %d\n',length(xWaveform))
	end

	%Assemble the two waveforms into an N-by-2 array that can be sent to the NI board
	dataToPlay = [xWaveform(:),yWaveform(:)];

end