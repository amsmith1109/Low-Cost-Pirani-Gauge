function out = cell_find(cell_array,string,exact)
    sz = find(cellfun(@(x) numel(x),cell_array)==numel(string));
    locations = find(cellfun(@(x)~isempty(strfind(x,string)),cell_array));
    if isempty(sz)&&isempty(locations)
        error('No match found.');
        return
    end
    if nargin==3
        if exact == 0
            out = locations;
            return
        end
    end
    match = find(ismember(sz,locations));
    if isempty(match)
       error('No exact matches found.'); 
    end
    if numel(sz)>numel(locations)
        out = sz(match);
    else
        out = locations(match);
    end
end