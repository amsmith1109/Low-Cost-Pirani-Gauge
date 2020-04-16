function out = char5(in)
if numel(in)>5
    out = in(1:5);
else
    out = in;
end