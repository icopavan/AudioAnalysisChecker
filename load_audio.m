function [waveforms,Fs,length_t,waveform_y_range]=load_audio(pathname,filename)

%determine which file it is from the filename
if strcmp(filename(end-2:end),'mat') %loading from nidaq_matlab_tools
  warning('off','MATLAB:loadobj');
  audio=open([pathname '\' filename]);
  warning('on','MATLAB:loadobj');
  waveforms = audio.data;
  Fs = audio.SR;
  length_t = audio.pretrigger;
  waveform_y_range = [-10 10];
elseif strcmp(filename(end-2:end),'bin') %loading from wavebook
  [fd,h,c] = OpenIoTechBinFile([pathname '\' filename]);
  Fs = h.preFreq;
  length_t=h.PreCount/Fs;
  waveforms = ReadChnlsFromFile(fd,h,c,length_t*Fs,1);
  waveforms=cell2mat(waveforms);
  waveform_y_range = [-5 5];
end