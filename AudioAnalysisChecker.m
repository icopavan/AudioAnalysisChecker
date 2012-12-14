function varargout = AudioAnalysisChecker(varargin)
% AUDIOANALYSISCHECKER M-file for AudioAnalysisChecker.fig
%      AUDIOANALYSISCHECKER, by itself, creates a new AUDIOANALYSISCHECKER or raises the existing
%      singleton*.
%
%      H = AUDIOANALYSISCHECKER returns the handle to a new AUDIOANALYSISCHECKER or the handle to
%      the existing singleton*.
%
%      AUDIOANALYSISCHECKER('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in AUDIOANALYSISCHECKER.M with the given input arguments.
%
%      AUDIOANALYSISCHECKER('Property','Value',...) creates a new AUDIOANALYSISCHECKER or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before AudioAnalysisChecker_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to AudioAnalysisChecker_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help AudioAnalysisChecker

% Last Modified by GUIDE v2.5 14-Dec-2012 12:48:27

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @AudioAnalysisChecker_OpeningFcn, ...
                   'gui_OutputFcn',  @AudioAnalysisChecker_OutputFcn, ...
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


function AudioAnalysisChecker_OpeningFcn(hObject, eventdata, handles, varargin)
handles.output = hObject;

handles = initialize(handles);

% Update handles structure
guidata(hObject, handles);


function varargout = AudioAnalysisChecker_OutputFcn(hObject, eventdata, handles) 
varargout{1} = handles.output;


function handles = initialize(handles)
handles.samples=round(str2double(get(handles.sample_edit,'string')));
axes(handles.wave_axes);cla;
axes(handles.spect_axes);cla;
axes(handles.PI_axes);cla;
handles.internal = [];
set(handles.processed_checkbox,'value',0);


function handles=load_audio(handles)
if isfield(handles.internal,'audio_pname') && ...
    exist(handles.internal.audio_pname,'dir')
  pathname=handles.internal.audio_pname;
elseif ispref('audioanalysischecker','audio_pname')
  pathname=getpref('audioanalysischecker','audio_pname');
else
  STARTDIR='';
  pathname = uigetdir(STARTDIR,...
    'Select folder where raw audio files are located');
  if isequal(pathname,0)
    return
  end
  setpref('audioanalysischecker','audio_pname',pathname);
end

[filename pathname]=uigetfile({'*.mat;*.bin'},...
  'Load audio file',[pathname '\']);
if isequal(filename,0)
  return
end
setpref('audioanalysischecker','audio_pname',pathname);

handles.internal.audio_pname=pathname;
handles.internal.audio_fname=filename;

handles = load_marked_vocs(handles);

if isempty(handles.internal.DataArray)
  return;
end

%determine which file it is from the marked filename
if strcmp(filename(end-2:end),'mat') %loading from nidaq_matlab_tools
  warning('off','MATLAB:loadobj');
  audio=open([pathname '\' filename]);
  warning('on','MATLAB:loadobj');
  waveforms = audio.data;
  Fs = audio.SR;
elseif strcmp(filename(end-2:end),'bin') %loading from wavebook
  [fd,h,c] = OpenIoTechBinFile([pathname '\' filename]);
  [waveforms] = ReadChnlsFromFile(fd,h,c,10*250000,1);
  Fs = h.preFreq;
end

% figure(1); clf;
% for k=1:size(waveforms,2)
%   subplot(size(waveforms,2),1,k)
%   plot(waveforms(1:10:end,k));
%   title(['Channel: ' num2str(k)]);
% end
% options.WindowStyle='normal';
% channel = inputdlg('Which channel?','',1,{''},options);
% close(1);
% 
% if isempty(channel)
%   return;
% end
channel='1'; %speed up loading audio for 2012 data

handles.internal.waveform=waveforms(:,str2double(channel));
handles.internal.Fs=Fs;

handles.internal.current_voc=1;

set(gcf,'Name',['AudioAnalysisChecker: ' handles.internal.audio_fname]);

update(handles);


function handles = load_marked_vocs(handles)
fn = gen_processed_fname(handles);
if exist(fn,'file')
  load(fn);
  handles.internal.net_crossings = (trial_data.net_crossings-length(trial_data.centroid))/300;
  handles.internal.DataArray = trial_data.voc_t;
  handles.internal.extracted_sound_data = trial_data;
  set(handles.processed_checkbox,'value',1);
else
  if ispref('audioanalysischecker','marked_voc_pname')
    DEFAULTNAME=getpref('audioanalysischecker','marked_voc_pname');
  else
    DEFAULTNAME='';
  end

  if ~exist([DEFAULTNAME 'sound_data.mat'],'file')
    [~, DEFAULTNAME] = uigetfile('sound_data.mat',...
      'Select processed sound data (sound_data.mat)',DEFAULTNAME);
    if isequal(DEFAULTNAME,0)
      return
    end
  end

  handles.sound_data_file = [DEFAULTNAME 'sound_data.mat'];
  %compare checksum to checksum in handles if it exists
  %saves time loading sound_data.mat every time
  [status result] = system(['md5\md5.exe ' handles.sound_data_file]);
  if status == 0
    space_indx=strfind(result,' ');
    checksum = result(1:space_indx(1));
  end
  if isfield(handles,'sound_data') && strcmp(checksum,handles.sound_data_checksum)
    extracted_sound_data = handles.sound_data;
  else
    load(handles.sound_data_file);
    handles.sound_data = extracted_sound_data;
    handles.sound_data_checksum = checksum;
  end
  
  setpref('audioanalysischecker','marked_voc_pname',DEFAULTNAME);

  all_trialcodes={extracted_sound_data.trialcode};
  trialcode = determine_vicon_trialcode([handles.internal.audio_pname handles.internal.audio_fname]);
  indx=find(strcmp(all_trialcodes,trialcode));

  if isempty(indx)
    handles.internal.DataArray=[];
    display_text = ['Vicon trial: ' trialcode ' absent.'];
    disp(display_text)
    add_text(handles,display_text);
    return;
  end

  handles.internal.net_crossings = (extracted_sound_data(indx).net_crossings-length(extracted_sound_data(indx).centroid))/300;
  handles.internal.DataArray = extracted_sound_data(indx).voc_t;
  handles.internal.extracted_sound_data = extracted_sound_data(indx);
  handles.internal.changed=0;
end


function add_text(handles,text)
current_text = get(handles.text_output_listbox,'String');
new_text = [current_text; {text}];
set(handles.text_output_listbox,'String',new_text);
addpath('findjobj');
jhEdit = findjobj(handles.text_output_listbox);
jEdit = jhEdit.getComponent(0).getComponent(0);
jEdit.setCaretPosition(jEdit.getDocument.getLength);


function update(handles)
set(handles.voc_edit,'string',num2str(handles.internal.current_voc));

axes(handles.wave_axes);cla;

Fs = handles.internal.Fs;

voc_time = handles.internal.DataArray(handles.internal.current_voc);

voc_sample = round((voc_time + 8)*Fs);

buffer=round(handles.samples/2);
sample_range=max(1,voc_sample-buffer):min(voc_sample+buffer,length(handles.internal.waveform));
X=handles.internal.waveform(sample_range);

t=(sample_range)./Fs-8;
plot(t(1:3:end),X(1:3:end),'k');
axis tight;
a=axis;
axis([a(1:2) -10 10]);

%displaying markings:
all_voc_times=handles.internal.DataArray;
time_range=t([1 end]);

voc_t_indx=all_voc_times>=time_range(1)...
  & all_voc_times<=time_range(2);

disp_voc_times=all_voc_times(voc_t_indx);
voc_nums=find(voc_t_indx);
hold on;
for k=1:length(disp_voc_times)
  plot([disp_voc_times(k) disp_voc_times(k)],[-10 10],'color','r');
end
text(disp_voc_times,-8*ones(length(voc_nums),1),num2str(voc_nums),...
  'horizontalalignment','center');
plot([voc_time voc_time],[-10 10],'color',[.6 .6 1]);
hold off;
text(disp_voc_times,zeros(length(disp_voc_times),1),...
  'X','HorizontalAlignment','center','color','c','fontsize',14,'fontweight','bold');

%displaying net crossings if visible
hold on;
net_crossings = handles.internal.net_crossings;

if a(1)<net_crossings(1)
  plot([net_crossings(1) net_crossings(1)],[-5 5],'b','linewidth',2);
end
if a(2)>net_crossings(2)
  plot([net_crossings(2) net_crossings(2)],[-5 5],'b','linewidth',2);
end

%plotting start and stop of the processed file if visible
if a(1)<net_crossings(1)-.5
  plot((net_crossings(1)-.5)*ones(2,1),[-5 5],'m','linewidth',2);
end
if a(2)>net_crossings(2)+1
  plot((net_crossings(2)+1)*ones(2,1),[-5 5],'g','linewidth',2);
end
hold off;

%plotting spectrogram:
axes(handles.spect_axes);cla;
if get(handles.plot_spectrogram_checkbox,'value')
  [S,F,T,P] = spectrogram(X,256,230,[],Fs,'yaxis');
  imagesc(T,F,10*log10(abs(P))); axis tight;
  set(gca,'YDir','normal','ytick',(0:25:125).*1e3,'yticklabel',...
    num2str((0:25:125)'),'xticklabel','');

  %worrying about the clim for the spectrogram:
  max_db_str=num2str(round(max(max(10*log10(P)))));
  min_db_str=num2str(round(min(min(10*log10(P)))));
  set(handles.max_dB_text,'string',max_db_str);
  set(handles.min_dB_text,'string',min_db_str);
  if get(handles.lock_range_checkbox,'value') == 1
    low_clim=str2double(get(handles.low_dB_edit,'string'));
    top_clim=str2double(get(handles.top_dB_edit,'string'));
    set(gca,'clim',[low_clim top_clim]);
  else
    set(handles.top_dB_edit,'string',max_db_str);
    set(handles.low_dB_edit,'string',min_db_str);
  end
  colormap('hot')
end

%plotting PI:
axes(handles.PI_axes);cla;
if get(handles.plot_PI_checkbox,'value')
  plot_PI(handles);
end


function plot_PI(handles)
PI=diff(handles.internal.DataArray)*1e3;
t=handles.internal.DataArray(2:end);

plot(t,PI,'.-k');
axis tight;
a=axis;
axis([a(1:2) 0 a(4)]);
hold on;
if handles.internal.current_voc > 1
  plot(t(handles.internal.current_voc-1),PI(handles.internal.current_voc-1),...
    'o','linewidth',2,'color',[.6 .6 1]);
end
for k=1:length(handles.internal.net_crossings)
  plot(handles.internal.net_crossings(k)*ones(2,1),[0 a(4)],...
    'b','linewidth',2);
end
plot((handles.internal.net_crossings(1)-.5)*ones(2,1),[0 a(4)],'m','linewidth',2);
plot((handles.internal.net_crossings(2)+1)*ones(2,1),[0 a(4)],'g','linewidth',2);
hold off; axis tight;
title('Pulse Interval (ms)','fontsize',8)


function fn = gen_processed_fname(handles)
sound_file=[handles.internal.audio_pname handles.internal.audio_fname];
fn=[sound_file(1:end-4) '_processed.mat'];

function save_trial(handles)
trial_data=handles.internal.extracted_sound_data;
trial_data.voc_t=handles.internal.DataArray;
trial_data.voc_checked=1;
trial_data.voc_checked_time=datevec(now);

fn=gen_processed_fname(handles);
save(fn,'trial_data');
handles.internal.changed = 0;
display_text = ['Saved ' handles.internal.audio_fname ' at ' datestr(now,'HH:MM PM')];
disp(display_text);
add_text(handles,display_text);
guidata(handles.save_menu,handles);


function canceled = save_before_discard(handles)
canceled = 0;
if isfield(handles.internal,'changed') && handles.internal.changed
  choice = questdlg('Edits detected, save first?', ...
    'Save?', ...
    'Yes','No','Cancel','Yes');
  % Handle response
  switch choice
    case 'Yes'
      save_trial(handles);
    case 'Cancel'
      canceled = 1;
  end
end

function close_GUI(handles)
if save_before_discard(handles)
  return
end
delete(handles.figure1);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


% --- Executes on button press in zoomin_button.
function zoomin_button_Callback(hObject, eventdata, handles)
handles.samples=round(handles.samples/2);
set(handles.sample_edit,'string',num2str(handles.samples));
update(handles);
guidata(hObject, handles);

% --- Executes on button press in zoomout_button.
function zoomout_button_Callback(hObject, eventdata, handles)
handles.samples=round(handles.samples*2);
set(handles.sample_edit,'string',num2str(handles.samples));
update(handles);
guidata(hObject, handles);


function sample_edit_Callback(hObject, eventdata, handles)
% Hints: get(hObject,'String') returns contents of sample_edit as text
%        str2double(get(hObject,'String')) returns contents of sample_edit as a double
handles.samples=round(str2double(get(hObject,'String')));
update(handles);
guidata(hObject, handles);


% --- Executes during object creation, after setting all properties.
function sample_edit_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in prev_button.
function prev_button_Callback(hObject, eventdata, handles)
handles.internal.current_voc = handles.internal.current_voc - 1;
if handles.internal.current_voc < 1
  handles.internal.current_voc = 1;
end
update(handles);
guidata(hObject, handles);

% --- Executes on button press in next_button.
function next_button_Callback(hObject, eventdata, handles)
handles.internal.current_voc = handles.internal.current_voc + 1;
if handles.internal.current_voc > length(handles.internal.DataArray)
  handles.internal.current_voc = length(handles.internal.DataArray);
end
update(handles);
guidata(hObject, handles);

% --- Executes on button press in first_call_button.
function first_call_button_Callback(hObject, eventdata, handles)
handles.internal.current_voc = 1;
update(handles);
guidata(hObject, handles);

% --- Executes on button press in final_call_button.
function final_call_button_Callback(hObject, eventdata, handles)
handles.internal.current_voc = length(handles.internal.DataArray);
update(handles);
guidata(hObject, handles);

function voc_edit_Callback(hObject, eventdata, handles)
% Hints: get(hObject,'String') returns contents of voc_edit as text
%        str2double(get(hObject,'String')) returns contents of voc_edit as a double
handles.internal.current_voc = str2double(get(hObject,'string'));
if handles.internal.current_voc > length(handles.internal.DataArray)
  handles.internal.current_voc = length(handles.internal.DataArray);
elseif handles.internal.current_voc < 1
  handles.internal.current_voc = 1;
end
update(handles);
guidata(hObject, handles);

% --- Executes on button press in delete_button.
function delete_button_Callback(hObject, eventdata, handles)
handles.internal.DataArray(handles.internal.current_voc)=[];
handles.internal.changed=1;
if handles.internal.current_voc > length(handles.internal.DataArray)
  handles.internal.current_voc=length(handles.internal.DataArray);
end
guidata(hObject, handles);
update(handles);


% --- Executes on button press in new_button.
function new_button_Callback(hObject, eventdata, handles)
axes(handles.wave_axes);
[x,y] = ginput(1);
voc_time = handles.internal.DataArray(handles.internal.current_voc);
buffer=handles.samples/2/handles.internal.Fs;
if x > voc_time - buffer && x < voc_time + buffer
  handles.internal.DataArray(end+1)=x;
  handles.internal.DataArray = sort(handles.internal.DataArray);
  handles.internal.changed=1;
  guidata(hObject, handles);
  update(handles);
else
  disp('Outside displayed range');
  add_text(handles,'Outside displayed range');
end


function voc_edit_CreateFcn(hObject, eventdata, handles)
% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function low_dB_edit_Callback(hObject, eventdata, handles)
% Hints: get(hObject,'String') returns contents of low_dB_edit as text
%        str2double(get(hObject,'String')) returns contents of low_dB_edit as a double
set(handles.lock_range_checkbox,'value',1);
update(handles);
guidata(hObject, handles);

% --- Executes during object creation, after setting all properties.
function low_dB_edit_CreateFcn(hObject, eventdata, handles)
% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --- Executes on button press in lock_range_checkbox.
function lock_range_checkbox_Callback(hObject, eventdata, handles)
% Hint: get(hObject,'Value') returns toggle state of lock_range_checkbox
update(handles);
guidata(hObject,handles);



function top_dB_edit_Callback(hObject, eventdata, handles)
% Hints: get(hObject,'String') returns contents of top_dB_edit as text
%        str2double(get(hObject,'String')) returns contents of top_dB_edit as a double
set(handles.lock_range_checkbox,'value',1);
update(handles);
guidata(hObject, handles);


% --- Executes during object creation, after setting all properties.
function top_dB_edit_CreateFcn(hObject, eventdata, handles)
% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


function key_press_handler(hObject, eventdata, handles)
key=get(handles.figure1,'CurrentKey');

switch key
  case {'numpad6','rightarrow'}
    next_button_Callback(handles.next_button, eventdata, handles);
  case {'numpad4','leftarrow'}
    prev_button_Callback(handles.prev_button, eventdata, handles);
  case {'period','decimal'}
    new_button_Callback(handles.new_button, eventdata, handles);
  case {'subtract','hyphen'}
    delete_button_Callback(handles.delete_button, eventdata, handles);
end



% --------------------------------------------------------------------
function file_menu_Callback(hObject, eventdata, handles)


% --------------------------------------------------------------------
function open_menu_Callback(hObject, eventdata, handles)
if save_before_discard(handles)
  return
end
handles=initialize(handles);
handles=load_audio(handles);
guidata(hObject, handles);

% --------------------------------------------------------------------
function save_menu_Callback(hObject, eventdata, handles)
save_trial(handles);

% --------------------------------------------------------------------
function close_menu_Callback(hObject, eventdata, handles)
close_GUI(handles)

function plot_spectrogram_checkbox_Callback(hObject, eventdata, handles)
update(handles);


function plot_PI_checkbox_Callback(hObject, eventdata, handles)
update(handles);

function previous_10_button_Callback(hObject, eventdata, handles)
handles.internal.current_voc = handles.internal.current_voc - 10;
if handles.internal.current_voc < 1
  handles.internal.current_voc = 1;
end
update(handles);
guidata(hObject, handles);

function next_10_button_Callback(hObject, eventdata, handles)
handles.internal.current_voc = handles.internal.current_voc + 10;
if handles.internal.current_voc > length(handles.internal.DataArray)
  handles.internal.current_voc = length(handles.internal.DataArray);
end
update(handles);
guidata(hObject, handles);


function playbutton_Callback(hObject, eventdata, handles)

voc_time = handles.internal.DataArray(handles.internal.current_voc);

voc_sample = round((voc_time + 8)*handles.internal.Fs);

buffer=handles.samples/2;
sample_range=max(1,voc_sample-buffer):min(voc_sample+buffer,length(handles.internal.waveform));
X=handles.internal.waveform(sample_range);

slowdown_factor = str2double(get(handles.playback_slowdown_factor,'string'));

soundsc(X,handles.internal.Fs/slowdown_factor);


function processed_checkbox_Callback(hObject, eventdata, handles)

function new_window_PI_button_Callback(hObject, eventdata, handles)
figure(1); clf;
plot_PI(handles)

function text_output_listbox_CreateFcn(hObject, eventdata, handles)


% --- Executes when user attempts to close figure1.
function figure1_CloseRequestFcn(hObject, eventdata, handles)
close_GUI(handles);



function text_output_listbox_Callback(hObject, eventdata, handles)

  


function playback_slowdown_factor_Callback(hObject, eventdata, handles)
set_value = str2double(get(hObject,'String'));
if ~audiodevinfo(0, 2, handles.internal.Fs/set_value, 16, 1)
  set(hObject,'String','20');
  disp_text='Sample rate not supported';
  add_text(handles,disp_text);
  disp(disp_text);
end

% --- Executes during object creation, after setting all properties.
function playback_slowdown_factor_CreateFcn(hObject, eventdata, handles)
% hObject    handle to playback_slowdown_factor (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
