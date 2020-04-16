%% Initialization Code
function varargout = Arduino_DAC(varargin)
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @Arduino_DAC_OpeningFcn, ...
                   'gui_OutputFcn',  @Arduino_DAC_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end
if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT

% --- Executes just before Arduino_DAC is made visible.
function Arduino_DAC_OpeningFcn(hObject, ~, handles, varargin)
handles.output = hObject;
guidata(hObject, handles);
global  track log gaugenum saved request wait rownum count time_log file_date
track = 0;
time_log = []; %for troubleshooting
count = 0;
rownum = [];
for i = 1:4
    fit_temp.fit{i} = [];
end
request = [];
saved = [1 1];
tmpdat = [];
gaugenum = 1;
log.year = {};
log.month = {};
log.day = {};
log.clock = {};
log.data = {};
wait = 3;
config = cfg();
handles.Calibration_Measurements.Data = [];
handles.Calibration_Measurements.ColumnName = config.main.cal;
handles.Calibration_Measurements.ColumnWidth = {config.main.width};
handles.Calibration_Values.ColumnName = config.consts.names;
handles.Calibration_Values.ColumnWidth = {config.consts.width};
datamat = [];
for i = 1:4
datamat = [datamat; [config.consts.vals{i}]];
end
handles.Calibration_Values.Data = datamat;
handles.Calibration_Values.RowName = config.consts.gauges;
handles.Parameter_Select.String = config.consts.names;
handles.Measurement_Type.String = config.meas.type;
handles.Measurement_Type.Value = findcell(config.meas.type,'Pressure');
handles.Fit_Type.String = config.fits.names;
handles.Baud.String = config.serial.baudnames;
handles.Baud.Value = 10;
handles.Ref_Units.String = config.meas.Pressure;
handles.Desired_Units.String = config.meas.Pressure;
if isfile('tempdata.mat')
   answer = questdlg('Crash detected, would you like to load data?','Crash Detected','Yes','No','Default');
   switch answer
       case 'Yes'
       saved(1) = false;
       dat = open('tempdata.mat');
       handles.Calibration_Measurements.Data = dat.data;
       case 'No' 
       save('tempdata','tmpdat');
   end
end
save('fit_temp.mat','fit_temp');
addlistener(handles.slider1 ,'Value', 'PostSet', @ContSliderDragCB);
addlistener(handles.slider2 ,'Value', 'PostSet', @ContSliderDragCB2);

function varargout = Arduino_DAC_OutputFcn(hObject, eventdata, handles) 
varargout{1} = handles.output;
init_plot(hObject,[],handles);
UpdatePlot(hObject,eventdata,handles);
config = cfg();
if config.last
    Connect_Callback(hObject, eventdata, handles)
end

%% Callbacks
function Connect_Callback(hObject, eventdata, handles)
global ard log request
switch handles.Connect.String
    case 'Connect'
    closeS();
    S = seriallist;
    config = cfg();
    selection = handles.Baud.Value;
    baud = config.serial.bauds(selection);
if numel(S)<2
    msgbox("No device connected.")
    return
end
for i = 2:numel(S)
    ard = serial(S(i));
    ard.BaudRate = baud;
    ard.Timeout = 1.5;
    try
        fopen(ard);
