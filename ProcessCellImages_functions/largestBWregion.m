function BW2 = largestBWregion(BW,conn)

if nargin<2
    conn = 8;
end

%BW = logical(BW);

L = bwlabel(BW,conn);

stats = regionprops(L,'Area');
[~,idx] = max([stats(:).Area]);
if numel(idx)>0
    BW2 = L==idx(1);
else
    BW2 = false(size(BW));
end

