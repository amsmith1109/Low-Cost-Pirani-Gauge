function [fit r2 SSE RMSE] = sigfit(x,y,guess,w)
%% Least-squares method to guess at start values
%This linearizes the equation and guesses at the non-linear parameter to
%find a best fit. Though this section converges on a very solid
%approximation, testing showed it was still inadequate (potentially because
%of how r^2 is computed.)
if ~exist('w')
    w = 1;
end
c = logspace(guess(1),guess(2));
for i = 1:numel(c)
    b = 1./(y-c(i));
    [v{i} r(i)] = MLS(1./x,b,[1 0]);
end
j = find(r==max(r)); %The best fit is chosen as the highest r^2 value from the scan
%% non-linear regression
%This utilizes the guess from the previous section to act as starting
%points for the non-linear regression
p = @(x,b) b(1)*x./(1+b(2)*x)+b(3);
a{1} = [v{j}(1)^-1, v{j}(2)*v{j}(1)^-1,c(j)]; %The first approximation is the output from the previous section
fun = @(b) sum((w.*(y-p(x,b))).^(2)); %Equation for computing the residual
a{end+1} = fminsearch(fun,a{end});
yhat = p(x,a{end});
for i = 1:2 %Each iterations improved the results. Most runs I tested converged after ~3 runs
a{end+1} = fminsearch(fun,a{end});
end
yhat = p(x,a{end});
residuals = y-yhat;
%% Statistics calculations
SSTO = sum((y-mean(y)).^2);
SSE = sum((residuals).^2);
SSR = sum((yhat-mean(y)).^2);
rmse = @(y,yhat)sqrt(sum((y-yhat).^2)/numel(y));
%% output values
fit = a{end}(1:3);
r2 = 1-SSE/SSTO;
end