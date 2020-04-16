function out = dec2bit(in)
if in >255
    error('Too large of an input.');
    return
end
vec = 0:7;
vec = fliplr(vec);
for q = 1:numel(in)
    v = in(q)+1;
for i = 1:8
    f = 2^vec(i);
    if v>f
        a(i) = logical(1);
        v = v-f;
    else
        a(i) = logical(0);
    end
end
    out(q,:) = a;
end
end