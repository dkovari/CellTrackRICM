function res = radial_blur(I,R,varargin)
% Radially blur an image using a specified method/function
% Inputs:
%	I:	input image, single value or RGB both work
%	R:	radius of blur region
% Optional Parameters:
%	'method':
%		'linear' uses a symetric linear kernel k=(R-abs(r))
%		'parabolic' parabolic kernel k=R^2-r^2
%		'hat'	a flat hat function
%		'gaussian' convolve with a gaussian of sigma=R/2
%		@fcn(r): kernel generated using a user defined radial function
%	'shape'
%		'same'	(default) uses zero padding, return same size as I, see conv2()
%		'pad'	uses edge padding, returns same size as I
%		'valid' no padding, returns only central region, see conv2()
%		'full' returns full convolution, see conv2()

R = abs(R);
p = inputParser;
addParamValue(p,'method','linear',@isblurmethod);
addParamValue(p,'shape','same',@ischar);

parse(p,varargin{:});

shape = p.Results.shape;
method = p.Results.method;

normalize = @(x) x/sum(x(:));

if isa(method,'function_handle')
    r = -round(R):round(R);
    [xx,yy] = meshgrid(r,r);
    kernel = normalize(sqrt(xx.^2+yy.^2));
end
if ~isa(method,'function_handle')
    switch(lower(method))
        case 'linear'
            r = -round(R):round(R);
            [xx,yy] = meshgrid(r,r);
            kernel = R-sqrt(xx.^2+yy.^2);
            kernel(kernel<0)=0;
            kernel = normalize(kernel);
            %figure();contour3(xx,yy,kernel); title('linear');
        case 'parabolic'
            r = -round(R):round(R);
            [xx,yy] = meshgrid(r,r);
            kernel = R^2-(xx.^2+yy.^2);
            kernel(kernel<0)=0;
            kernel = normalize(kernel);
            %figure();contour3(xx,yy,kernel); title('parabolic');
        case 'gaussian'
			sig = R/2;
            sig_2 = sig^2;
            r = -round(3*sig):round(3*sig);
            [xx,yy] = meshgrid(r,r);
            kernel = normalize(exp(-((xx.^2+yy.^2)/(2*sig_2))));
            %figure();contour3(xx,yy,kernel); title('gaussian');
        case 'hat'
            r = -round(R):round(R);
            kernel = normalize(im2double(BWcircle(R,[round(R)+1,round(R)+1],[2*round(R)+1,2*round(R)+1])));
            %[xx,yy] = meshgrid(r,r);
            %figure();contour3(xx,yy,kernel); title('hat');
    end
end

I = im2double(I);
if strcmpi(shape,'pad')
    I=padarray(I,[floor(length(r)/2),floor(length(r)/2)],'replicate');
    shape = 'valid';
end

res = [];
for c = 1:size(I,3)
    res = cat(3,res,conv2(I(:,:,c),kernel,shape));
end
end

function res = isblurmethod(s)
res = false;
if isa(s,'function_handle')
    res = true;
    return
end
if ischar(s)
    res = any(strcmpi(s,{'linear','parabolic','hat','gaussian'}));
end
end
