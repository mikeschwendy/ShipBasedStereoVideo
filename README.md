# ShipBasedStereoVideo

This code is intended to accompany the following paper currently in prep: 
Schwendeman, M. and J. Thomson (In Preparation). Shipboard Stereo Video Measurements of Open Ocean Whitecaps. Journal of Geophysical Research.

It shows how to use Matlab and Matlab Computer Vision System Toolbox to perform measurements of ocean waves from a ship-based stereo video system.  

Our system uses three Pt. Grey Flea2 Cameras directed out from the ship rail, with timestamps contained in the image upper left pixels.  It also uses a NovAtel SPAN GNSS and intertial system to measure camera position and orientation. The HorizonStabilization toolbox (https://github.com/mikeschwendy/HorizonStabilization) is required to measure the camera pitch and roll to synchronize the camera frames with the NovAtel data. This code assumes that the stereo intrinsic and extrinsic parameters have been calibrated.  We use the functions for camera calibration provided with the Matlab Computer Vision System Toolbox.

This code is covered by the BSD License

