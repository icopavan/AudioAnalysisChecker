function audit_multp_ch(trial_data,processed_audio_dir,processed_audio_fnames,proc_fname_indx)


if isfield(trial_data,'duration_data_audit')
    
for kk = 1:length(trial_data.voc_t)
  
  voc_ts = trial_data.duration_data{kk}(:,1);
  audit_vocs = ~isnan(trial_data.duration_data_audit{kk}(:,2));
  remaining_vocs_indx = find(~audit_vocs);
  
  disp(['On file ' trial_data.trialcode ' on channel #' num2str(trial_data.ch(kk))]);
  
  new_duration_data = nan(length(remaining_vocs_indx),3);
  for vv=1:length(remaining_vocs_indx)
      disp(['On voc #' num2str(vv) ' on ' num2str(length(remaining_vocs_indx)) ' vocs.']);
    buffer_s = round((10e-3).*Fs);
    buffer_e = round((14e-3).*Fs);
    voc_time = voc_ts(remaining_vocs_indx(vv));
    voc_samp = round((voc_time + pretrig_t)*Fs);
    voc=waveform(max(1,voc_samp-buffer_s):min(voc_samp+buffer_e,length(waveform)));
    
    clf;
    
    hh(1)=subplot(2,1,1); cla;
    plot((1:length(voc))./Fs,voc);
    hold on;
    plot(buffer_s/Fs,0,'*g');
    axis tight;
    aa=axis;
    hold off;
    
    hh(2)=subplot(2,1,2); cla;
    [~,F,T,P] = spectrogram(voc,128,120,512,Fs);
    imagesc(T,F,10*log10(P)); set(gca,'YDir','normal');
    set(gca,'clim',[-95 -30]);
    hold on;
    axis tight;
    aaa=axis;
    
    axis([aa(1:2) aaa(3:4)]);
    hold off;
    
    linkaxes(hh,'x');
    
    disp('press Return to ignore voc');
    [x,~]=ginput(2);
    if ~isempty(x) && diff(x)>0
      voc_s = voc_time - buffer_s/Fs + x(1);
      voc_e = voc_time - buffer_s/Fs + x(2);
      new_duration_data(vv,:) = [voc_time voc_s voc_e];
    end
  end
  trial_data.duration_data_audit{kk}(~audit_vocs,:) = new_duration_data;
  trial_data.manual_additions = 1;
  save([processed_audio_dir processed_audio_fnames{proc_fname_indx}],'trial_data');
end
end
end