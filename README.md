## Synopsis
This is a collection of tools for segmenting images of cells within MATLAB. 

## Usage
1. Copy this entire directory to your matlab path.
2. Run LoadCellImages.m
3. Follow the prompts to load file and crop images.
4. After loading images, the image segmenter (ProcessCellData.m) is automatically started

## Processing Cell Images
The image segmenter was originally designed to analyze cell footprints imaged under RICM.
Image segmenting is done using 3 main parameters:
- Ilow: Pixels below this value are included in the segmented image
  
-  Ihigh: Pixels above this value are included
  
- StdLim: Pixels that are part of a 3x3 neighborhood with a standard deviation greater than this value are included

Other Options:
-  Fill Holes: Fills in holes in the segmented image. Holes must be completely surrounded by included pixels
- LargestOnly: keeps only the largest area
-  Blur: Binary segmented image is convolved with a gausian having width="Blur" number of pixels. This has the effect of smoothing the edge of the segmented image.
- Fill Holes (Gray): applies the fill operation after bluring the image.
-  Levelset Value: value (from 0 to 1) above which the blured image image is thersholded.
- Minimum Size: minimum size a region of included pixels must be in order to be included in final segmented image.
