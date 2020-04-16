% generates the 4 bytes of a floating point number to upload to an arduino
% for direct storage as a float value.
% When recieving on the arduino use the following:
% for (i = 0;i<=3;i++){
% EEPROM.put(addr+i,byte[i]);
% }
function out = f2b(in)
if ~isfloat(in)
    error('Must be a float input');
    return
end
if abs(in)>6.8056469e38
   error('Input outside of range for 32-bit precision');
   return
end
if in==0
   out = [0 0 0 0];
   return
end
    s = sign(in)<0;
    exp = floor(log2(abs(in)))+127;
    frac_val = round((abs(in)/(2^(exp-127))-1)*2^23);
    frac = fliplr(bitget(frac_val,1:23));
    exp = fliplr(bitget(floor(log2(abs(in)))+127,1:8));
    full = ([s exp frac]);
    for i = 1:4
    out(i) = sum(full((8*i-7):(8*i)).*2.^fliplr(0:7));
    end
    out = fliplr(out);
end