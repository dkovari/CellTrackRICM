function LoadCellImages(filename)
%Load images into a stack using bioforamts import tool
% Input:
%    filename (optional): specify bioformats file to open and load
%       If you don't specify a file then you are prompted to choose a file
%       using the uigetfile GUI.
%
% This loader assumes your data is stored in a single n-dimensional image
% file. You can try loading the included file:
% "ExampleCells - FM1-63 Labeled Macrophages.nd2"
% 
% If you have trouble with the included file, Nikon offers a free viewer
% for nd2 files:
% https://www.nikoninstruments.com/Products/Software/NIS-Elements-Advanced-Research/NIS-Elements-Viewer
%
% After Loading the image data. The software will automatically start the
% image segmenter: ProcessCellData.m
%
% This loader function is built using the LOCI bioformats importer.
% Any of the formats the LOCI importer can read, should be available as
% options when you select your image file.


%% Load Bioformats Importer
if ~exist('bfGetReader.m','file') %check for bioformats_importer library
    addpath(fullfile(fileparts(mfilename('fullpath')),'bfmatlab'));
    if ~exist('bfGetReader.m','file')
        error('Could not find bfmatlab library.');
    end
end

%% add functions to path
%add sub-functions to path
fpath = mfilename('fullpath');
pathstr = fileparts(fpath);
oldpath = addpath(genpath(fullfile(pathstr,'ProcessCellImages_functions')));

%% Select/open file
persistent last_dir;
if nargin<1
    %% Prompt User for data
    [FileName,PathName] = uigetfile(bfGetFileExtensions,'Choose Bio-Formats File.',last_dir);
    
    if FileName==0
        return;
    end
    if ~isempty(PathName)
        last_dir = PathName;
    end
    filename = fullfile(PathName,FileName);
end

if ~exist(filename,'file');
    error('Specified file: %s does not exist',filename);
end

[Dir,~] = fileparts(filename);

%% Load File Info
hDlg = msgbox({'Loading ND2 File Info','Please wait'},'Loading...');
bfreader = bfGetReader(filename);
try
close(hDlg);
catch
end

numSeries = bfreader.getSeriesCount();
numChan = bfreader.getSizeC();

SeriesNum = NaN;
ChanNum = NaN;
%% Prompt user to choose which series and chanels to use for cell image
while isnan(SeriesNum)||isnan(ChanNum)
    if isnan(SeriesNum)
        SeriesNum = 1;
    end
    if isnan(ChanNum)
        ChanNum = 1;
    end
    
    if numSeries>1&&numChan>1
        prom = {sprintf('Position Series (1-%d)',numSeries);...
                sprintf('Channel (1-%d)', numChan)};
        defAns = {sprintf('%d',SeriesNum);sprintf('%d',ChanNum)};
        answer = inputdlg(prom,'Select Series and Channel',1,defAns);
        
        if isempty(answer)
            bfreader.close()
            return;
        end
        
        SeriesNum = str2double(answer{1});
        ChanNum = str2double(answer{2});

    elseif numSeries>1
        prom = sprintf('Position Series (1-%d)',numSeries);
        defAns = {sprintf('%d',SeriesNum)};
        
        answer = inputdlg({prom},'Select Series (Only 1 Channel found)',1,defAns);
        
        if isempty(answer)
            bfreader.close()
            return;
        end
        
        SeriesNum = str2double(answer{1});
    elseif numChan>1
        prom = {sprintf('Channel (1-%d)', numChan)};...
        defAns = {sprintf('%d',ChanNum)};
        answer = inputdlg(prom,'Select Channel (Only one Position)',1,defAns);
        if isempty(answer)
            bfreader.close()
            return;
        end
        
        ChanNum = str2double(answer{1});
    end
    if isempty(SeriesNum)||SeriesNum<1||SeriesNum>numSeries
        SeriesNum = NaN;
    end
    if isempty(ChanNum)||ChanNum<1||ChanNum>numChan
        ChanNum = NaN;
    end
end

%% Prompt for Background
answer = questdlg('Use a background image?');
if ~strcmpi(answer,'yes')
    USE_BG = false;
else
    USE_BG = true;
    [BgName, BgPath] = uigetfile( ...
                        {'*.tif;*.tiff','Image Files (*.tif, *.tiff)'},...
                           'Select background image', Dir);
    if BgName == 0
        USE_BG = false;
    else
        [~,~,ext] = fileparts(BgName);
        if strcmpi(ext,'.nd2')
            disp('dan fix this');
            USE_BG = false;
        else
            BG = double(imread(fullfile(BgPath,BgName)));
            BG = wiener2(BG,[3,3]);
            BG = BG - mean(BG(:));
        end
        [bgH,bgW,~] = size(BG);
        if ~all([bgH,bgW]==[bfreader.getSizeY(),bfreader.getSizeX();])
            USE_BG = false;
            warning('Background is not correct size. Skipping.');
        end
    end
end

%% Load Images
meta = bfreader.getMetadataStore();
bfreader.setSeries(SeriesNum-1);
WIDTH = bfreader.getSizeX();
HEIGHT = bfreader.getSizeY();
numT = bfreader.getSizeT();
CellData.PxScale = double(meta.getPixelsPhysicalSizeY(0).value());
CellData.PxScaleUnit = 'µm';%meta.getPixelsPhysicalSizeX(0).value(ome.units.UNITS.MICROM);

nF = numT;


CellData.Time = NaN(nF,1);

CellData.origstack = zeros(HEIGHT,WIDTH,nF);


hWait = waitbar(0,'Loading Images');
for f=1:nF
    idx = bfreader.getIndex(0,ChanNum-1,f-1)+1;
    Img = double(bfGetPlane(bfreader,idx));
    if USE_BG
        CellData.origstack(:,:,f) = (Img - mean(Img(:))) - BG;
    else
        CellData.origstack(:,:,f) = Img;
    end
    %get timestamp
    dT = meta.getPlaneDeltaT(SeriesNum-1,idx-1);
    CellData.Time(f) = dT.value(ome.units.UNITS.S).doubleValue();
    
    waitbar(f/nF,hWait);
end
try
close(hWait);
catch
end

bfreader.close();

%% Prompt for crop
answer = questdlg('Do you want to crop the images?');
if strcmpi(answer,'cancel')
    return
end
if strcmpi(answer,'yes')
    [Y_CROP,X_CROP] = uicropstack(CellData.origstack,'colormap','gray','clim','average');
    drawnow();
    
    CellData.origstack = CellData.origstack(Y_CROP(1):Y_CROP(2),X_CROP(1):X_CROP(2),:);
else
    Y_CROP = [1,HEIGHT];
    X_CROP = [1,WIDTH];
end

%% Save Cell Data
while true
    [outfile, outpath] = uiputfile('*.mat','Save Cell Data',last_dir);
    if outfile==0
        btn = questdlg('You did not specify a file. Are you sure you dont want to save the data?', 'Exit?', 'Yes', 'No, select file','Yes');
        if strcmpi(btn,'Yes')
            break;
        end
    else
        break;
    end
end
%save data
if outfile~=0
    save(fullfile(outpath,outfile),'-struct','CellData','-append');
    outfile = fullfile(outpath,outfile);
else
    outfile = '*.mat';
end

%% Process Images
btn = questdlg('Do you want to segment the images using?','Segment?','Yes','No','Yes');
if strcmpi(btn,'yes')
    ProcessCellData(CellData,outfile);
end