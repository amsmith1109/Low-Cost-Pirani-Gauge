function out = revert_time(in,month,year)
if size(in,1)==1
    in = in.';
end
if size(in,2)>1
    error('Input must be a vector.');
    return
end
fail_save = datevec(now);
onz = ones(numel(in),1);
if nargin < 2
    month = fail_save(2);
end
if nargin < 3
    year = fail_save(1);
end
month = month*onz;
year = year*onz;
conv = [86400 3600 60 1];
raw = in;
for i = 1:4
    date_number(:,i) = floor(raw/conv(i));
    raw = raw-date_number(:,i)*conv(i);
end
    out =[year,month,date_number];
end