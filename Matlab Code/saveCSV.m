function saveCSV(data)
try
[a,b] = uiputfile('*.csv');
f = [b a];
dlmwrite(f,data,'precision',10);
try
mean(pwd==b);
catch
delete(a);
dlmwrite(f,data,'precision',10);
end
catch
    return
end
end