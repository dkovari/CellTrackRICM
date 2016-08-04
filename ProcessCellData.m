function ProcessCellData(CellData,default_savefile)
%GUI for processing cell images
% Input:
%   CellData (optional):
%     String specifying file to open (e.g. yourcelldata.mat)
%           File must contain variable named origstack
%     Struct containing celldata
%           origstack must be a field in specified struct
%
%  default_savefile:
%   String specifying default file name when saving data
%
%==========================================================================
% Copyright 2016 Daniel T. Kovari, Emory University, Georgia Tech
% All rights reserved.

%% add functions to path
%add sub-functions to path
fpath = mfilename('fullpath');
pathstr = fileparts(fpath);
oldpath = addpath(genpath(fullfile(pathstr,'ProcessCellImages_functions')));

%% Load Data
persistent last_dir;
if nargin<1

    %select file
    [File,Dir] = uigetfile(fullfile(last_dir,'*.mat'),'Select cell data file');
    if File==0
        return
    end
    if ~isempty(Dir)
        last_dir = Dir;
    end

    CellData = load(fullfile(Dir,File));
    default_savefile = fullfile(Dir,File); 

elseif ischar(CellData)
    if exist(CellData,'file');
        if nargin<2
            default_savefile = CellData;
        end
        CellData = load(CellData);        
    else
        error('File: %s does not exist',CellData);
    end
elseif isstruct(CellData)
    File = '*.mat';
    Dir = '';
    if nargin<2
        default_savefile = fullfile(Dir,File);
    end
elseif ~isstruct(CellData)
    error('wrong argument type');
end

%% validate data
if ~isfield(CellData,'origstack')
    error('Structure must contain field origdata');
end

%dat_range = prctile(CellData.origstack(:),[5,95]);
%dat_mean = mean(CellData.origstack(:));

if ~isfield(CellData,'Ilow')
    CellData.Ilow = -Inf;
end
if ~isfield(CellData,'Ihigh')
    CellData.Ihigh = Inf;
end
if ~isfield(CellData,'StdLim')
    CellData.StdLim = Inf;
end
if ~isfield(CellData,'FillHoles')
    CellData.FillHoles = true;
end
if ~isfield(CellData,'LargestOnlyTH')
    CellData.LargestOnlyTH = false;
end
if ~isfield(CellData,'Blur')
    CellData.Blur = 3;
end
if ~isfield(CellData,'FillHolesLS')
    CellData.FillHolesLS = true;
end
if ~isfield(CellData,'LevesSetVal')
    CellData.LevelSetVal = 0.5;
end
if ~isfield(CellData,'MinSize')
    CellData.MinSize = 30;
end
if ~isfield(CellData,'PxScale')
    pxans = {};
    while isempty(pxans)
        pxans = inputdlg({'Pixel Scale (unit/px)','Scale Unit'},'Pixel Scale',2,{num2str(0.157825),'µm'});
    end
            
    CellData.PxScale = num2str(pxans{1});
    CellData.PxScaleUnit = pxans{2};
end

if ~isfield(CellData,'PxScaleUnit')
    pxans = {};
    while isempty(pxans)
        pxans = inputdlg({'Scale Unit'},'Pixel Scale',1,{'µm'});
    end
    CellData.PxScaleUnit = pxans{1};
end

%% StackFig
hPlotFig = figure();
[RGBostack,clim] = gray2rgb_stack(CellData.origstack,'gray','average');
%Create stack figure
hStackFig = stackfig(RGBostack,'Clim',clim,'frameupdate_fn',@FrameChange,'colormap','gray');
colorbar;
set(hStackFig,'CloseRequestFcn',@CloseProc);

%% Create Threshold GUI
%global hThreshFig;
hThreshFig = figure('Name','Threshold Controls',...
                    'NumberTitle','off',...
                    'toolbar','none',...
                    'menubar','none',...
                    'DockControls','off',...
                    'CloseRequestFcn',@CloseProc);

%% Position Definitions for menu
line_height = 2.2; %char


