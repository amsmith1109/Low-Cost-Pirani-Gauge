function out = byte2dec(in)
if size(in,2)~=8
    error('Wrong size input.')
    return
end
for q = 1:size(in,1)
a = 0;
b = in(q,:);
for i = 1:8
    a = a+b(i)*2^(8-i);
end
out(q) = a;
end
end