%         pause(0.5); %Delay is needed for an ESP32 as an initial startup outputs ~350 bytes
        wait = 0;
        while ard.BytesAvailable < 14
            wait = wait+1;
            pause(0.2);
            if wait == 10
                error();
            end
        end
        input = fread(ard,ard.BytesAvailable);
        textcheck = char(input.');
    if ~isempty(strfind(textcheck,'SRS_ADC'))
        fclose(ard);
        break
    end
    catch
    end
    if i==numel(S)
        msgbox("Did not find DAC.");
        return
    end
end
fclose(ard);
try
clearlog(hObject,eventdata,handles);
ard.BytesAvailableFcnCount = 3;
ard.BytesAvailableFcnMode = 'byte';
ard.BytesAvailableFcn = {@sread,hObject};
ard.Timeout = 0.1;
fopen(ard);
pause(1.5);
set(handles.Com_Port,'String',S(i));
handles.Connect.String = 'Disconnect';
handles.Get_Readings.Enable = 'On';
handles.Time_Log.Enable = 'On';
handles.Upload.Enable = 'On';
GetC_Callback(hObject, eventdata, handles)
catch
msgbox("Failed to connect.");
end
    case 'Disconnect'
        fclose(ard);
        closeS();
        request = [];
        handles.Connect.String = 'Connect';
        handles.Com_Port.String = '';
        handles.Time_Log.Enable = 'Off';
        handles.Get_Readings.Enable = 'Off';
        handles.Upload.Enable = 'Off';
end

function Baud_Callback(hObject, eventdata, handles)

function Baud_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


function Measurement_Type_Callback(hObject, eventdata, handles)
config = cfg();
indx = handles.Measurement_Type.Value;
strng = config.meas.type{indx};
handles.Ref_Units.String = config.meas.(strng);
handles.Desired_Units.String = config.meas.(strng);
handles.Ref_Units.Value = 1;
handles.Desired_Units.Value = 1;


function Measurement_Type_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function Serial_Log_Callback(hObject, eventdata, handles)

function Serial_Log_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function Get_Readings_Callback(hObject, eventdata, handles)
global ard request wait
if isempty(ard)
    msgbox("Not attached to an arduino.")
    return
end
config = cfg();
request = 'raw';
wait = 18;
fprintf(ard,'r1');
if size(handles.Calibration_Measurements.Data,1)>3
    handles.Fit_Curve.Enable = 'On';
end
import java.awt.event.*;
import java.awt.event.InputEvent
r = java.awt.Robot;
r.keyPress(KeyEvent.VK_ESCAPE);
r.keyRelease(KeyEvent.VK_ESCAPE);

function Fit_Curve_Callback(hObject, eventdata, handles)
global fit saved gaugenum
x = handles.Calibration_Measurements.Data(:,1);
y = handles.Calibration_Measurements.Data(:,1+gaugenum);
if numel(x)<3
    msgbox('Not enough data to fit.');
    return
end
fittype = handles.Fit_Type.Value;
config = cfg();
try
% if numel(x)>1e3 %If there's a large set of data, we only take a sample of 1k points
%     p = randperm(numel(x));
%     p = p(1:1000);
%     x = x(p);
%     y = y(p);
% end
[fi r] = config.fits.fit{fittype}(x,y);
f = config.fits.parameter{fittype}(fi);
% rmse = @(y,yhat)sqrt(sum((y-yhat).^2)/numel(y));
% xhat = config.fits.inverseeq{fittype}(fi,y);
% RMSE = rmse(x,xhat);
catch
    msgbox("Unable to perform fit.");
    return
end
loadfit(gaugenum,f,fittype)
UpdateConfig(hObject,eventdata,handles);
saved(1) = 0;
Convert_Units_Callback(hObject,eventdata,handles);
UpdatePlot(hObject,eventdata,handles);


function Upload_Callback(hObject, eventdata, handles)
global ard wait request
request = 'cal';
wait = 16;
fprintf(ard,'*CAL!');


function Fit_Type_Callback(hObject, eventdata, handles)

function Fit_Type_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function Manual_Input_Callback(hObject, eventdata, handles)
global ard
global log data
key = get(gcf,'CurrentKey');
    if(strcmp (key , 'return'))
        strg = handles.Manual_Input.String;
        fprintf(ard,strg);
        handles.Manual_Input.String='';
    end
   	if(strcmp (key,'escape'))
        handles.edit1.String='';
        uicontrol(handles.edit1); %returns the cursor to the edit box
    end

function Manual_Input_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



%% Pure Functions
function sread(hObject, eventdata, handles)
global request wait ard log time_log
hObject = handles;
handles = guidata(handles);
flag = false;
if ard.BytesAvailable >= wait
    if ~isempty(request)
        j = char(fread(ard,1));
        if j(1)=='*' % Used to detected if it's requested data
            [j flag] = passdata(hObject,eventdata,handles);
        end
    else
        j = fscanf(ard);
    end
try
    if ischar(j)
        log.data=[{j(1:(end-2))};log.data];
        display_log(hObject,eventdata,handles)
        updatelog(eventdata.Data.AbsTime);
    end
    tic
    if iscell(j)
        log.data = [[j{:}].';log.data];
        display_log(hObject,eventdata,handles)
        updatelog(eventdata.Data.AbsTime);
    end
    time_log(end+1) = toc;
catch
end
end
if flag
    UpdatePlot(hObject,eventdata,handles);
end

function display_log(hObject,eventdata,handles)
global log
if numel(log.data)>25
    handles.Serial_Log.String = {log.data{1:25}}.';
else
    handles.Serial_Log.String = log.data;
end
       
function [out flag] = passdata(hObject,eventdata,handles)
global saved request wait ard track
flag = false;
try
switch request
    case 'cfg'
        config = cfg();
        type_ind = cell_find(config.consts.names,'Calibration Type');
        errormsg = 'Failed to get calibration values.';
        j = fread(ard,wait);
        j = j.';
        ind = 1;
        for rep = 1:4
        ind = ind+1;
        for k = 1:numel(config.consts.invtypes)
            val = config.consts.invtypes{k}(j,double(ind));
            handles.Calibration_Values.Data{rep,k} = val(1:(end-1));
            ind = val(end);
        end
        g_params = [handles.Calibration_Values.Data{rep,1:3}];
        g_type = handles.Calibration_Values.Data{rep,type_ind};
        conversions = [handles.Calibration_Values.Data{rep,(end-1):end}];
        if g_type <= numel(config.fits.eq)
            loadfit(rep,g_params,g_type,conversions);
        end
        ind = ind+2; %Skip over terminators
        end
        out = 'Calibration values from DAC have been loaded.';
    case 'raw'
        errormsg = 'Failed to get reading.';
        out = dread(hObject,eventdata,handles);
        flag = true;
        saved(2) = 0;
    case 'con'
        errormsg = 'System error; disabling datalogging.';
        out = dread(hObject,eventdata,handles);
        if ard.BytesAvailable < 3*wait
            flag = true;
            track = 0;
        else
            fprintf(ard,'r0');
            flushinput(ard);
            fprintf(ard,'r0');
        end
        saved(2) = 0;
        return
    case 'cal'
        errormsg = 'Failed to calibrate.';
        out = fscanf(ard);
        out = out(1:(end-2));
        if out == 'Calibrating...'
            uploadvals(hObject,eventdata,handles);
        end
        fprintf(ard,'*CAL!');
end
out = [out '  '];
request = [];
wait = 3;
catch
    out = [errormsg '  '];
    switch request 
        case 'con'
        fprintf(ard,'r0'); %sends a command to stop continuos outputs
        flushinput(ard);
        if track <3
            Time_Log_Callback(hObject,eventdata,handles);
            track = track + 1;
        end
    end
    request = [];
    wait = 3;
    return
end

function out = dread(hObject,eventdata,handles)
global wait ref_g count ard
j = fread(ard,wait);
j = j.';
for i = 1:4
    m(i) = b2i(j(4*i-[3 2]));
    s(i) = b2i(j(4*i-[1 0]));
end
if numel(handles.Ref_Gauge.Enable) == 2
cal = str2num(handles.Ref_Gauge.String);
else
    cal = getcal(ref_g);
end
if isempty(cal)
    cal = 0;
end
time = eventdata.Data.AbsTime;
t = time*[zeros(2,1);86400;3600;60;1];
new_data = [cal double([m s]) t]; %The double in the middle matches the data types
handles.Calibration_Measurements.Data = [new_data;handles.Calibration_Measurements.Data];
for i = 1:4
    out{i} = {['#' num2str(i) ' = ' num2str(new_data(i+1)) char(177) num2str(new_data(i+5))]};
end
count = count + 1;
if count > 15 %only save when more than 15 measurements have been added
data = handles.Calibration_Measurements.Data;
save('tempdata','data');
count = 0;
end

function uploadvals(hObject,eventdata,handles)
global ard
vals = handles.Calibration_Values.Data;
config = cfg();
for i = 1:4
    for j = 1:length(config.consts.types)
        fun = config.consts.types{j};
        fprintf(ard,char([(96+j) num2str(i) fun(vals{i,j})]));
        pause(0.01); %A delay between transmissions appears to reduce the number of errors in transmission
    end
end

function updatelog(a)
global log
log.year = [a(1);log.year];
log.month = [a(2);log.month];
log.day = [a(3);log.day];
clock = a(4:6)*60.^[2;1;0];
log.clock = [clock;log.clock];

function clearlog(hObject,eventdata,handles)
global log
log = structfun(@(x) {}, log, 'UniformOutput', false);
handles.Serial_Log.String = {};
handles.Serial_Log.Value = 1;
 
function Load_Table(hObject,eventdata,handles)
handles.Calibration_Measurements.Data = eventdata;
UpdatePlot(hObject,eventdata,handles);


%% Menu Callbacks
function File_Callback(hObject, eventdata, handles)

function Open_Callback(hObject, eventdata, handles)
global saved
try
    Check_Saved_Data(hObject,eventdata,handles);
catch
    return
end
try 
[a,b] = uigetfile('*.csv'); %open file dialog box for .csv files
f = [b a];
if (a==0)
    return
end
handles.Disp_All.Value = 1;
Load_Table(hObject, csvread(f), handles); %imports data from the csv file
set(handles.Fit_Curve,'Enable','On')
catch
    msgbox("Error loading file. Check selected file's integrity.") %error handling for csv's that produce invalid results
    return;
end
saved(2) = 1;
handles.Data_Name.String = replace(a,'.csv','');
    
function out = Check_Saved_Data(hObject,eventdata,handles)
global saved
if ~saved(2)
    out = questdlg("Would you like to save the current data table first?");;
    switch answer
        case 'Yes'
            SaveD_Callback(hObject, eventdata, handles);
        case 'Cancel'
            error(' ');
            return
    end
    out = answer;
end


function SaveD_Callback(hObject, eventdata, handles)
global saved;
data = handles.Calibration_Measurements.Data;
try
saveCSV(data);
saved(1) = true;
catch
    return
end
handles.Data_Name.String = replace(handles.Data_Name.String,'.csv','');

function Close_Callback(hObject, eventdata, handles)
figure1_CloseRequestFcn(hObject,eventdata,handles);

%% Annoying functions
function figure1_CloseRequestFcn(hObject, eventdata, handles)
global saved
flag = false;
if sum(saved)<numel(saved)
answer = questdlg("There is unsaved data. Would you like to save before closing?");
switch answer
    case 'Cancel'
        return
    case 'Yes'
        config = cfg();
        if saved(1)==0
            try
            SaveG_Callback(hObject,eventdata,handles);
            catch
                flag = true;
            end
        end
        if saved(2)==0
            SaveD_Callback(hObject,eventdata,handles);
        end
end
end
if flag
    return
end
saved = ones(1,numel(saved)); %For some reason this function repeates, so this prevents it from asking to save twice.
closeS(); %Disconnects from Serial Device
delete('fit_temp.mat'); %Deleted temporary file
delete('tempdata.mat');
delete(hObject); %closes GUI
close all; %clears all other figures

function Ref_Gauge_CreateFcn(hObject, eventdata, handles)

function Time_To_Log_CreateFcn(hObject, eventdata, handles)

function Save_Log_Callback(hObject, eventdata, handles)
global log saved
try
[a,b] = uiputfile('*.csv');
f = [b a];
struct2csv(log,f);
try
mean(pwd==b);
catch
delete(a);
struct2csv(log,f);
saved(2) = 1;
end
catch
    return
end

function Ref_Units_Callback(hObject, eventdata, handles)

function Ref_Units_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function changegauge(hObject,eventdata,handles)
global gaugenum
oldG = gaugenum;
gaugenum = eventdata;
if oldG~=gaugenum
    try
    UpdatePlot(hObject,eventdata,handles);
    catch
    end
end


%% Functions that only call updating the plot
function g1_Callback(hObject, eventdata, handles)
changegauge(hObject,1,handles);

function g2_Callback(hObject, eventdata, handles)
changegauge(hObject,2,handles);

function g3_Callback(hObject, eventdata, handles)
changegauge(hObject,3,handles);

function g4_Callback(hObject, eventdata, handles)
changegauge(hObject,4,handles);

function xlin_Callback(hObject, eventdata, handles)
UpdatePlot(hObject,eventdata,handles);

function xlog_Callback(hObject, eventdata, handles)
UpdatePlot(hObject,eventdata,handles);

function ylin_Callback(hObject, eventdata, handles)
UpdatePlot(hObject,eventdata,handles);

function ylog_Callback(hObject, eventdata, handles)
UpdatePlot(hObject,eventdata,handles);

function xsqr_Callback(hObject, eventdata, handles)
UpdatePlot(hObject,eventdata,handles);

function ysqr_Callback(hObject, eventdata, handles)
UpdatePlot(hObject,eventdata,handles);

function Ref_Callback(hObject, eventdata, handles)
UpdatePlot(hObject,eventdata,handles);

function Time_Callback(hObject, eventdata, handles)
UpdatePlot(hObject,eventdata,handles);

function RawY_Callback(hObject, eventdata, handles)
UpdatePlot(hObject,eventdata,handles);

function MeasY_Callback(hObject, eventdata, handles)
UpdatePlot(hObject,eventdata,handles);

function ref_vs_time_Callback(hObject, eventdata, handles)
UpdatePlot(hObject,eventdata,handles);

function Disp_All_Callback(hObject, eventdata, handles)
global request ard
if ~isempty(request)
if request == 'con'
    fprintf(ard,'r0');
    UpdatePlot(hObject,eventdata,handles)
    fprintf(ard,'r0');
end
else
UpdatePlot(hObject,eventdata,handles)
end

function UpdatePlot(hObject,eventdata,handles)
global gaugenum rownum
try
xscale = 'log';
yscale = 'log';
if handles.xlin.Value
   xscale = 'linear';
end
if handles.ylin.Value
    yscale = 'linear';
end
[x y dy] = grabdata(hObject,eventdata,handles);
expx = (2^handles.xsqr.Value);
expy = (2^handles.ysqr.Value);
if isnumeric(x)
    x = x.^expx;
end
y = y.^expy;
handles.axes1.Children(1).XData = x;
handles.axes1.Children(1).YData = y;
handles.axes1.Children(1).YNegativeDelta = dy;
handles.axes1.Children(1).YPositiveDelta = dy;
if isempty(x)
    rangex = [0 1];
    rangey = rangex;
else
rangex = rangefind(x,xscale);
[rangey yn] = rangefind(y,yscale);
end
handles.axes1.XScale = xscale;
handles.axes1.YScale = yscale;
titlestr = [handles.Calibration_Values.RowName{gaugenum} ' Measurement Results'];
if handles.Ref.Value
    x_indx = handles.Ref_Units.Value;
    xstr = ['Reference Gauge (' handles.Ref_Units.String{x_indx} ')'];
else
    xstr = 'Time (s)';
end
if handles.ref_vs_time.Value
    val = handles.Ref_Units.Value;
    unts = handles.Ref_Units.String{val};
    ystr = ['Reference Measurement (' unts ')'];
    titlestr = 'Reference Gauge Datalog';
else
if handles.RawY.Value
    ystr = 'Binary Output';
else
    y_unit = replace(handles.Calibration_Values.Data{gaugenum,6},' ','');
    ystr = ['Gauge Measurement (' y_unit ')'];
end
end
if handles.ysqr.Value
    ystr = [ystr '^2'];
end
if handles.xsqr.Value
    xstr = [xstr '^2'];
end
mat = tmpmat();
try
cv = mat.conversion{gaugenum};
if ~isempty(mat.fit{gaugenum})
    if handles.Ref.Value
        if handles.RawY.Value
            fun = @(y) mat.inv{gaugenum}(mat.fit{gaugenum},y.^(1/expy)).^(expx);
            xn = fun(yn);
        else
            ref_u_v = handles.Ref_Units.Value;
            ref_u = handles.Ref_Units.String{ref_u_v};
            g_u = replace(handles.Calibration_Values.Data{gaugenum,6},' ','');
            conv = uconv(g_u,ref_u);
            xn = (conv(1)*yn+conv(2)).^(expx/expy); %This is to show the correlation between the prediction and measurement
        end
        handles.axes1.Children(2).XData = real(xn);
        handles.axes1.Children(2).YData = yn;
    end
end
catch
end
handles.axes1.XLabel.String = xstr;
handles.axes1.YLabel.String = ystr;
handles.axes1.Title.String = titlestr;
handles.axes1.XLim = rangex;
handles.axes1.YLim = rangey;
if ~isempty(rownum)
    handles.axes1.Children(3).XData = x(rownum);
    handles.axes1.Children(3).YData = y(rownum);
end
catch
    return
end

function [x y dy] = grabdata(hObject,eventdata,handles)
global gaugenum request
if isempty(handles.Calibration_Measurements.Data)
    x = [];
    y = [];
    dy = [];
    return
end
rows = numel(handles.Calibration_Measurements.Data(:,1));
range = 1:rows;
if handles.Disp_All.Value == 0
    steps = floor(rows/10);
if rows > steps   %focuses on only the most recent 250 datapoints
    pos = rows-floor(handles.slider1.Value*(rows-steps));
    zoom = .25*(1-handles.slider2.Value);
    mid = pos-steps/2;
    limits = floor(mid+zoom*[-steps steps]);
    range = limits(1):limits(2);
end
end

if handles.Ref.Value
    x = handles.Calibration_Measurements.Data(range,1);
else
    x = handles.Calibration_Measurements.Data(range,end);
%     if isempty(request) %Prevents this from happening during datalogging
%        t = revert_time(x);
%        x = hours(t(:,4))+minutes(t(:,5))+seconds(t(:,6));
%     end
end
if handles.ref_vs_time.Value
   y = handles.Calibration_Measurements.Data(range,1);
   dy = zeros(numel(y),1);
else
   y = handles.Calibration_Measurements.Data(range,gaugenum+1);
try
dy = handles.Calibration_Measurements.Data(range,gaugenum+5);
catch
    dy = zeros(numel(y),1);
end
end
if ~handles.ref_vs_time.Value
if ~handles.RawY.Value
   mat = tmpmat();
   if isempty(mat.fit{gaugenum})
       Fit_Curve_Callback(hObject, eventdata, handles)
       mat = tmpmat();
   end
   y = mat.inv{gaugenum}(mat.fit{gaugenum},y);
   y = mat.conversion{gaugenum}(1)*y+mat.conversion{gaugenum}(2);
   dy = [mat.inv{gaugenum}(mat.fit{gaugenum},y+dy) mat.inv{gaugenum}(mat.fit{gaugenum},y-dy)]; %using finite difference for error propagation
   dy = mat.conversion{gaugenum}(1)*dy+mat.conversion{gaugenum}(2);
   dy = (dy(:,1)-dy(:,2))/2;
end
end

function [range,fitvar] = rangefind(var,scale)
mini = min(var);
maxi = max(var);
diff = (maxi-mini);
if diff==0
    diff = 1;
end
range = [mini maxi]+[-1 1]*diff/10;
fitvar = linspace(range(1),range(2));
if scale(1:3) == 'log'
    if range(1)<0
        range = [mini/1.5 maxi*1.5];
        fitvar = logspace(floor(log10(mini)),log10(range(2)),100);
    else
        fitvar = logspace(log10(range(1)),log10(range(2)),100);
    end
end

function Reset_Cal_Callback(hObject, eventdata, handles)
config = cfg();
answer = questdlg("Are you sure you want to erase saved calibration values and restore to default? All unsaved work will be erased.");
switch answer
    case 'Cancel'
        return
    case 'No'
        return
    case 'Yes'
        for i = 1:4
            for j = 1:length(config.consts.names)
                handles.Calibration_Values.Data{i,j} = config.consts.vals{i}{j};
            end
        end
    Upload_Callback(hObject, eventdata, handles)
end



function UpdateConfig(hObject,eventdata,handles);
global gaugenum
m = tmpmat();
for i = 1:3
   handles.Calibration_Values.Data{gaugenum,i}= m.fit{gaugenum}(i);
end
handles.Calibration_Values.Data{gaugenum,6} = handles.Ref_Units.String{handles.Desired_Units.Value};
handles.Calibration_Values.Data{gaugenum,7} = m.type{gaugenum};
% handles.Calibration_Values.Data{gaugenum,8} = 4;
handles.Calibration_Values.Data{gaugenum,9} = m.conversion{gaugenum}(1);
handles.Calibration_Values.Data{gaugenum,10} = m.conversion{gaugenum}(2);

function Cal_Tab_Callback(hObject, eventdata, handles)

function LoadG_Callback(hObject, eventdata, handles)
global saved gaugenum %Add a check to make sure gauges are being overwritten first.
gh = ghm();
strng = fieldnames(gh.Gauge);
[indx,tf] = listdlg('ListString',strng,'SelectionMode','single');
if isempty(indx)
    return
else
   vals = gh.Gauge.(strng{indx});
   handles.Calibration_Values.RowName{gaugenum} = strng{indx};
   for i = 1:numel(vals)
   handles.Calibration_Values.Data{gaugenum,i} = vals{i};
   end 
   loadfit(gaugenum,[vals{1} vals{2} vals{3}],vals{7});
end
saved(1) = 1;
UpdatePlot(hObject,eventdata,handles)
    
function LoadC_Callback(hObject, eventdata, handles)

function GetC_Callback(hObject, eventdata, handles)
global ard request wait
if isempty(ard)
    msgbox("Not attached to an arduino.")
    return
end
config = cfg();
request = 'cfg';
wait = 4*(config.consts.total+3);
fprintf(ard,'*CAL?');

function SaveL_Callback(hObject, eventdata, handles)
Save_Log_Callback(hObject,eventdata,handles);

function SaveG_Callback(hObject, eventdata, handles)
global saved gaugenum
        reps = gaugenum;
switch eventdata.EventName
    case 'Close'
        reps = 1:4;
end
Gauge_History = ghm();
config = cfg();
for i = reps
data = {handles.Calibration_Values.Data{i,:}};
name = handles.Calibration_Values.RowName{i};
try %Checks to make sure the gauge was named
    if name == config.consts.gauges{i}
        uicontrol(handles.Code);
        msgbox('Give this gauge a unique name before saving.');
        error(' ');
        return
    end
catch
end
name = replace(name,' ','_');
name = replace(name,'-','');
name = replace(name,'__','_');
if isfield(Gauge_History.Gauge,name)
    check = questdlg('Would you like to overwrite the previously saved gauge calibration?');
    switch check
        case 'No'
	        return
        case 'Cancel'
            return
    end
end
Gauge_History.Gauge.(name) = data;
end
save('Gauge_History.mat','Gauge_History');
saved(1) = 1;

function Sort_Table_Callback(hObject, eventdata, handles)
global gaugenum
data = handles.Calibration_Measurements.Data;
[b i] = sort(data(:,gaugenum+1));
out = data(i(:,1),:);
handles.Calibration_Measurements.Data = out;

function Sort_Table_DeleteFcn(hObject, eventdata, handles)

function Time_Log_Callback(hObject, eventdata, handles)
global ard request wait ref_g
flushinput(ard);
if isempty(ard)
    msgbox("Not attached to an arduino.")
    return
end
if isempty(request)
    request = 'con';
    wait = 18;
    handles.Serial_Log.String = [{'Beginning datalogging...'};handles.Serial_Log.String];
    updatelog(clock);
    try
        ref_g.BytesAvailable
    catch
        Terranova_908_Callback(hObject,eventdata,handles); 
    end
else
    wait = 3;
    request = [];
    handles.Serial_Log.String=[{'Terminating datalogging.'};handles.Serial_Log.String];
    updatelog(clock);
end
handles.Fit_Curve.Enable = 'on';
fprintf(ard,'r0');

function Code_Callback(hObject, eventdata, handles)
global gaugenum saved
key = get(gcf,'CurrentKey');
    if(strcmp(key , 'return'))
        strng = handles.Code.String;
        handles.Calibration_Values.RowName{gaugenum} = strng;
        handles.Code.String='';
        saved(1) = 0;
        UpdatePlot(hObject,eventdata,handles);
    end
   	if(strcmp (key,'escape'))
        handles.edit1.String='';
        uicontrol(handles.Code); %returns the cursor to the edit box
    end
    
function Code_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function Parameter_Select_Callback(hObject, eventdata, handles)

function Parameter_Select_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function Manual_Parameter_Callback(hObject, eventdata, handles)
global gaugenum 
key = get(gcf,'CurrentKey');
    if(strcmp(key , 'return'))
        manual_cal(hObject,gaugenum,handles);
    end
   	if(strcmp (key,'escape'))
        handles.edit1.String='';
        uicontrol(handles.Manual_Parameter); %returns the cursor to the edit box
    end
    
function Manual_Parameter_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function Calibration_Measurements_CellSelectionCallback(hObject, eventdata, handles)
global rownum 
if ~isempty(eventdata.Indices)
    rownum = eventdata.Indices(:,1);
    UpdatePlot(hObject,eventdata,handles);
else
    rownum = [];
end

function Desired_Units_Callback(hObject, eventdata, handles)

function Desired_Units_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function Convert_Units_Callback(hObject, eventdata, handles)
global gaugenum
config = cfg();
vd = handles.Desired_Units.Value;
r = handles.Ref_Units.Value;
desire = handles.Desired_Units.String{vd};
ref = handles.Ref_Units.String{r};
p = round(uconv(ref,desire),4); %Weird behavior where the results from ºC to ºF conversion fixed by rounding
m = tmpmat();
loadfit(gaugenum,m.fit{gaugenum},m.type{gaugenum},p);
handles.Calibration_Values.Data{gaugenum,9} = p(1);
handles.Calibration_Values.Data{gaugenum,10} = p(2);
param = cell_find(config.consts.names,'Unit');
entry = config.consts.interp{param}(desire);
if ~config.consts.valid{param}(entry)
    msgbox('Invalid gauge parameter.');
    return
end
handles.Calibration_Values.Data{gaugenum,param} = entry;
UpdatePlot(hObject,eventdata,handles);


function Delete_Line_Callback(hObject, eventdata, handles)
global rownum
data = handles.Calibration_Measurements.Data;
try
if ~isempty(rownum)
    if rownum ==1
        handles.Calibration_Measurements.Data = data(2:end,:);
    else
        handles.Calibration_Measurements.Data = [data(1:(rownum(1)-1),:);data((rownum(end)+1):end,:)];
    end
end
rownum = [];
handles.axes1.Children(3).XData = [];
handles.axes1.Children(3).YData = [];
catch
end

function Calibration_Measurements_CellEditCallback(hObject, eventdata, handles)

function figure1_KeyPressFcn(hObject, eventdata, handles)
key = get(gcf,'CurrentKey');
    if(strcmp (key , 'alt'))
        UpdatePlot(hObject,eventdata,handles);
    end
    
function Ref_Gauge_Callback(hObject,eventdata,handles)


function Untitled_1_Callback(hObject, eventdata, handles)

function Terranova_908_Callback(hObject, eventdata, handles)
global ard ref_g
S = seriallist;    
try
    checks = find(~(S==ard.Port));
catch
    checks = 1:numel(S);
end
for i = checks(2:end)
    ref_g = serial(S(i));
    ref_g.BaudRate = 9600;
    ref_g.Timeout = 0.01;  %The gauge responds almost instantly
    try
        fopen(ref_g);
        fprintf(ref_g,'v')
        textcheck=fgetl(ref_g);
    if numel(textcheck)>4
    if(textcheck(1:4)=="908A")
        handles.Ref_Gauge.String = S(i);
        handles.Ref_Gauge.Enable = 'off';
        break
    end
    end
        fclose(ref_g);
    catch
        msgbox('Unable to connect to Terranova 908');
        return
    end
end
fprintf(ref_g,'u');
unit = fgetl(ref_g);
unit = unit(1:end-1); %Terranova has a single terminator byte, this trims it off
if numel(unit)==6
    unit = 'Pa'; %Special case where unit = Pascal (this gauge only supports 5 chars)
end
c = cfg();
names = fields(c.meas);
pres_val = cell_find(names,'Pressure'); %This ensures it always grabs the correct position for pressure.
select = cell_find(c.meas.Pressure,unit);
handles.Measurement_Type.Value = pres_val;
Measurement_Type_Callback(hObject,eventdata,handles);
handles.Ref_Units.Value = select;
handles.Measurement_Type.Enable = 'off';
handles.Ref_Units.Enable = 'off';

function out = getcal(obj)
try
    fprintf(obj,'p');
    read = fscanf(obj);
    valid = find(read=='e'); %Valid measurements have exponents
    for i = 1:numel(valid)
        range = (valid(i)-5):(valid(i)+2);
        g{i} = read(range);
    end
    g = replace(g,' ','');
    if numel(g)==1;
       out = str2double(g{1});
       return;
    end
    if uint8(read(1))==32||45 %checks for if the first gauge has a significant reading
        out = str2double(g{2});
    else
        out = str2double(g{1});
    end
catch
    msgbox(read)
end

function Menu_UPlot_Callback(hObject, eventdata, handles)
    UpdatePlot(hObject,eventdata,handles);

function man_up_plot()
import java.awt.event.KeyEvent
import java.awt.event.*;
import java.awt.event.InputEvent
r = java.awt.Robot;
r.keyPress(KeyEvent.VK_CONTROL);
r.keyPress(KeyEvent.VK_9);
r.keyRelease(KeyEvent.VK_9);
r.keyRelease(KeyEvent.VK_CONTROL);

function Up_All_Cal_Callback(hObject, eventdata, handles)
manual_cal(hObject,1:4,handles); 
    
function manual_cal(hObject,gauge,handles)
global saved
config = cfg();
in = handles.Manual_Parameter.String;
param = handles.Parameter_Select.Value;
entry = config.consts.interp{param}(in);
if ~config.consts.valid{param}(entry)
    msgbox('Invalid gauge parameter.');
    return
end
for i = gauge
handles.Calibration_Values.Data{i,param} = entry;
end
handles.Manual_Parameter.String='';
saved(1) = 0;


function init_plot(hObject,eventdata,handles)
hold on
plot(0,0,'g*');
plot(0,0,'r-');
errorbar(0,0,0,'b.');
% plot(0,0,'b.')
handles.axes1.Children(1).XData = [];
handles.axes1.Children(1).YData = [];
handles.axes1.Children(1).YNegativeDelta = [];
handles.axes1.Children(1).YPositiveDelta = [];
handles.axes1.Children(2).XData = [];
handles.axes1.Children(2).YData = [];
handles.axes1.Children(3).XData = [];
handles.axes1.Children(3).YData = [];

function New_Session_Callback(hObject, eventdata, handles)
global saved
try
    Check_Saved_Data(hObject,eventdata,handles);
catch
    return
end
data = [];
handles.Calibration_Measurements.Data = data;
save('tempdata.mat','data');
cla reset
init_plot(hObject,eventdata,handles)
UpdatePlot(hObject,eventdata,handles);
saved(2) = 1;


function Save_Fig_Callback(hObject, eventdata, handles)
[a b] = uiputfile('*.bmp');
filename = [b a];
f = figure('visible','off');
graph = copyobj(handles.axes1,f);
f.OuterPosition = [0 0 1000 1000];
set(gca,'OuterPosition',[-0.15 -0.05 1.325 1.1],'FontSize',24,'FontName','Calibri');
graph.Children(1).MarkerSize=20;
graph.Children(2).LineWidth=2;
try
    saveas(graph,filename);
    close;
catch
    close;
    return
end

function Delete_Edges_Callback(hObject, eventdata, handles)
global saved request
if isempty(request)
data = handles.Calibration_Measurements.Data;
if isempty(data)
    return
end
handles.Calibration_Measurements.Data = rmoutliers(data,'movmean',20);
UpdatePlot(hObject,eventdata,handles);
saved(2) = 0;
end

function Smooth_Data_Callback(hObject, eventdata, handles)
global saved request
if isempty(request)
full = handles.Calibration_Measurements.Data;
if isempty(full)
    return
end
static = full(:,6:end);
data = full(:,1:5);
data = smoothdata(data);
handles.Calibration_Measurements.Data = [data,static];
UpdatePlot(hObject,eventdata,handles)
saved(2) = 0;
end

function Eval_R_Callback(hObject, eventdata, handles)
global gaugenum
data = handles.Calibration_Measurements.Data;
unit = handles.Calibration_Values.Data{gaugenum,6};
unit = replace(unit,' ','');
conv(1) = handles.Calibration_Values.Data{gaugenum,9};
conv(2) = handles.Calibration_Values.Data{gaugenum,10};
scl = handles.axes1.XScale;
gname = handles.Calibration_Values.RowName{gaugenum};
eval_residuals(gaugenum,data,unit,conv,scl,gname)



function slider1_Callback(hObject, eventdata, handles)
if ~handles.Disp_All.Value
UpdatePlot(hObject,eventdata,handles)
end

function slider1_CreateFcn(hObject, eventdata, handles)
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end

function ContSliderDragCB(hObject, eventdata)
handles = guidata(eventdata.AffectedObject);
slider1_Callback(hObject, eventdata, handles)

function ContSliderDragCB2(hObject, eventdata)
handles = guidata(eventdata.AffectedObject);
slider1_Callback(hObject, eventdata, handles)


function slider2_Callback(hObject, eventdata, handles)

function slider2_CreateFcn(hObject, eventdata, handles)
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end
