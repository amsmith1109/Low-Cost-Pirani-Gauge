function out = findcell(cel,val)
if (isstring(val))||(ischar(val))
    matches = cellfun(@(x)~isempty(strfind(x,val)),cel);
    indx = cellfun(@(x)numel(x)==numel(val),cel);
    out = find(bitand(matches,indx));
end
if isnumeric(val)
    out = find(cellfun(@(x)x==val,cel));
end
end