set(hThreshFig,...
    'units','characters',...
    'position',[0,0,40,11*line_height]);
movegui(hThreshFig,'center');

fig_ext = get(hThreshFig,'position');

button_height = 2;
button_pad = (line_height-button_height)/2;

text_height = 1.2;
text_pad = (line_height-text_height)/2;

edit_height = 1.6;
edit_pad = (line_height-edit_height)/2;

check_height = 1.6;
check_pad = (line_height-check_height)/2;

col_1_start = 2;
col_1_width = 15;

col_2_start = col_1_start+col_1_width+1.5;

cur_y = fig_ext(4)-1.5*line_height;

%% Ilow
hTxt_Ilow = uicontrol(hThreshFig,'style','text',...
                        'units','characters',...
                        'position',[col_1_start, cur_y+text_pad, col_1_width, text_height],...
                        'HorizontalAlignment','right',...
                        'string','I_low:');
hEdt_Ilow = uicontrol(hThreshFig,'style','edit',...
                        'units','characters',...
                        'position',[col_2_start, cur_y+edit_pad, 10, edit_height],...
                        'HorizontalAlignment','center',...
                        'TooltipString','Low value of image intensity. Keep pixels less than this value',...
                        'string',num2str(CellData.Ilow),...
                        'Callback',@pci_edit_Ilow);
                    
hBtn_Ilow = uicontrol(hThreshFig,'style','pushbutton',...
                        'units','characters',...
                        'position',[col_2_start + 10.5, cur_y+edit_pad, 10, edit_height],...
                        'HorizontalAlignment','center',...
                        'TooltipString','Select intensity from points on figure',...
                        'string','Select',...
                        'Callback',@pci_btn_Ilow);
cur_y = cur_y-line_height;

%% Ihigh
hTxt_Ihigh = uicontrol(hThreshFig,'style','text',...
                        'units','characters',...
                        'position',[col_1_start, cur_y+text_pad, col_1_width, text_height],...
                        'HorizontalAlignment','right',...
                        'string','I_high:');
hEdt_Ihigh = uicontrol(hThreshFig,'style','edit',...
                        'units','characters',...
                        'position',[col_2_start, cur_y+edit_pad, 10, edit_height],...
                        'HorizontalAlignment','center',...
                        'TooltipString','High value of image intensity. Keep pixels larger than this value.',...
                        'string',num2str(CellData.Ihigh),...
                        'Callback',@pci_edit_Ihigh);
hBtn_Ihigh = uicontrol(hThreshFig,'style','pushbutton',...
                        'units','characters',...
                        'position',[col_2_start + 10.5, cur_y+edit_pad, 10, edit_height],...
                        'HorizontalAlignment','center',...
                        'TooltipString','Select intensity from points on figure',...
                        'string','Select',...
                        'Callback',@pci_btn_Ihigh);
cur_y = cur_y-line_height;

%% StdLim
hTxt_StdLim = uicontrol(hThreshFig,'style','text',...
                        'units','characters',...
                        'position',[col_1_start, cur_y+text_pad, col_1_width, text_height],...
                        'HorizontalAlignment','right',...
                        'string','StdLim:');
hEdt_StdLim = uicontrol(hThreshFig,'style','edit',...
                        'units','characters',...
                        'position',[col_2_start, cur_y+edit_pad, 12, edit_height],...
                        'HorizontalAlignment','center',...
                        'TooltipString','Value of local std. dev. used in threshold. Keeps pixels above this value.',...
                        'string',num2str(CellData.StdLim),...
                        'Callback',@pci_edit_StdLim);
cur_y = cur_y-line_height;

%% fill holes
hTxt_FillHoles = uicontrol(hThreshFig,'style','text',...
                        'units','characters',...
                        'position',[col_1_start, cur_y+text_pad, col_1_width, text_height],...
                        'HorizontalAlignment','right',...
                        'string','Fill Holes:');
hChk_FillHoles = uicontrol(hThreshFig,'style','checkbox',...
                        'units','characters',...
                        'position',[col_2_start, cur_y+check_pad, 5, check_height],...
                        'HorizontalAlignment','center',...
                        'TooltipString','Fill holes in thresholded image',...
                        'string','',...
                        'value',CellData.FillHoles,...
                        'Callback',@pci_chk_FillHoles);
