function stack2 = bwperimstack(stack,varargin)
%dilate images in an image stack

if ndims(stack)>3
    error('stack must be 3-d: [H,W,numFrames]');
end
stack2(size(stack,1),size(stack,2),size(stack,3)) = 0;
for f = 1:size(stack,3)
    stack2(:,:,f) = bwperim(stack(:,:,f),varargin{:});
end
