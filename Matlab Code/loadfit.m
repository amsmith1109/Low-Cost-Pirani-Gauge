function loadfit(gauge,parameters,type,conversion)
config = cfg();    
fit_temp = tmpmat();
fit_temp.fit{gauge} = parameters;
fit_temp.type{gauge} = type;
if type == 0
    type = 1;
end
fit_temp.eq{gauge} = config.fits.eq{type};
fit_temp.inv{gauge} = config.fits.inverseeq{type};
if nargin==4
    fit_temp.conversion{gauge} = conversion;
else
    fit_temp.conversion{gauge} = [1 0];
end
save('fit_temp.mat','fit_temp');
end