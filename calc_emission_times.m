function emission_t = calc_emission_times(D,t,voc_t)
%D: distance between bat and microphone
%t: frame times for bat location
%voc_t: voc time on microphone

delays_at_bat = D/340;
t_at_mike = t' + D/340;

delay=nan(length(voc_t),1);
for v=1:length(voc_t)
  voc=voc_t(v);

  d_indx = find( (t_at_mike - voc) < 0 , 1 , 'last');
  delay(v) = delays_at_bat(d_indx);
end

emission_t = voc_t - delay;