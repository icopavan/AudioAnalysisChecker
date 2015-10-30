function varargout = duration_mark(varargin)
% DURATION_MARK MATLAB code for duration_mark.fig
%      DURATION_MARK, by itself, creates a new DURATION_MARK or raises the existing
%      singleton*.
%
%      H = DURATION_MARK returns the handle to a new DURATION_MARK or the handle to
%      the existing singleton*.
%
%      DURATION_MARK('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in DURATION_MARK.M with the given input arguments.
%
%      DURATION_MARK('Property','Value',...) creates a new DURATION_MARK or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before duration_mark_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to duration_mark_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help duration_mark

% Last Modified by GUIDE v2.5 30-Oct-2015 13:36:32

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @duration_mark_OpeningFcn, ...
                   'gui_OutputFcn',  @duration_mark_OutputFcn, ...
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






function update(handles)
%updates the 3 axes

call_num=handles.callnum;

set(handles.call_num_edit,'string',num2str(call_num));
set(handles.max_call,'string',num2str(handles.calltot));

cur_ch=handles.data.proc.call(call_num).channel_marked;
waveform=handles.data.filt_wav_noise{cur_ch};
Fs=handles.data.Fs;
buffer=str2double(get(handles.buffer_edit,'string'));
buffer_s = round((buffer * 1e-3).*Fs);
onset=handles.data.proc.call(call_num).onset;
offset=handles.data.proc.call(call_num).offset;
if isnan(onset)
  samp_s=handles.data.proc.call(call_num).locs-buffer_s*2;
else
  samp_s=max(1,onset-buffer_s);
end
if isnan(offset)
  samp_e=handles.data.proc.call(call_num).locs+buffer_s*2;
else
  samp_e=min(offset+buffer_s,size(waveform,1));  
end

voc_p=waveform(samp_s:samp_e);



axes(handles.context_axes);
if ~isfield(handles.data,'plot_cur_wav') && ~isfield(handles.data,'prev_chan')...
    || handles.data.prev_chan ~= cur_ch
  cla;
  t=(0:size(waveform,1)-1)/Fs;
  plot(t,waveform);
  axis tight;
  hold on;
elseif isfield(handles.data,'plot_cur_wav')
  delete(handles.data.plot_cur_wav);
end
if isfinite(onset) && isfinite(offset)
  handles.data.plot_cur_wav=plot((onset:offset)'/Fs,...
    waveform(onset:offset),'r');
else
  handles.data.plot_cur_wav=plot((samp_s:samp_e)'/Fs,...
    waveform(samp_s:samp_e),'r');
end


axes(handles.wav_axes);
plot((1:length(voc_p))./Fs,voc_p);
hold on;
if isfinite(onset)
  plot([buffer_s buffer_s]./Fs,[min(voc_p) max(voc_p)],'r')
end
plot([buffer_s+offset-onset buffer_s+offset-onset]./Fs,...
  [min(voc_p) max(voc_p)],'r')
axis tight; hold off;

axes(handles.spec_axes);
[~,F,T,P] = spectrogram(voc_p,128,120,512,Fs);
imagesc(T,F,10*log10(P)); set(gca,'YDir','normal');
clim_upper=str2double(get(handles.clim_upper_edit,'String'));
clim_lower=str2double(get(handles.clim_lower_edit,'String'));
set(gca,'clim',[clim_lower clim_upper]);
%         colormap jet
%         colorbar
hold on;
axis tight;
aaa=axis;
if isfinite(onset)
  plot([buffer_s buffer_s]./Fs,[0 Fs/2],'r')
end
plot([buffer_s+offset-onset buffer_s+offset-onset]./Fs,...
  [0 Fs/2],'r')
hold off;

handles.data.prev_chan=cur_ch;

linkaxes([handles.wav_axes handles.spec_axes],'x');
guidata(handles.figure1, handles)



function key_press_handler(hObject, eventdata, handles)
key=get(handles.figure1,'CurrentKey');

switch key
  case {'numpad6','rightarrow'}
    nav_next_button_Callback(handles.nav_next_button, eventdata, handles);
  case {'numpad4','leftarrow'}
    nav_prev_button_Callback(handles.nav_prev_button, eventdata, handles);
  case {'home'}
    nav_start_button_Callback(handles.nav_start_button, eventdata, handles);
  case {'end'}
    nav_last_button_Callback(handles.nav_last_button, eventdata, handles);
  case {'subtract','hyphen','delete'}
    del_button_Callback(handles.del_button, eventdata, handles);
  case {'period','decimal','add'}
    mark_button_Callback(handles.mark_button, eventdata, handles);
end

function canceled = save_before_discard(handles)
canceled = 0;
if isfield(handles,'data') && isfield(handles.data,'edited') && handles.data.edited
  f=gcf;
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
  figure(f);
end

function saved=save_trial(handles)
saved=0;
if ~isfield(handles,'data') 
  disp('Nothing to save')
  return;
end

calldata = handles.data.proc.call;
B=num2cell([calldata.onset]);
[calldata.call_start_idx]=B{:};
B=num2cell([calldata.offset]);
[calldata.call_end_idx]=B{:};
calldata=rmfield(calldata,'onset');
calldata=rmfield(calldata,'offset');

% fn=handles.data.fn;
% m=matfile(fn,'Writable',true);
% m.call = calldata;
% m.dur_marked=1;
% m.dur_marks_timestamp=now;





function close_GUI(handles)
%retuns true if save needed and user cancels
if save_before_discard(handles)
  return;
end
if isfield(handles,'figure1');
  delete(handles.figure1);
else
  delete(gcf);
end

% --- Executes when user attempts to close figure1.
function figure1_CloseRequestFcn(hObject, eventdata, handles)
close_GUI(handles);

% --- Executes just before duration_mark is made visible.
function duration_mark_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to duration_mark (see VARARGIN)

% Choose default command line output for duration_mark
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes duration_mark wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = duration_mark_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;



function noise_freq_edit_Callback(hObject, eventdata, handles)
% hObject    handle to noise_freq_edit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of noise_freq_edit as text
%        str2double(get(hObject,'String')) returns contents of noise_freq_edit as a double


% --- Executes during object creation, after setting all properties.
function noise_freq_edit_CreateFcn(hObject, eventdata, handles)
% hObject    handle to noise_freq_edit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function start_freq_edit_Callback(hObject, eventdata, handles)
% hObject    handle to start_freq_edit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of start_freq_edit as text
%        str2double(get(hObject,'String')) returns contents of start_freq_edit as a double


% --- Executes during object creation, after setting all properties.
function start_freq_edit_CreateFcn(hObject, eventdata, handles)
% hObject    handle to start_freq_edit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function end_freq_edit_Callback(hObject, eventdata, handles)
% hObject    handle to end_freq_edit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of end_freq_edit as text
%        str2double(get(hObject,'String')) returns contents of end_freq_edit as a double


% --- Executes during object creation, after setting all properties.
function end_freq_edit_CreateFcn(hObject, eventdata, handles)
% hObject    handle to end_freq_edit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in nav_next_button.
function nav_next_button_Callback(hObject, eventdata, handles)
% hObject    handle to nav_next_button (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.callnum=min(handles.callnum+1,handles.calltot);
guidata(hObject, handles);
update(handles);


% --- Executes on button press in nav_prev_button.
function nav_prev_button_Callback(hObject, eventdata, handles)
% hObject    handle to nav_prev_button (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.callnum=max(handles.callnum-1,1);
guidata(hObject, handles);
update(handles);

% --- Executes on button press in nav_start_button.
function nav_start_button_Callback(hObject, eventdata, handles)
% hObject    handle to nav_start_button (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.callnum=1;
guidata(hObject, handles);
update(handles);

% --- Executes on button press in nav_last_button.
function nav_last_button_Callback(hObject, eventdata, handles)
% hObject    handle to nav_last_button (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.callnum=handles.calltot;
guidata(hObject, handles);
update(handles);

% --- Executes on button press in del_button.
function del_button_Callback(hObject, eventdata, handles)
% hObject    handle to del_button (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.data.proc.call(handles.callnum).onset=NaN;
handles.data.proc.call(handles.callnum).offset=NaN;
handles.data.edited=1;
guidata(hObject,handles);
update(handles)

% --- Executes on button press in mark_button.
function mark_button_Callback(hObject, eventdata, handles)
% hObject    handle to mark_button (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
axes(handles.wav_axes);

Fs=handles.data.wav.fs;
buffer_s = round((2e-3)*Fs);

[x,~,button]=ginput(2);
if isempty(x) || ismember(13,button) || length(x) < 2 %ignoring
  disp('Ignoring voc');
  return
%   voc_status(hh,buffer_s/Fs,'X','r',.1)
elseif diff(x)<0
  disp('Error clicks not in order, ignoring voc')
  return
%   voc_status(hh,buffer_s/Fs,'X','r',.1)
elseif ismember(27,button) %ESC
  return;
else
  if isnan(handles.data.proc.call(handles.callnum).onset)
    loc=handles.data.proc.call(handles.callnum).locs;
    buffer_mult=2;
  else
    loc=handles.data.proc.call(handles.callnum).onset;
    buffer_mult=1;
  end
  handles.data.proc.call(handles.callnum).onset = round(loc - buffer_s*buffer_mult + x(1)*Fs);
  handles.data.proc.call(handles.callnum).offset = round(loc - buffer_s*buffer_mult + x(2)*Fs);
  handles.data.edited=1;
  guidata(hObject,handles);
  
%   new_duration_data(vv,:) = [voc_time voc_s voc_e];
%   voc_status(hh,buffer_s/Fs,'OK','g',0)
end
update(handles);

% --------------------------------------------------------------------
function filemenu_Callback(hObject, eventdata, handles)
% hObject    handle to filemenu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --------------------------------------------------------------------
function loadfile_Callback(hObject, eventdata, handles)
% hObject    handle to loadfile (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

%determine if they want to save current file first


%determine the type of file (wu-jung's mic_data_detect or my _processed file)
if ispref('duration_mark_gui') && ispref('duration_mark_gui','micrecpath')
  pname=getpref('duration_mark_gui','micrecpath');
else
  pname='';
end
[fname,pname]=uigetfile({'*mic_data_detect.mat','Wu-Jung''s format';...
  '*_processed.mat','Ben''s format';...
  '*.mat','Mat files'},[],pname);
if isequal(fname,0)
  return;
end
fn=[pname,fname];
setpref('duration_mark_gui','micrecpath',pname)

handles.data=[];
handles.data.proc=load(fn);
handles.data.edited=0;

noise_freq=str2double(get(handles.noise_freq_edit,'String'))*1e3;
end_freq=str2double(get(handles.end_freq_edit,'String'))*1e3;
start_freq=str2double(get(handles.start_freq_edit,'String'))*1e3;

%wu_jung format
if strfind(fn,'mic_data_detect')
  A=strsplit(fn,'_detect');
  data_fname=A{1};
  handles.data.wav=load([data_fname '.mat']);
  
  Fs=handles.data.wav.fs;
  handles.data.Fs=Fs;
  %if durations haven't been marked already, run the automated duration
  %marking code
  if ~isfield(handles.data.proc,'dur_marked') || ~handles.data.proc.dur_marked
    %doing filtering once on each channel, as opposed to repeatedly doing it
    %for each call
    handles.data.edited=1;
    ch_marked=unique([handles.data.proc.call(:).channel_marked]);
    [handles.data.filt_wav_noise,handles.data.filt_wav_start,...
      handles.data.filt_wav_start,handles.data.noise_high,...
      handles.data.noise_low,handles.data.data_square,...
      handles.data.data_square_high,handles.data.data_square_diff_high,...
      handles.data.data_square_low,handles.data.data_square_diff_low]=...
      deal(cell(handles.data.proc.num_ch_in_file,1));
    %remove extraneous sounds below noise_freq
    [b,a] = butter(6,noise_freq/(Fs/2),'high');
    %we assume it's below 30k, removes some energy from echoes
    [low_b, low_a]=butter(6,end_freq/(Fs/2),'low'); 
    %we assume it's above 30k, removes some energy from previous vocs
    [high_b, high_a]=butter(6,start_freq/(Fs/2),'high'); 
    for cc=ch_marked
      waveform=handles.data.wav.sig(:,cc);

      ddf=filtfilt(b,a,waveform); %freqz(b,a,SR/2,SR);
      data_square = smooth((ddf.^2),100);

      %for marking the end time 
      waveform_low=filtfilt(low_b,low_a,ddf); %using the previously high passed data
      data_square_low=smooth((waveform_low.^2),100);

      %for marking the start time
      waveform_high=filtfilt(high_b,high_a,waveform); %just high pass it once time
      data_square_high=smooth((waveform_high.^2),100);

      noise_length = .001*Fs; %length of data for estimating noise (1ms)

      data_square_diff_high = abs(smooth(diff(data_square_high),50));
      noise_diff_high=...
        median(max(reshape(data_square_diff_high(1:floor(length(data_square_diff_high)...
        /noise_length)*noise_length),noise_length,[])));
      data_square_diff_low = abs(smooth(diff(data_square_low),50));
      noise_diff_low=...
        median(max(reshape(data_square_diff_low(1:floor(length(data_square_diff_low)...
        /noise_length)*noise_length),noise_length,[])));

      handles.data.filt_wav_noise{cc}=ddf;
      handles.data.data_square{cc}=data_square;

      handles.data.filt_wav_start{cc}=waveform_high;
      handles.data.data_square_high{cc}=data_square_high;
      handles.data.data_square_diff_high{cc}=data_square_diff_high;

      handles.data.filt_wav_end{cc}=waveform_low;
      handles.data.data_square_low{cc}=data_square_low;
      handles.data.data_square_diff_low{cc}=data_square_diff_low;

      handles.data.noise_high{cc}=noise_diff_high;
      handles.data.noise_low{cc}=noise_diff_low;
    end
    
    [handles.data.proc.call(:).onset]=deal(nan);
    [handles.data.proc.call(:).offset]=deal(nan);    
    used_vocs = find([1, diff([handles.data.proc.call(:).locs]./Fs)>10e-3]);
    
    warning('off','signal:findpeaks:largeMinPeakHeight')
    for vv=used_vocs
      loc=handles.data.proc.call(vv).locs;
      cc=handles.data.proc.call(vv).channel_marked;
      
      [handles.data.proc.call(vv).onset,handles.data.proc.call(vv).offset]=...
        extract_dur_on_call(loc,Fs,...
        handles.data.filt_wav_noise{cc},handles.data.filt_wav_start{cc},...
        handles.data.filt_wav_end{cc},handles.data.noise_high{cc},...
        handles.data.noise_low{cc},handles.data.data_square{cc},...
        handles.data.data_square_high{cc},handles.data.data_square_diff_high{cc},...
        handles.data.data_square_low{cc},handles.data.data_square_diff_low{cc},0,0);
    end
    warning('on','signal:findpeaks:largeMinPeakHeight')
  else
    B=num2cell([handles.data.proc.call.call_start_idx]);
    [handles.data.proc.call.onset]=B{:};
    B=num2cell([handles.data.proc.call.call_end_idx]);
    [handles.data.proc.call.offset]=B{:};
  end
  
elseif strfind(fn,'mic_data_detect') %ben's format
  %load in different types of the raw audio files
end

%initialize
handles.callnum=1;
handles.calltot=length(handles.data.proc.call);
handles.data.fn=fn;

guidata(hObject, handles);
update(handles);



% --------------------------------------------------------------------
function savefile_Callback(hObject, eventdata, handles)
% hObject    handle to savefile (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

%save in the correct format
if save_trial(handles)
  handles.data.edited=0;
  guidata(hObject,handles);
end

% --------------------------------------------------------------------
function exit_Callback(hObject, eventdata, handles)
% hObject    handle to exit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

closeGUI(handles);



function clim_upper_edit_Callback(hObject, eventdata, handles)
% hObject    handle to clim_upper_edit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of clim_upper_edit as text
%        str2double(get(hObject,'String')) returns contents of clim_upper_edit as a double
update(handles)


% --- Executes during object creation, after setting all properties.
function clim_upper_edit_CreateFcn(hObject, eventdata, handles)
% hObject    handle to clim_upper_edit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


function clim_lower_edit_Callback(hObject, eventdata, handles)
% hObject    handle to clim_lower_edit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of clim_lower_edit as text
%        str2double(get(hObject,'String')) returns contents of clim_lower_edit as a double
update(handles)


% --- Executes during object creation, after setting all properties.
function clim_lower_edit_CreateFcn(hObject, eventdata, handles)
% hObject    handle to clim_lower_edit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function call_num_edit_Callback(hObject, eventdata, handles)
% hObject    handle to call_num_edit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of call_num_edit as text
%        str2double(get(hObject,'String')) returns contents of call_num_edit as a double
handles.callnum=str2double(get(hObject,'String'));
guidata(hObject,handles);
update(handles);

% --- Executes during object creation, after setting all properties.
function call_num_edit_CreateFcn(hObject, eventdata, handles)
% hObject    handle to call_num_edit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function max_call_Callback(hObject, eventdata, handles)
% hObject    handle to max_call (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of max_call as text
%        str2double(get(hObject,'String')) returns contents of max_call as a double


% --- Executes during object creation, after setting all properties.
function max_call_CreateFcn(hObject, eventdata, handles)
% hObject    handle to max_call (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in delete_call_button.
function delete_call_button_Callback(hObject, eventdata, handles)
% hObject    handle to delete_call_button (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.data.edited=1;
callnum=handles.callnum;
handles.data.proc.call(callnum)=[];
handles.callnum=max(1,handles.callnum-1);
handles.calltot=handles.calltot-1;
guidata(hObject,handles);
update(handles);



function buffer_edit_Callback(hObject, eventdata, handles)
% hObject    handle to buffer_edit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of buffer_edit as text
%        str2double(get(hObject,'String')) returns contents of buffer_edit as a double
update(handles)

% --- Executes during object creation, after setting all properties.
function buffer_edit_CreateFcn(hObject, eventdata, handles)
% hObject    handle to buffer_edit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
