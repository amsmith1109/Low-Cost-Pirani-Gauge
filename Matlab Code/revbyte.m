function out = revbyte(in)
for i = 1:numel(in)
out(i) = byte2dec(~fliplr(dec2bit(in(i))));
end
end