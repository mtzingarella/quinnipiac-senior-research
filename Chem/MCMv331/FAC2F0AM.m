function FAC2F0AM(MCM_flnm,save_flnm)
% function FAC2F0AM(MCM_flnm,save_flnm)
% Reads FACSIMILE text-file output (e.g. from MCM web extraction tool)
% and converts it to a script for use with the F0AM chemical integrator.
% Note that the m-file generated by this routine will be written to the
% same directory as where the MCM subset text file is located.
%
% INPUTS:
% MCM_flnm: name of FACSIMILE text file, INCLUDING EXTENSION.
% save_flnm: (OPTIONAL) name of .m script to be generated. Default is MCM_flnm.m.
%
% 20101211 GMW  Original Creation Date 
% 20120210 GMW  Made a number of modifications for version 2 of the model. For full
%               details, see the UWCM_v2_ChangeLog.
% 20120801 GMW  Converted from script to function.
% 20120821 GMW  Fixed minor bug in the CheckFastCutoff section
% 20150608 GMW  Updates for F0AMv3:
%               - Removed instantaneous reaction assumption code
%               - Added RO2 and hv to reaction names
%               - Disentangled reaction block-building and writing of script.
%               - Renamed from MCMreadnwrite.m to FAC2F0AM.m
% 20210614 GMW  Changed method of scrolling through header/comment lines to make it more robust
%                against future changes (I hope).

%--------------------------------------------------------------------
% READ MCM FACSIMILE FILE
%--------------------------------------------------------------------
fid=fopen(MCM_flnm);

%scroll through headers
l = fgetl(fid);
while ~strncmp(l,'VARIABLE',8)
    l=fgetl(fid);
end

%grab species names
Snames = []; l=fgetl(fid);
while ~strncmp(l,'*',1)
    Snames = [Snames l ' '];
    l = fgetl(fid);
end
Snames = regexp(Snames,'\<*\w*\>','match'); %cell array of species names

% skip s'more comments
while strncmp(l,'*',1)
    l = fgetl(fid);
end

%grab lump peroxy radical names
RO2names = [];
while ~strncmp(l,'*',1)
    RO2names = [RO2names l ' '];
    l = fgetl(fid);
end
RO2names = regexp(RO2names,'\<*\w*\>','match'); %cell array of RO2 names
RO2names(1) = []; %remove "RO2" from names

%grab number of species and reactions
rstart = ftell(fid);
fseek(fid,-50,'eof');
l=fgetl(fid);
n = str2num(char(regexp(l,'\d*','match')));
nSp = n(1); %number of species
nRx = n(2); %number of reactions
fseek(fid,rstart,'bof');

% skip down to reactions
while ~strncmp(l,'%',1)
    l = fgetl(fid);
end

%read reactions and parse into cell arrays
k = cell(nRx,1);
Rnames = cell(nRx,1);
for i=1:nRx
    if l(end) ~= ';'
        l = [l ' ' fgetl(fid)]; %semicolon denotes end of reaction
    end
    l = l(3:end-2); %hack off beginning and end characters
    s = regexp(l,':','start');
    k{i} = l(1:s-2);
    Rnames{i} = l(s+2:end);
    l = fgetl(fid);
end
fclose(fid);

%fix components of rate constants string to be matlab-friendly
k = strrep(k,'TEMP','T');
k = strrep(k,'EXP','exp');
k = strrep(k,'D-','e-');
k = strrep(k,'D+','e');
k = strrep(k,'*','.*');
k = strrep(k,'/','./');
k = strrep(k,'@','.^');
k = strrep(k,'<','');
k = strrep(k,'>','');
k = strrep(k,'.*O2','.*.21.*M');
k = strrep(k,'.*N2','.*.78.*M');

%--------------------------------------------------------------------
% CREATE REACTION BLOCK STRINGS
%--------------------------------------------------------------------
Gstr = {}; fstr = {};
for i=1:length(Rnames)
    name = Rnames{i};
    ki = k{i};
    
    %hack up reaction
    arrow = regexp(name,'=','start'); %reactant/product divider
    rct = regexp(name(1:arrow-1),'\<*\w*\>','match'); %cell array of reactant names
    prd = regexp(name(arrow+1:end),'\<*\w*\>','match'); %cell array of product names

    %build reactant multiplier string and reactant f-string
    Gstr{i}=''; fstr{i}='';
    for j=1:length(rct)
        Gstr{i} = [Gstr{i} 'Gstr{i,' num2str(j) '} = ''' rct{j} '''; '];
        fstr{i} = [fstr{i} 'f' rct{j} '(i)=f' rct{j} '(i)-1; '];
    end
    
    %build product f-string
    for j=1:length(prd)
        fstr{i} = [fstr{i} 'f' prd{j} '(i)=f' prd{j} '(i)+1; '];
    end
    
    %deal with RO2 in rate constant
    if ~isempty(strfind(ki, '.*RO2'))
        ki = strrep(ki,'.*RO2','');
        Gstr{i} = [Gstr{i} 'Gstr{i,2} = ''RO2'';'];
        name = [name(1:arrow-1) '+ RO2 ' name(arrow:end)];
    end
    
    % deal with J in rate constant
    if ~isempty(strfind(ki,'J'))
        name = [name(1:arrow-1) '+ hv ' name(arrow:end)];
    end
    
    Rnames{i} = name;
    k{i} = ki;
end

%--------------------------------------------------------------------
% WRITE RATES SCRIPT FILE
%--------------------------------------------------------------------
%Open script file
[mpath,name] = fileparts(which(MCM_flnm));
if nargin<2 %default is same as input MCM filename
    save_flnm = [name '.m'];
end
[fid,msg] = fopen(fullfile(mpath,save_flnm),'w');
if fid==-1
    disp('Problem opening script m-file. Message from fopen:')
    disp(msg)
    return
end    

%Print header
fprintf(fid,'%s\n',['% ' save_flnm]);
fprintf(fid,'%s\n',['% generated from ' MCM_flnm]);
fprintf(fid,'%s\n',['% ' datestr(now,'YYYYmmdd')]);
fprintf(fid,'%s\n',['% # of species = ' num2str(length(Snames))]);
fprintf(fid,'%s\n\n',['% # of reactions = ' num2str(length(Rnames))]);

%Print species names
fprintf(fid,'%s\n','SpeciesToAdd = {...');
for i=1:length(Snames)
    s = Snames{i};
    fprintf(fid,'%s',['''' s '''; ']);
    if rem(i,10)==0
        fprintf(fid,'%s\n','...');
    end
end
fprintf(fid,'%s\n\n','};');

%Print RO2 names
fprintf(fid,'%s\n','RO2ToAdd = {...');
for i=1:length(RO2names)
    s = RO2names{i};
    fprintf(fid,'%s',['''' s '''; ']);
    if rem(i,10)==0
        fprintf(fid,'%s\n','...');
    end
end
fprintf(fid,'%s\n\n','};');

%Print some code
fprintf(fid,'%s\n\n','AddSpecies');

%print reaction parameters
for i=1:length(Rnames)
    fprintf(fid,'%s\n','i=i+1;');
    fprintf(fid,'%s\n',['Rnames{i} = ''' Rnames{i} ''';']);
    fprintf(fid,'%s\n',['k(:,i) = ' k{i} ';']);
    fprintf(fid,'%s\n',Gstr{i});
    fprintf(fid,'%s\n\n',fstr{i});
end

fprintf(fid,'%s\n\n\n',['%END OF REACTION LIST']);
fclose(fid);


