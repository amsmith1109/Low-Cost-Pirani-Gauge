% Made to get the individual bytes of an unsigned 16-bit int
function out = i2b(in)
if in>(2e15-1)
    error('Input too large. Must be < 32768.') 
    return
end
in = double(in);
out(1) = uint8(floor(in/256));
out(2) = uint8(mod(in,256));
end