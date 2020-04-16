% Matrix Least Squares
% x = x data,  y = y data, p = polynomial
% Inputting a vector into p will define which orders you want
% Ex: p = [5 2 0] returns least squares for a*x^5 + b*x^2 + c;
function [v r o] = MLS(x,y,p,w)
if ~exist('w')
   w = 1;
end
W = diag(w);
xcheck = size(x);
warning('off')
if xcheck(1) == 1
    x = x.';
end
ycheck = size(y);
if ycheck(1) == 1
    y = y.';
end
if p(1)<p(end)
    p = fliplr(p);
end
if numel(p)==1
    if p ==0
        f = @(x) x;
        return
    end
    p = fliplr(0:p);
end
if numel(p)>1
f = @(x) x.^p(1);
for i = 2:numel(p)
    f = @(x) [f(x) x.^p(i)];
end
end
X = f(x);
v(1,:) = ((X.'*W.^2*X)^-1)*X.'*W.^2*y;
fr = @(x) sum(v.*x.^p,2);
SSE = sum((y-fr(x)).^2);
SSR = sum((fr(x)-mean(y)).^2);
SSTO = sum((y-mean(y)).^2);
r = 1-SSE/SSTO;
end