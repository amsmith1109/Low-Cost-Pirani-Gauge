%% Deming regression (Assumes identical variance in x & y)
function out = DLS(x,y);
xn = mean(x);
yn = mean(y);
z = x+i*y;
Z = sqrt(sum((z-(xn+i*yn)).^2));
out = imag(Z)/real(Z);
out(2) = yn-out(1)*xn;
end