function [rgbstack,clim] = gray2rgb_stack(stack,cmap,clim)
%convert grayscale stack into rgb stack
% Inputs:
%   stack
%   cmap: colormap to use, either [Nx3] matrix specifying the map
%                          or a string like 'gray' specifying a built in
%                          colormap
%   clim: color limits, [low,high]
%           alternatively specify the string
%           'auto': use min and max of each frame
%           'global': use min,max for all frames
%           'average': average min,max for the frames
% Returns an RGB stack: [Y,X,C,nFrames]
if ischar(clim)
    switch lower(clim)
        case 'auto'
            clim = 'auto';
        case 'global'  %calculate global limits
            clim = [nanmin(stack(:)), nanmax(stack(:))];
        case 'average'  %calc average limits
            Maxlist = nan(size(stack,3),1);
            Minlist = Maxlist;
            for f = 1:size(stack,3)
                Maxlist(f) = nanmax(reshape(stack(:,:,f),[],1));
                Minlist(f) = nanmin(reshape(stack(:,:,f),[],1));
            end
            clim = [nanmean(Minlist),nanmean(Maxlist)];
        otherwise
            warn('invalid clim method');
    end
end


if ischar(cmap)
    cmap = eval(cmap);
end
if ~ismatrix(cmap)||size(cmap,2)~=3
    error('incorrect colormap');
end

rgbstack = zeros(size(stack,1),size(stack,2),3,size(stack,3));

for f=1:size(stack,3)
    if ischar(clim)&&strcmpi('auto',clim)
            cl = [min(nanmin(stack(:,:,f))), max(nanmax(stack(:,:,f)))];
            rgbstack(:,:,:,f) = ind2rgb( gray2ind( mat2gray(stack(:,:,f),cl),size(cmap,1)),cmap);
    else
        rgbstack(:,:,:,f) = ind2rgb( gray2ind( mat2gray(stack(:,:,f),clim),size(cmap,1)),cmap);
    end
end