cur_y = cur_y-line_height;

%% Largest Only
hTxt_LargestOnly = uicontrol(hThreshFig,'style','text',...
                        'units','characters',...
                        'position',[col_1_start, cur_y+text_pad, col_1_width, text_height],...
                        'HorizontalAlignment','right',...
                        'string','LargestOnly:');
hChk_LargestOnly = uicontrol(hThreshFig,'style','checkbox',...
                        'units','characters',...
                        'position',[col_2_start, cur_y+check_pad, 5, check_height],...
                        'HorizontalAlignment','center',...
                        'TooltipString','Keep only the largest contiquous region.',...
                        'string','',...
                        'value',CellData.LargestOnlyTH,...
                        'Callback',@pci_chk_LargestOnlyTH);
cur_y = cur_y-line_height;

%% Blur
hTxt_BLur = uicontrol(hThreshFig,'style','text',...
                        'units','characters',...
                        'position',[col_1_start, cur_y+text_pad, col_1_width, text_height],...
                        'HorizontalAlignment','right',...
                        'string','Blur:');
hEdt_blur = uicontrol(hThreshFig,'style','edit',...
                        'units','characters',...
                        'position',[col_2_start, cur_y+edit_pad, 12, edit_height],...
                        'HorizontalAlignment','center',...
                        'TooltipString','Radius of blur to use for levelset',...
                        'string',num2str(CellData.Blur),...
                        'Callback',@pci_edit_blur);
cur_y = cur_y-line_height;

%% Fill Holes
hTxt_FillHoles2 = uicontrol(hThreshFig,'style','text',...
                        'units','characters',...
                        'position',[col_1_start, cur_y+text_pad, col_1_width, text_height],...
                        'HorizontalAlignment','right',...
                        'string','Fill Holes (gray):');
hChk_FillHoles2 = uicontrol(hThreshFig,'style','checkbox',...
                        'units','characters',...
                        'position',[col_2_start, cur_y+check_pad, 5, check_height],...
                        'HorizontalAlignment','center',...
                        'TooltipString','Fill holes using grayscale fill',...
                        'string','',...
                        'value',CellData.FillHolesLS,...
                        'Callback',@pci_chk_FillHolesLS);
cur_y = cur_y-line_height;

%% LevelSetVal
hTxt_LevelSetVal = uicontrol(hThreshFig,'style','text',...
                        'units','characters',...
                        'position',[col_1_start, cur_y+text_pad, col_1_width, text_height],...
                        'HorizontalAlignment','right',...
                        'string','Levelset Value:');
hEdt_LevelSetVal = uicontrol(hThreshFig,'style','edit',...
                        'units','characters',...
                        'position',[col_2_start, cur_y+edit_pad, 12, edit_height],...
                        'HorizontalAlignment','center',...
                        'TooltipString','Value of levelset to use for contour',...
                        'string',num2str(CellData.LevelSetVal),...
                        'Callback',@pci_edit_LSval);
cur_y = cur_y-line_height;

%% Filter Minimum Size
hTxt_MinSize = uicontrol(hThreshFig,'style','text',...
                        'units','characters',...
                        'position',[col_1_start, cur_y+text_pad, col_1_width, text_height],...
                        'HorizontalAlignment','right',...
                        'string','Minimum Size:');
hEdt_MinSize = uicontrol(hThreshFig,'style','edit',...
                        'units','characters',...
                        'position',[col_2_start, cur_y+edit_pad, 12, edit_height],...
                        'HorizontalAlignment','center',...
                        'TooltipString','Spots smaller than this size (in pixels) are removed',...
                        'string',num2str(CellData.MinSize),...
                        'Callback',@pci_edit_MinSize);
cur_y = cur_y-line_height;

