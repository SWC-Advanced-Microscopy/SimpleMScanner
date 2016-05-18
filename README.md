# SimpleMScanner

Simple MATLAB 2-photon scanning software for demo and teaching purposes.


## What is this?

A 2-photon microscope is a laser-scanning microscope that builds up an image by sweeping a laser beam across a specimen in a [raster pattern](https://en.wikipedia.org/wiki/Raster_scan). The laser excites fluorescent proteins which emit light of a different wavelength to that with which they were excited. 
This emitted light is detected using one or more [PMTs](https://en.wikipedia.org/wiki/Photomultiplier). 
Emitted light and excitation light are of different wavelengths and so can be isolated with [dichroic mirrors](https://en.wikipedia.org/wiki/Dichroic_filter) and optical
band-pass filters. 
Similarly, emitted light of different wavelengths (e.g. from different fluorescent molecules) can be split by dichroic mirrors and detected at different PMTs. 

The 2-photon microscope takes its name from the [2-photon effect](https://en.wikipedia.org/wiki/Two-photon_excitation_microscopy) that is to excite the fluorophores in the specimen. 
Here, single fluorophore molecules emit a short-wave photon after being excited by two long wave photons delivered simultaneously. 
This is the opposite of what typically occurs in fluorescence (shorter wave photons excite a molecule to release longer wave photons). 
The 2-photon effect is made possible by high frequency pulsed lasers, where the peak power is many thousands of times higher than the mean power. 
For example, the [Mai Tai laser](http://www.spectra-physics.com/products/ultrafast-lasers/mai-tai#specs) from Spectraphysics has a mean power of about 2 W but a peak power of about 500 kW. 

One interesting feature of 2-photon microscopes is that they are [relatively easy to build](http://journals.plos.org/plosone/article?id=10.1371/journal.pone.0110475) with off the shelf parts. 
In order to acquire an image with a 2-photon, the beam needs to be scanned across the specimen and the emitted light collected. 
[ScanImage](http://scanimage.vidriotechnologies.com), which runs in MATLAB, is a widely used software package for acquiring images and coordinating experiments. 
However, ScanImage is a complex application and its core scanning code is not accessible to the user. 
**SimpleMScanner** is a collection of example tutorial code to show how to write scanning software for a 2-photon microscope. 
SimpleMScanner is not designed to be a complete application, but rather a teaching aid or perhaps even a basis upon which to begin writing a complete application. 


## What you will need
SimpleMScanner has been tested on MATLAB R2015a and requires the [Data Acquisition Toolbox](https://uk.mathworks.com/products/daq/). 
You will also need a National Instruments acquisition device to coordinate scanning and data acquisition. 
It has been tested on an NI PCI-6115, but likely other boards supported by the Data Acquisition Toolbox will work as well. 
Of course you will also need at least a set scan mirrors, a scan lens, a tube lens, an objective, some form of detector and a laser. 
For educational purposes, it is possible to use a laser pointer and a photo-diode that detects transmitted light through a thin sample. 


## Disclaimer
This software is supplied "as is" and the author(s) are not responsible for hardware damage, blindness, etc, caused by use (or misuse) of this software. 
High powered lasers should only be operated by trained individuals. 
It is good practice to confirm the scan waveforms with an oscilloscope before feeding them to the scan mirrors. 
Start with smaller amplitude scan patterns and lower frame rates so as not to damage your scanners. 
Immediately stop scanning if the mirrors make unusual chirping noises and/or the image breaks down.



# Contents of this project

* **scanAndAcquire_Minimal** - The least you need to scan the mirrors across a sample and obtain an image:
..* Uni-directional scanning
..* Displays image to screen only
..* One channel only
..* No correction for imaging artefacts
..* Scanning parameters are hard-coded into the function. User can change scanner amplitude, number of pixels in the image, and sample rate.

* **scanAndAcquire_Basic** - The same as scanAndAcquire_Minimal but adds:
..* Averaging using multiple samples per pixel
..* Correction of the X mirror (fast axis) turn-around artefact

* **scanAndAcquire_Polished** - The same as scanAndAcquire_Basic but adds the following features:
..* All important parameters can be set via parameter/value pairs
..* Acquisition of multiple channels
..* Scanning patterns and plotting are handled by external functions
..* A histogram overlay on top of the scan image.
..* Saving to disk
..* Bidirectional scanning

* The **buildingBlocks** folder contains code snippets to help teach the individual concepts from the above without providing a solution to the whole problem. 

* The repository also contains functions for loading saved TIFF stacks from disk, etc.