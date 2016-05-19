function success = checkScanParams(obj)
% Check whether the scanner parameters are valid
%
% function success = checkScanParams(obj)
%
%
% Purpose
% Returns true of the scanner parameter stored as properties in the 
% scanAndAcquire_OO object object are valid.
%
%
% Rob Campbell - Basel 2016
	
	success=true;

	if ~isscalar(obj.imSize)
		fprintf('imSize should be a scalar\n')
		success=false;
	end

	if ~isscalar(obj.scannerAmplitude)
		fprintf('maxScannerVoltageAmplitude should be a scalar\n')
		success=false;
	end

	if ~isscalar(obj.samplesPerPixel)
		fprintf('samplesPerPixel should be a scalar\n')
		success=false;
	end

	if ~isscalar(obj.fillFraction)
		fprintf('fillFraction should be a scalar\n')
		success=false;
	end

	if ~ischar(obj.scanPattern)
		fprintf('scanPattern should be a string')
		success=false;
	end

	if ~strcmpi(obj.scanPattern,'uni') && ~strcmpi(obj.scanPattern,'bidi')
		fprintf('scanPattern must be the string "uni" or "bidi"')
		success=false;
	end

	if abs(obj.scannerAmplitude)>obj.maxScannerVoltage
		fprintf('objscannerAmplitude should be less than %0.1f\n',obj.maxScannerVoltage)
		success=false;
	end


end %close checkScanParams
