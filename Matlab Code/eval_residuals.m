function eval_residuals(gauge,data,unit,conv,scale,gname)
%Specify file name here
mat = tmpmat();
meas = data(:,1);
fit = mat.fit{gauge};
x = data(:,(gauge+1));
y = mat.inv{gauge}(fit,x);
r = (meas-y);
f = figure;
resids = r./y*100;
% yyaxis left
xax = conv(1)*y+conv(2);
% uconv('mtorr','mBar');
% meas = meas*ans(1);
if numel(xax)>1e3
    plot(meas,(resids),'b.','MarkerSize',4)
else
    plot(meas,(resids),'b*','MarkerSize',20)
end
f.Children.XScale = scale;
% f.Children.YScale = scale;
hold on
ax = gca;
ax.XLim = [min(meas) max(meas)];
plot(ax.XLim,[0 0],'k-','LineWidth',2)
xlabel(['Pressure (' unit ')'])
ylabel('Absolute Error (%)')
if size(data,2)>4
yyaxis right
t = data(:,5);
temp = (t-2.6667e3)/53.333;
plot(meas,temp,'r.');
ylabel('Temperature (°C)')
f.Children.YAxis(1).Color = [0 0 1];
f.Children.YAxis(2).Color = [1 0 0];
f.Children.YScale = scale;
end
title(['Residuals of ' gname])
f.Units = 'Normalized';
f.OuterPosition = [.05 .1 .5 .5];
set(gca,'OuterPosition',[0 0 1 1],'FontSize',24,'FontName','Calibri');
r_std = sqrt(sum(r.^2)/(numel(r)-2));
1;
end