# SimpleMScanner

Simple MATLAB 2-photon scanning software for demo and teaching purposes.

<img src="https://github.com/tenss/SimpleMScanner/blob/gh-pages/images/active_cells_smaller.jpg" />

## What is this?

A 2-photon microscope is a laser-scanning microscope that builds up an image by sweeping a laser beam across a specimen in a [raster pattern](https://en.wikipedia.org/wiki/Raster_scan). The laser excites fluorescent proteins which emit light of a different wavelength to that with which they were excited. 
This emitted light is detected using one or more [PMTs](https://en.wikipedia.org/wiki/Photomultiplier). 
Emitted light and excitation light are of different wavelengths and so can be isolated with [dichroic mirrors](https://en.wikipedia.org/wiki/Dichroic_filter) and optical
band-pass filters. 
Similarly, emitted light of different wavelengths (e.g. from different fluorescent molecules) can be split by dichroic mirrors and detected at different PMTs. 

The 2-photon microscope takes its name from the [2-photon effect](https://en.wikipedia.org/wiki/Two-photon_excitation_microscopy) that is used to excite the fluorophores in the specimen. 
Here, single fluorophore molecules emit a short-wave photon after being excited by two long-wave photons that are absorbed simultaneously. 
This is the opposite of what typically occurs in fluorescence (one shorter wave photon excites a molecule to release one longer wave photon). 
The 2-photon effect is made possible by high frequency pulsed lasers, where the peak power is many thousands of times higher than the mean power. 
For example, the [Mai Tai laser](http://www.spectra-physics.com/products/ultrafast-lasers/mai-tai#specs) from Spectraphysics has a mean power of about 2 W but a peak power of about 500 kW. 

One interesting feature of 2-photon microscopes is that they are [relatively easy to build](http://journals.plos.org/plosone/article?id=10.1371/journal.pone.0110475) with off the shelf parts. 
In order to acquire an image, the beam needs to be scanned across the specimen and the emitted light collected. 
[ScanImage](http://scanimage.vidriotechnologies.com), which runs in MATLAB, is a widely used software package for acquiring images and coordinating experiments. 
However, ScanImage is a complex application which does a lot of things in addition to image acquisition. 
**SimpleMScanner** is a collection of example tutorial code to show how to write scanning software for a linear scanning (not resonant) 2-photon microscope. 
SimpleMScanner is a teaching aid, not a complete application.


## What you will need
SimpleMScanner has been tested on MATLAB R2015a and R2015b and requires the [Data Acquisition Toolbox](https://uk.mathworks.com/products/daq/) and/or 
the [Vidrio](http://scanimage.vidriotechnologies.com) `dabs.ni.daqmx` wrapper. 
For more details on DAQ tasks in MATLAB see [the TENSS DAQmx examples](https://github.com/tenss/MatlabDAQmx).
You will also need a National Instruments device to coordinate scanning and data acquisition. 
It has been tested on NI PCI-6110, PCI-6115, and USB-6356 devices and should work on other similar boards. 
Of course you will also need at least a set of scan mirrors, a scan lens, a tube lens, an objective, some form of detector and a laser. 
For educational purposes, it is possible to use a laser pointer and a photo-diode that detects transmitted light through a thin, high contrast, sample such as an EM grid. 


# Contents of this project
SimpleMScanner contains examples written using both The Mathworks Data Acquisition Toolbox and the Vidrio `dabs.ni.daqmx` wrapper.

* **DAQ_ToolBox_Scanners/scanAndAcquire_Minimal** - 
  This tutorial function uses the DAQ Toolbox and is the least you need to scan the mirrors across a sample and obtain an image:
  1. Uni-directional scanning.
  2. Displays image to screen only.
  3. One channel only.
  4. No correction for imaging artefacts.
  5. Scanning parameters are hard-coded into the function. User can change scanner amplitude, number of pixels in the image, and sample rate.
  <br />
  
**DAQmx_Scanners/minimalScanner** is the equivilent using the Vidrio wrapper, but it's object-oriented.

* **DAQ_ToolBox_Scanners/scanAndAcquire_Basic** - 
  This tutorial function is the least you need to get good images and save them to disk. 
  It uses the DAQ Toolbox and provides the same features as scanAndAcquire_Minimal but adds:
  1. [Averaging using multiple samples per pixel](https://raw.githubusercontent.com/tenss/SimpleMScanner/gh-pages/images/samples_per_pix_example.jpg).
  2. Correction of the X mirror (fast axis) turn-around artefact.
  3. Saving to disk as a TIFF stack. A function to read back the data is provided.
  <br />
**DAQmx_Scanners/basicScanner** is the equivilent using the Vidrio wrapper, but it's object-oriented.

* **DAQ_ToolBox_Scanners/scanAndAcquire_Polished** - The same as scanAndAcquire_Basic but adds the following features:
  1. All important parameters can be set via parameter/value pairs.
  2. More error checks.
  3. Acquisition of multiple channels.
  4. Generation of scan patterns and image display are handled by external functions.
  5. Adds an optional histogram overlay on top of the scan images.
  6. Time-stamps added to the saved TIFF info.
  7. Bidirectional scanning.
  8. Improved scan waveform buffering to allow for higher frame rates.
  <br />
  
**DAQmx_Scanners/polishedScanner** is largely the equivilent using the Vidrio wrapper, but it's object-oriented and focuses on making a nice and robust OO interface.
It does not implement bidirectional scanning or multiple channels. 


* **scanAndAcquire_OO** - The same features as scanAndAcquire_Polished but in an object-oriented interface. 
It uses the DAQ Toolbox.

* **scannerGUI** - A simple GUI wrapper class for scanAndAcquire_OO. 
This showcases some of the advantages of using object-oriented techniques for data acquisition and GUI-building. 
The scannerGUI class is not supposed to be a complete GUI application. 
Its purpose is to demonstrate how easy it is to wrap an object with a GUI. 
Currently the scannerGUI provides the following features:
  1. Starts/stops scanning.
  2. Switches back and forth between unidirectional and bidirectional modes.
  3. Allows update of the bidirectional phase delay whilst scanning.
  4. Most properties of the object can be changed dynamically during scanning via the GUI. 



* The repository also contains a folder of utility functions. Currently just one for loading the saved TIFF stacks from disk.

# Also see
* For basic DAQmx examples and other introductory concepts see [MatlabDAQmx](https://github.com/tenss/MatlabDAQmx)
* [PTRRupprecht/Instrument-Control](https://github.com/PTRRupprecht/Instrument-Control)
* [HelioScan](http://helioscan.github.io/HelioScan/)
* [SciScan](http://www.scientifica.uk.com/products/scientifica-sciscan)
* [ScanImage](https://vidriotechnologies.com/)
* [LSMAQ](https://github.com/danionella/lsmaq) - which is a very similar project

# Disclaimer
This software is supplied "as is" and the author(s) are not responsible for hardware damage, blindness, etc, caused by use (or misuse) of this software. 
High powered lasers should only be operated by trained individuals. 
It is good practice to confirm the scan waveforms with an oscilloscope before feeding them to the scan mirrors. 
Start with smaller amplitude scan patterns and lower frame rates so as not to damage your scanners. 
Immediately stop scanning if the mirrors make unusual chirping noises and/or the image breaks down.
PMTs can be damaged by normal ambient light levels and must be operated in the dark.
