% F0AM_benchmark.m
% Setup used to evaluate F0AM execution time and coarse debugging.
% Script will output a "benchmark ratio," which is the ratio of model run time to 
% the runtime for MATLAB's bench function.
%
% 20180110 GMW

clear

tstep = 1; %hours

%% SOLAR PARAMETERS

SolarParam.lat          = 0; %degrees, range -90:90
SolarParam.lon          = 0; %degrees, range -180:180
SolarParam.alt          = 1000; %meters
SolarParam.startTime    = [2014 05 18 12 00 00]; %year month day hour min sec
SolarParam.nDays        = 1;

%% METEOROLOGY

%calculate solar zenith angles
time.year           = 2014;
time.month          = 5;
time.day            = 18;
time.hour           = [12:tstep:(23+1-tstep) 0:tstep:(11+1-tstep)]';  
time.min            = 0;
time.sec            = 0;
time.UTC            = 0;
location.latitude   = 0;
location.longitude  = 0;
location.altitude   = 1000;
sun = sun_position(time,location); %fields zenith and azimuth

Met = {...
%   names       %values
    'P'          1000;              %Pressure, mbar
    'T'          298;               %Temperature, K
    'RH'         50;                %Relative Humidity, %
    
    % DILUTION
    'kdil'          1/86400;        %dilution constant, /s
%     'tgauss'        -1;...        % initial timescale for Gaussian dilution, s
    
    % PHOTOLYSIS
    'SZA'           sun.zenith;...  % solar zenith angle, degrees
    'jcorr'         1;...           % j-value correction factor
    'LFlux'         [];...          % actinic flux spectrum
    'ALT'           1000;...        % altitude, m asl
    'O3col'         300;...         % overhead ozone column, DU
    'albedo'        0.1;...         % surface albedo
    
    % EMISSIONS/DEPOSITION
    'BLH'           1000;...        % boundary layer depth, m
    'PPFD'          0;...           % umol/m^2/s
    'LAI'           1;...           % m^2/m^2
    
    % AEROSOL (ORGANIC)
    'rpaerosol'     0;...           % mean aerosol particle radius, cm
    'Naerosol'      0;...           % aerosol number density, #/cm^3
    'Saerosol'      1e-6;...           % mean aerosol particle surface area concentration cm^2/cm^3
    'Vaerosol'      0;...           % mean aerosol particle volume concentration cm^3/cm^3
    
    % AEROSOL (AQUEOUS)
    'pH'            7;...           % liquid drop pH
    'rpaqueous'     0;...           % mean liquid drop radius, cm
    'Naqueous'      0;...           % liquid drop number density, #/cm^3
    'Saqueous'      0;...           % mean aqueous particle surface area concentration cm^2/cm^3
    'Vaqueous'      0;...           % mean aqueous particle volume concentration cm^3/cm^3
    
    % AEROSOL (ICE)
    'rpice'         0;...           % mean ice radius, cm
    'Nice'          0;...           % ice number density, #/cm^3
    'Sice'          0;...           % mean ice particle surface area concentration cm^2/cm^3
    'Vice'          0;...           % mean ice particle volume concentration cm^3/cm^3

    };

%% CHEMICAL CONCENTRATIONS

InitConc = {...
    % names             conc(ppb)           HoldMe
    'H2'                550                  1;
    'O3'                50                   0;
    'OH'                1e6/2.5e10           0;
    'HO2'               0.02                 0;
    'H2O2'              0.1                  0;
    'CO'                100                  1;
    'NO'                0.0                  0;
    'NO2'               0.5                  0;
    'CH4'               1900                 1;
    'HCHO'              0.5                  0;
    
     %Halogens
    'HOBr'              7/1000               0;
    'HOI'               3/1000               0;
    'HCl'               14/1000              0;
    
    % families
    'NOx'               {'NO2','NO'}        [];
    'Bry'               {'HOBr','HBr','BrO','Br','BrNO2','BrNO3','2*Br2'}  [];
%     'Iy'                {'HOI','I','IO','HI','OIO','CH3I','INO','INO2','INO3','2*I2','2*I2O4','2*I2O3'}  [];
%     'Cly'               {'HCl','ClO','OClO','Cl','ClNO3','ClOO','HOCl','ClNO2','2*Cl2','2*Cl2O2'} [];
    };
    
% missing BrCl, IBr, ICl

%% CHEMISTRY
ChemFiles = {...
   'MCMv331_K(Met)';
   'MCMv331_J(Met,2)';
   'MCMv331_Methane';
   'Halogens_Sherwen2016';
%    'HalogenAerosol_Sherwen2016';
   };

%% DILUTION CONCENTRATIONS

BkgdConc = {'DEFAULT'       0};

%% OPTIONS

ModelOptions.Verbose        = 1;
ModelOptions.EndPointsOnly  = 1;
ModelOptions.LinkSteps      = 1;
ModelOptions.Repeat         = 3;
ModelOptions.IntTime        = 3600*tstep; %3600 seconds/hour
% ModelOptions.TimeStamp      = time.hour;
ModelOptions.SavePath       = 'DoNotSave';
% ModelOptions.FixNOx         = 0;

%% MODEL RUN

for i = 1:1 %need a few burns for stable answer (memory allocation/caching?)
    start = now;
    S = F0AM_ModelCore(Met,InitConc,ChemFiles,BkgdConc,ModelOptions);
    stop = now;
end
dt_f0am = (stop - start)*86400;

if 0
    %use MATLAB's benchmark for normalization
    t_bench = bench;
    dt_bench = sum(t_bench(1:4)); %ignore graphics tests
    % close all %close benchmark figure
    %
    fprintf('Benchmark ratio = %2.1f\n',dt_f0am./dt_bench)
end

%% family plot

x = breakin(S.Conc);

fy = 'NOx';
NOx = sum(x(:,S.Chem.Family.(fy).index).*S.Chem.Family.(fy).scale,2)*1000;
figure;plot(S.Time/3600,NOx - 500,'k')
legend('NOx delta (ppt)')

fy = 'Cly';
Cly = sum(x(:,S.Chem.Family.(fy).index).*S.Chem.Family.(fy).scale,2)*1000;
fy = 'Bry';
Bry = sum(x(:,S.Chem.Family.(fy).index).*S.Chem.Family.(fy).scale,2)*1000;
fy = 'Iy';
Iy = sum(x(:,S.Chem.Family.(fy).index).*S.Chem.Family.(fy).scale,2)*1000;
figure;plot(S.Time,Cly - 14,'g-',S.Time,Bry - 7,'r-',S.Time,Iy - 3,'b')
legend('Cly','Bry','Iy')