%% Process Stack
hBtn_ProccessStack = uicontrol(hThreshFig,'style','pushbutton',...
                        'units','characters',...
                        'position',[col_1_start+2,cur_y+button_pad,fig_ext(3)-col_1_start-4,button_height],...
                        'HorizontalAlignment','center',...
                        'TooltipString','Process image stack using parameters',...
                        'string','Process',...
                        'Callback',@pci_btn_proc);

%% Variables used in functions
%CellData
%hStackFig
nF = size(CellData.origstack,3);
ProcessedFrame = false(nF,1); %frames that have been processed with current paramters
CellData.data = NaN(size(CellData.origstack));
CellData.threshstack = false(size(CellData.origstack));

%% Save on Close
    function CloseProc(~,~)
        [pth,~,~] = fileparts(default_savefile);
        if ~isempty(pth)&&~exist(pth,'dir')
            mkdir(pth);
            made_dir = true;
        else
            made_dir = false;
        end
        
        [FileName,PathName] = uiputfile(default_savefile,'Save Data');
        if FileName==0
            if made_dir
                rmdir(pth);
            end
            answer = questdlg('You did not select a file. Do you still want to close?');
            if strcmpi(answer,'yes')
                try
                delete(hStackFig);
                delete(hThreshFig);
                delete(hPlotFig);
                catch
                end
            else
                return;
            end
        else
            h = msgbox('Saving. Please wait','Saving');
            ApplyThreshold(1:nF);
            try
            if ~exist(fullfile(PathName,FileName),'file')
                save(fullfile(PathName,FileName),'-struct','CellData');
            else
                save(fullfile(PathName,FileName),'-struct','CellData','-append');
            end
            catch
                warning('Could not save file. Try pausing dropbox.');
                close(h);
                return
            end
            close(h);
            try
            delete(hStackFig);
            delete(hThreshFig);
            delete(hPlotFig);
            catch
            end
        end
    end
                    
