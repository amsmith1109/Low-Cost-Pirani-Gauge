function out = unit_interp(in)
sz = numel(in);
if sz<5
    in = [in '     '];
end
out = char(in(1:5));
end