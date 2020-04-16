% Made to convert the byte structure output from an arduino
% Serial COM to the float value from the 4 bytes
% Note: Arduino stores 32bit floats backwards, that's why there are so many
% fliprl operations.
function out = b2f(in)
if sum(in>255)
    error('Each input must be a byte.')
    return
end
if numel(in)~=4
   error('Incorrect number of input bytes.')
   return
end
if size(in,1) == 1
    in = fliplr(in);
else
in = fliplr(in.');
end
in = uint8(in);
if sum(in==zeros(1,4))==4;
    out = 0;
    return
end
bits = [];
for i = 1:numel(in)
bits = [bits fliplr(bitget(in(i),1:8))];
end
s = double(bits(1));
exp = bits(2:9);
exp = double(sum(bits(2:9).*uint8(2.^fliplr((0:7)))))-127;
frac = bits(10:end);
mask = 2.^(-1*(1:23));
val = sum(double(frac).*mask);
out = (-1)^s*(2^exp)*(1+val);
end