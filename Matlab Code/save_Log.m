function save_Log()
global log data
log = log;
log.data = data;
try
[a,b] = uiputfile('*.csv');
f = [b a];
struct2csv(log,f);
try
mean(pwd==b);
catch
delete(a);
struct2csv(log,f);
end
catch
    return
end
end