%% Button Functions
    function pci_btn_proc(~,~)
        ApplyThreshold(1:nF);
    end
    function pci_edit_LSval(hObj,~)
        val = str2double(get(hObj,'string'));
        if ~isnan(val)&&val>=0
            if val~=CellData.LevelSetVal
                ProcessedFrame = false(nF,1);
                CellData.LevelSetVal = val;
            end
        end
        set(hObj,'string',num2str(CellData.LevelSetVal));
        proc_frame();
    end
    function pci_chk_FillHolesLS(hObj,~)
        val = get(hObj,'value');
        if val~=CellData.FillHolesLS;
            ProcessedFrame = false(nF,1);
            CellData.FillHolesLS = val;
        end
        proc_frame();
    end
    function pci_edit_blur(hObj, ~)
        val = str2double(get(hObj,'string'));
        if ~isnan(val)&&val>=0
            if val~=CellData.Blur
                ProcessedFrame = false(nF,1);
                CellData.Blur = val;
            end
        end
        set(hObj,'string',num2str(CellData.Blur));
        proc_frame();
    end
    function pci_chk_LargestOnlyTH(hObj,~)
        val = get(hObj,'value');
        if val~=CellData.LargestOnlyTH;
            ProcessedFrame = false(nF,1);
            CellData.LargestOnlyTH = val;
        end
        proc_frame();
    end
    function pci_chk_FillHoles(hObj,~)
        val = get(hObj,'value');
        if val~=CellData.FillHoles;
            ProcessedFrame = false(nF,1);
            CellData.FillHoles = val;
        end
        proc_frame();
    end
    function pci_edit_StdLim(hObj,~)
        val = str2double(get(hObj,'string'));
        if ~isnan(val)&&val>=0
            if val~=CellData.StdLim
                ProcessedFrame = false(nF,1);
                CellData.StdLim = val;
            end
        end
        set(hObj,'string',num2str(CellData.StdLim));
        proc_frame();
    end
    function pci_edit_Ihigh(hObj,~)
        val = str2double(get(hObj,'string'));
        if ~isnan(val)
            if val~=CellData.Ihigh
                ProcessedFrame = false(nF,1);
                CellData.Ihigh = val;
            end
        end
        set(hObj,'string',num2str(CellData.Ihigh));
        proc_frame();
    end

    function pci_edit_Ilow(hObj,~)
        val = str2double(get(hObj,'string'));
        if ~isnan(val)
            if val~=CellData.Ilow
                ProcessedFrame = false(nF,1);
                CellData.Ilow = val;
            end
        end
        set(hObj,'string',num2str(CellData.Ilow));
        proc_frame();
    end

    function pci_edit_MinSize(hObj,~)
        val = str2double(get(hObj,'string'));
        if ~isnan(val)
            if val~=CellData.MinSize
                ProcessedFrame = false(nF,1);
                CellData.MinSize = val;
            end
        end
        set(hObj,'string',num2str(CellData.MinSize));
        proc_frame();
    end

    function pci_btn_Ilow(~,~)
        figure(hStackFig);
        title('Select points then press enter');
        [x,y] = ginput();
        title('');
        if isempty(x)
            return;
        end
        handles = guidata(hStackFig);
        x=round(x);
        y=round(y);
        
        y(x<1) = [];
        x(x<1) = [];
        
        x(y<1) = [];
        y(y<1) = [];
        
        y(x>size(CellData.origstack,2)) = [];
        x(x>size(CellData.origstack,2)) = [];
        
        x(y>size(CellData.origstack,1)) = [];
        y(y>size(CellData.origstack,1)) = [];
        
        if isempty(x)
            return;
        end
        old_low = CellData.Ilow;
        CellData.Ilow = 0;
        acc = 0;
        for n=1:numel(x)
            if ~isnan(CellData.origstack(y(n),x(n),handles.curFrame))
                CellData.Ilow = CellData.Ilow+CellData.origstack(y(n),x(n),handles.curFrame);
                acc = acc+1;
            end
        end
        if acc==0
            CellData.Ilow = old_low;
        else
            CellData.Ilow = CellData.Ilow/acc;
        end
        set(hEdt_Ilow ,'string',num2str(CellData.Ilow));
        proc_frame();
    end
    
    function pci_btn_Ihigh(~,~)
        figure(hStackFig);
        title('Select points then press enter');
        [x,y] = ginput();
        title('');
        
        handles = guidata(hStackFig);
        x=round(x);
        y=round(y);
        
        y(x<1) = [];
        x(x<1) = [];
        
        x(y<1) = [];
        y(y<1) = [];
        
        y(x>size(CellData.origstack,2)) = [];
        x(x>size(CellData.origstack,2)) = [];
        
        x(y>size(CellData.origstack,1)) = [];
        y(y>size(CellData.origstack,1)) = [];
        
        if isempty(x)
            return;
        end
        old_high = CellData.Ihigh;
        CellData.Ihigh = 0;
        acc=0;
        for n=1:numel(x)
            if ~isnan(CellData.origstack(y(n),x(n),handles.curFrame))
                CellData.Ihigh = CellData.Ihigh+CellData.origstack(y(n),x(n),handles.curFrame);
                acc = acc+1;
            end
        end
        if acc==0
            CellData.Ihigh = old_high;
        else
            CellData.Ihigh = CellData.Ihigh/acc;
        end
        set(hEdt_Ihigh,'string',num2str(CellData.Ihigh));
        proc_frame();
    end
    
%% Proc_Frame()
    function proc_frame() %process current frame only
        handles = guidata(hStackFig);
        if ~ProcessedFrame(handles.curFrame) %only proc if needed
            ApplyThreshold(handles.curFrame);
        end
        %change focus back to settings window
        if ishghandle(hThreshFig)
            figure(hThreshFig);
        end
    end
%% FrameChange()
    function FrameChange(hFig)
        handles = guidata(hFig);
        if ~ProcessedFrame(handles.curFrame) %only proc if needed
            ApplyThreshold(handles.curFrame);
        else
            if ~ishandle(hPlotFig)
                hPlotFig = figure();
            else
                figure(hPlotFig);
            end
            clf;
            hold on;
            if isfield(CellData,'Time')
                plot(CellData.Time,CellData.Area,'-');
                plot(CellData.Time(handles.curFrame),CellData.Area(handles.curFrame),'x');
                xlabel('Time [s]');
            else
                plot(1:nF,CellData.Area,'-');
                plot(handles.curFrame,CellData.Area(handles.curFrame),'x');
                xlabel('Frame');
            end
            ylabel(sprintf('Area [%s^2]',CellData.PxScaleUnit));
        end
        %change focus back to stackfi
        if ishghandle(hStackFig)
            figure(hStackFig);
        end
    end
