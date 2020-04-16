function closeS()
if ~isempty(instrfind)
fclose(instrfind);
delete(instrfind);
end
end