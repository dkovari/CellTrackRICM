function AnimateCell(CellData,MovDir,MovName)
% 

%% add functions to path
%add sub-functions to path
fpath = mfilename('fullpath');
pathstr = fileparts(fpath);
oldpath = addpath(genpath(fullfile(pathstr,'ProcessCellImages_functions')));

persistent last_dir;
if nargin<1
    %% Prompt User for data
    %select file
    [File,Dir] = uigetfile(fullfile(last_dir,'*.mat'),'Select .mat file with cell data');
    if File==0
        return
    end
    if ~isempty(Dir)
        last_dir = Dir;
    end
    CellData = load(fullfile(Dir,File));
    [~,name,~] = fileparts(File);
else
    if ischar(CellData)
        if ~exist(CellData,'file')
            error('Could not find the specified file');
        end
        [Dir,name,~] = fileparts(CellData);
        CellData = load(CellData);
    else
        if ~isstruct(CellData)
            error('CellData must be a struct containing tfm variables, or a string specifying the location of a file containing those variables');
        end
        Dir = '';
        name = '*';
    end
end

%% Validate file
if ~isfield(CellData,'origstack')
    error('Data does not include origstack');
end
%if ~isfield(CellData,'PxScale')
    CellData.PxScale = 0.157825;
%    CellData.PxScaleUnit = 'µm';
%end

%if ~isfield(CellData,'PxScaleUnit')
    CellData.PxScaleUnit = 'µm';
%end


%% Initialize Figure
[H,W,nF] = size(CellData.origstack);
PX_SCALE = CellData.PxScale;
FSCALE = 10/100; %px/Pa
DSCALE = 2;
clim=stackclim(CellData.origstack,'average');
cmap = gray(255);

%Plot Time Stamp
SHOW_TIMESTAMP = true;
%Time Stamp Placement
TIME_FONT_SIZE = 28;
yloc = 0.99; %top of text (frac of axis)
xloc = 0.01; %left of text (frac of axis)

%location and size of scalebar
%Scale bar size in px
SB_FONT_SIZE = 28;
SB_LENGTH = 20; %Âµm
SB_WIDTH = 6; %figure points
PX_LENGTH = SB_LENGTH/(PX_SCALE);

RELATIVE_SB  = true; %place scalebar relative to axes corner
SB_POS = [0.05,0.05]; %position of scalebar [x,y]
SB_X = [10,10 + PX_LENGTH]; %non-relative position of SB
SB_Y = [30,30];%non-relative position of SB



%% setup fig and axes
hfig = figure('units','pixels','Position',[0,0,2*W+20,2*H+20]);
hax = axes('Parent',hfig);

%setup image
imbase = ind2rgb( gray2ind( mat2gray(CellData.origstack(:,:,1),clim),size(cmap,1)),cmap);
hImage = image('Parent',hax,'CData',imbase,'handlevisibility','off');
axis(hax,'xy','image');

set(hax,'box','off',...
    'xtick',[],...
    'ytick',[]);

if RELATIVE_SB
    YLIM = get(hax,'ylim');
    XLIM = get(hax,'xlim');
    SB_X = XLIM(1)+SB_POS(1)*(XLIM(2)-XLIM(1)) + [0,PX_LENGTH];
    SB_Y = YLIM(1)+SB_POS(2)*(YLIM(2)-YLIM(1)) + [0,0];
end
 


% Time stamp
YLIM = get(gca,'ylim');
XLIM = get(gca,'xlim');

switch get(gca,'xdir')
    case 'normal'
        xloc = XLIM(1)+xloc*(XLIM(2)-XLIM(1));
    case 'reverse'
        xloc = XLIM(2)-xloc*(XLIM(2)-XLIM(1));
end
switch get(gca,'ydir')
    case 'normal'
        yloc = YLIM(1)+yloc*(YLIM(2)-YLIM(1));
    case 'reverse'
        yloc = yLIM(2)-yloc*(YLIM(2)-YLIM(1));
end

Anim(nF) = struct('cdata',[],'colormap',[]);
%pause;
for f=1:nF
    cla(hax);
    
    %make rgb data
    imbase = ind2rgb( gray2ind( mat2gray(CellData.origstack(:,:,f),clim),size(cmap,1)),cmap);
    
    %show rgb image
    set(hImage,'CData',imbase);
    
    axis(hax,'xy','image');
    hold(hax,'on');
    
    
    %Time Stamp
    if SHOW_TIMESTAMP
        str = sprintf('Time: %04.01f min',(CellData.Time(f)-CellData.Time(1))/60);
        text(xloc,yloc,str,'parent',hax,'Color','w','VerticalAlignment','top','HorizontalAlignment','Left','FontSize',TIME_FONT_SIZE);
    end
    
    %Plot ScaleBar
    text(mean(SB_X),mean(SB_Y)+2*SB_WIDTH,sprintf('%d µm',SB_LENGTH),'parent',hax,'color','w','VerticalAlignment','bottom','HorizontalAlignment','center','FontSize',SB_FONT_SIZE);
    plot(hax,SB_X,SB_Y,'-w','LineWidth',SB_WIDTH);
    
    %save frame to animation
    xlim(hax,XLIM);
    ylim(hax,YLIM);
    
    Anim(f) = getframe(hax);
end
try
close(hfig);
catch
end

%putvar(Anim);
%implay(Anim);

%% Save mp4
if nargin>1
    if nargin>2
        [~,name,~] = fileparts(MovName);
    else
        if strcmp(name,'*')
            name = 'CellVideo';
        end
    end
    mov_file =[name,'.mp4'];
    mov_path = MovDir;
else
    [mov_file, mov_path] = uiputfile(fullfile(Dir,[name,'.mp4']),'Save Animation?');
end
if mov_file~=0
    %crop anim data to same size (this is a hack)
    Anim = SameSizeAnim(Anim);
    
    writerObj = VideoWriter(fullfile(mov_path,mov_file),'MPEG-4');
    writerObj.FrameRate = 5;
    open(writerObj);
    writeVideo(writerObj,Anim);
    close(writerObj);
end