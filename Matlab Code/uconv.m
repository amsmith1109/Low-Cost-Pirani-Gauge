function out = uconv(start,desired,value)
config = cfg();
config.meas = rmfield(config.meas,'type');
names = fieldnames(config.meas);
for i = 1:length(names)
    a = findcell(config.meas.(names{i}),start);
    b = findcell(config.meas.(names{i}),desired);
    if ~isempty(a)
        if isempty(b)
            error('Units must be of the same type');
            return
        end
        indx = i;
        break
    end
end
if isempty(a)||isempty(b)
    error('Did not find units.');
    return
end
p = config.conversion.(names{indx}){a};
q = config.conversion.(names{indx}){b};
q = [1/q(1) -q(2)/q(1)];
out = [p(1)*q(1) (p(2)*q(1)+q(2))];
if nargin==3
    out = out(1)*value+out(2);
end