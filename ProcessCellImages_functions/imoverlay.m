function out = imoverlay(in, mask, varargin)
%IMOVERLAY Create a mask-based image overlay.
%   OUT = IMOVERLAY(IN, MASK, COLOR) takes an input image, IN, and a binary
%   image, MASK, and produces an output image whose pixels in the MASK
%   locations have the specified COLOR.
%
%   IN should be a grayscale or an RGB image of class uint8, uint16, int16,
%   logical, double, or single.  If IN is double or single, it should be in
%   the range [0, 1].  If it is not in that range, you might want to use
%   mat2gray to scale it into that range.
%
%   MASK should be a two-dimensional logical matrix.
%
%   COLOR should be a 1-by-3 vector of values in the range [0, 1].  [0 0 0]
%   is black, and [1 1 1] is white.
%
%   OUT is a uint8 RGB image.
%
%   Examples
%   --------
%   Overlay edge detection result in green over the original image.
%       
%       I = imread('cameraman.tif');
%       bw = edge(I, 'canny');
%       rgb = imoverlay(I, bw, [0 1 0]);
%       imshow(rgb)
%
%   Treating the output of peaks as an image, overlay the values greater than
%   7 in red.  The output of peaks is not in the usual grayscale image range
%   of [0, 1], so use mat2gray to scale it.
%
%       I = peaks;
%       mask = I > 7;
%       rgb = imoverlay(mat2gray(I), mask, [1 0 0]);
%       imshow(rgb, 'InitialMagnification', 'fit')

%   Steven L. Eddins
%   Copyright 2006-2012 The MathWorks, Inc.


if ~(ndims(in)==2||(ndims(in)==3&&size(in,3)==3))
    error('input must be a 2d image or 2d RGB image');
end

% Force the 2nd input to be logical.
mask = logical(mask);

p=inputParser;
p.CaseSensitive = false;
%default color is white
addOptional(p,'color',[1,1,1],@(x) isnumeric(x)&&numel(x)==3&&all(x>=0)&&all(x<=1));
addParamValue(p,'MaskOrigin',[1,1],@(x) isnumeric(x)&&numel(x)==2);

parse(p,varargin{:});

color = im2double(p.Results.color);

switch(class(in))
    case 'double'
        %do nothing
    case 'single'
        color = im2single(color);
    case 'int16'
        color = im2int16(color);
    case 'uint16'
        color = im2uint16(color);
    case 'uint8'
        color = im2uint8(color);
end


% Make the uint8 the working data class.  The output is also uint8.


% Initialize the red, green, and blue output channels.
if ndims(in) == 2
    % Input is grayscale.  Initialize all output channels the same.
    out_red   = in;
    out_green = in;
    out_blue  = in;
else
    % Input is RGB truecolor.
    out_red   = in(:,:,1);
    out_green = in(:,:,2);
    out_blue  = in(:,:,3);
end

% Replace output channel values in the mask locations with the appropriate
% color value.

[I,J] = ind2sub(size(mask),find(mask));
I = I + round(p.Results.MaskOrigin(1))-1;
J = J + round(p.Results.MaskOrigin(2))-1;

I(I>size(in,1))=[];
J(J>size(in,2))=[];
I(I<1)=[];
J(J<1)=[];

S = sub2ind(size(in),I,J);

out_red(S)   = color(1);
out_green(S) = color(2);
out_blue(S)  = color(3);

% Form an RGB truecolor image by concatenating the channel matrices along
% the third dimension.
out = cat(3, out_red, out_green, out_blue);
