function out = b2i(in)
out = [];
if numel(in)==2
out = uint16(uint16(in(1)))*2^8+uint16(in(2));
end
end