%% ApplyThreshold
    function ApplyThreshold(frames)
        try
        handles = guidata(hStackFig);
        rgb_stack = handles.stack;
            NO_STACKFIG = false;
        catch
            NO_STACKFIG = true;
        end
        for f=frames
            if ProcessedFrame(f)
                continue
            end
            stdim = stdfilt(CellData.origstack(:,:,f),ones(3,3));
            thr = CellData.origstack(:,:,f)<CellData.Ilow|CellData.origstack(:,:,f)>CellData.Ihigh;
            %figure(80); imagesc(thr); title('Ilow Ihigh')
            thr = thr|(stdim>CellData.StdLim);
            %figure(81); imagesc(stdim); title('std');
            %figure(82); imagesc(CellData.origstack(:,:,f)); colormap gray; title('orig');
            if CellData.FillHoles
                thr = imfill(thr,'holes');
            end
            if CellData.LargestOnlyTH&&CellData.FillHoles
                thr = largestBWregion(thr);
            end
            thr = double(thr);
            if CellData.Blur > 0
                 thr = radial_blur(thr,CellData.Blur,'method','linear');
            end
            if CellData.Blur>0&&CellData.FillHolesLS
                thr = imfill(thr);
            end
            CellData.data(:,:,f) = thr;
            CellData.threshstack(:,:,f) = thr>CellData.LevelSetVal;
            
            if CellData.MinSize>0
                th = bwareaopen(CellData.threshstack(:,:,f),CellData.MinSize);
                if CellData.Blur>0
                    th = imdilate(th,strel('disk',CellData.Blur+1));
                    %figure(91);imagesc(CellData.data(:,:,f));
                    CellData.data(:,:,f) = CellData.data(:,:,f).*th;
                    %figure(90);imagesc(CellData.data(:,:,f));
                    CellData.threshstack(:,:,f) = CellData.data(:,:,f)>CellData.LevelSetVal;
                else
                    CellData.data(:,:,f) = th;
                    CellData.threshstack(:,:,f) = th;
                end
            end
            
            if ~NO_STACKFIG
                OL = bwperim(CellData.threshstack(:,:,f));
                %figure(); imagesc(OL);
                rgb_stack(:,:,:,f) = imoverlay(RGBostack(:,:,:,f),OL,'color',[1,1,0]);
                %figure();image(rgb_stack(:,:,:,f));
                %figure();image(RGBostack(:,:,:,f));
            end

            ProcessedFrame(f) = true;
        end
        if ~NO_STACKFIG
            handles.stack = rgb_stack;
            guidata(hStackFig,handles);
            %force image update for current frame
            set(handles.hImg,'CData',handles.stack(:,:,:,handles.curFrame));
        end
        
        % calc and plot area
        CellData.Area = NaN(nF,1);
        CellData.Area(ProcessedFrame) = sum(sum(CellData.threshstack(:,:,ProcessedFrame),1),2)*(CellData.PxScale^2);
        
        if ~ishandle(hPlotFig)
            hPlotFig = figure();
        else
            figure(hPlotFig);
        end
        clf;
        hold on;
        if isfield(CellData,'Time')
            plot(CellData.Time,CellData.Area,'-');
            plot(CellData.Time(handles.curFrame),CellData.Area(handles.curFrame),'x');
            xlabel('Time [s]');
        else
            plot(1:nF,CellData.Area,'-');
            plot(handles.curFrame,CellData.Area(handles.curFrame),'x');
            xlabel('Frame');
        end
        ylabel(sprintf('Area [%s^2]',CellData.PxScaleUnit));
    end
end





