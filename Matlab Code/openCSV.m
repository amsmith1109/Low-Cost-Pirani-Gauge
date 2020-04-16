function out = openCSV()
try 
[a,b] = uigetfile('*.csv'); %open file dialog box for .csv files
f = [b a];
if (a==0)
    return
end
out = csvread(f);
end
end