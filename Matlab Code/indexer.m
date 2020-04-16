function out = indexer(lookup,sample,type)
if ~exist('lookup')
    error('No lookup table given.');
    return
end
if ~exist('sample')
    error('No Sample input');
    return
end

if ~exist('type')
    type = 'all';
elseif numel(type) == 3
    if type=='all'
    elseif type == 'N2O'
        type = 0;
    end
elseif numel(type) ==2
    if == 'NO'
    type = 1;
    end
end

if sample ~= 'all'
index1 = find(lookup(:,3)==sample);
else
    index1 = lookup(:,1);
end

if type ~= 'all'
out = find(lookup(index1,5)==type);
else
    out = index1;
end
end