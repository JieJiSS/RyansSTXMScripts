function [DirLabelS]=DirLabelMapsStruct(InDir,sample,saveflg,savepath,sp2,impar)

%%  DirLabS=DirLabelMapsStruct(InDir,sample,saveflg,savepath,sp2)
%%
%% INPUT: InDir - cell array of strings containing directory where stacks are saved as
%%                .mat files
%%        sample - cell array of strings indicating sample names
%%        saveflg - 1=save a ton of figs, 0=do not save
%%        savepath - string indicating save directory
%%        sp2 - sp2 threshold for carbon maps
%%        impar - option for cropped images - either 'SVD' or 'RGB' for RGB binary maps
%% OUTPUT: 
%%         LabelCnt - matrix containing counts for particle classes
%%                    columns: [OC,ECOC,INECOC,INOC] rows: [sample1,
%%                    sample2, sample3...]
%%         OutSpec - cell array containing grand average spectra for the
%%                   different samples. [energy,OD] - legacy variable
%%         PartSize - cell array containing sizes for individual particles
%%                within the different samples
%%         label - cell array containing labels for individual particles
%%         CmpSiz - cell array of sample matrices containing component
%%                  areas (in um^2). Rows correspond to particles and columns are as
%%                  follows: [OCArea,InArea,ECArea,TotalParticleArea]
%%         SootCarbox is ??
%%         TotalCarbon is the height of total carbon/particle
%%         OutOCSpec - Cell array of spectra for OC particles only
%%         OutRad - Cell array of average radial particle scans for each
%%                  class. Row is relative dist from center and column is
%%                  particle type.
%%         OutCmp - cell array of average spectra for component specified
%%                  in call to ComponentSpec.m
%%         RadStd: cell array of average component (BC, OC, IN) radial scans
%%         SingRad: cell array of single particle radial scans 
%%         SootDistCent: cell array of the relitive distance of soot center 
%%           of mass from the center of the particle.
%%         SootDistCentInscribed: cell array of Distances of the soot 
%%           inclusion from the edge of the largest inscribed circle
%%         SootEcc: cell array of soot inclusion eccentricities
%%         SootMaj: cell array of soot elipitical major axes
%%         SootMin: cell array of soot elipitical minor axes
%%         SootCvex: cell array of soot convexities
%%         SootArea: cell array of soot inclusion areas (in um^2)
%%         CroppedParts: cell array of cropped particle RGB images for 
%%           later plotting
%%         ImageProps: cell array of image property vectors for the ...
%%           original image? [XLength,YLength,Xpoints,Ypoints]
%%         PartDirs: cell array of directories original data can be found in
%%         PartSN: cell array of particle serial numbers.
%% OCT 2009, RCMoffet, update 7/7/2016 RCMoffet

startingdir=dir;
LabelCnt=zeros(4,length(InDir));
stackcnt=0;
mapcnt=0;

%% begin loop over sample directories
for j=1:length(InDir)  %% loop over different sample directories
    cd(InDir{j});
    directory=dir;
    loopctr=1;
    TotPix=0;

    %% initialize variables
    PartSize{j}=[];% particle sizes
    label{j}=[];% particle labels (as strings)
    CmpSiz{j}=[];% areas of componenets
    SootCarbox{j}=[];
    TotalCarbon{j}=[];% OD of total carbon (OD(320)-OD(278))
    Carbox{j}=[];
    Sp2{j}=[];
%     SootDistCent{j}=[];% relative distance of the soot inclusion from the particle center
%     SootDistCentInscribed{j}=[];
%     SootEcc{j}=[];% eccentricity of the soot inclusion
%     SootMaj{j}=[];% major axis of soot inclusion
%     SootMin{j}=[];% minor axis of the soot inclusion
%     SootCvex{j}=[];% convexity of the soot inclusion
    SootArea{j}=[];% 
    CroppedParts{j}=[]; % Cropped RGB Images of particles
    ImageProps{j}=[]; % image properties: [Xvalue,Yvalue,# of X pixels,# of Y pixels]
    PartDirs{j,:}=[];
    PartSN{j}=[];
    %% loop over stacks
    for l=1:length(directory)
        ind=strfind(directory(l).name,'.mat');
        % if the directory has a mat file...
        if ~isempty(ind)
            load(directory(l).name); %% load data file
            disp(sprintf('%s%s%s',InDir{j},'\',directory(l).name));
            %% error checking
            if length(Snew.eVenergy)<3
                disp('too few images for CarbonMaps');
                continue
            end
            test=Snew.eVenergy(Snew.eVenergy<325 & Snew.eVenergy>275);
            if isempty(test)
                disp('this is not the carbon edge')
                continue
            end
            if max(test)<315
                disp('no post edge, stack skipped')
                continue
            end
            if length(test)>8 %% checking numbers of stacks and maps for screen display
                stackcnt=stackcnt+1;
            else
                mapcnt=mapcnt+1;
            end
            disp(sprintf('# of Stacks = %g, # of Maps = %g',stackcnt,mapcnt));
            %% Run DiffMaps and label particles
            if saveflg==1  %% test for figure saving option "saveflg"
                Sinp=CarbonMaps(Snew,sp2,savepath,sample{j});
                %                 Sinp=SootCarboxMap(Sinp,0);
                Sinp=SootCarboxSizeHist(Sinp,1);
            else
                Sinp=CarbonMaps(Snew,sp2,1); %% call without producing figures
                %                 Sinp=SootCarboxMap(Snew,0);
                
                Sinp=SootCarboxSizeHist(Sinp,1);
            end
            if isempty(Sinp.Size)
                disp('no particles identified, stack skipped')%% this was happening with glitches and synchrotron/beamline noise in the data.
                continue
            end
            %% count particle classes
            NewCount=LabelCount(Sinp)';
            LabelCnt(:,j)=LabelCnt(:,j)+NewCount;
            %% Find soot inclusion distance from the center
            Sinp=DistCent(Sinp);
            %% Do radial scans
            [AvgRadClass{loopctr},AvgStdClass{loopctr},npart{loopctr},SingRadScans{loopctr}]=...
                MapRadialScanSpline(Sinp,1,0);
            %% Crop particle comp maps
            Sinp=CropPart(Sinp,0,impar); % can change last input to 'RGB' for CompMaps
            close
            for i=1:length(Sinp.CroppedParts)
                cpartsiz=size(Sinp.CroppedParts{1});
                if sum(cpartsiz(1:2))==0
                    disp(sprintf('%s%s%s IS GIVING EMPTY RGBs!!',InDir{j},'\',directory(l).name));
                end
            end
            %% Give Labels and size for plotting chemical size distributionsas
            [class,siz]=ChemSiz(Sinp);
            %% Get image size 
            imsiz=size(Sinp.LabelMat);
            %% Append data from previous .mat files
            PartSize{j}=[PartSize{j},siz];
            label{j}=[label{j},class];
            CmpSiz{j}=[CmpSiz{j};Sinp.CompSize];  %% area of the different components
            SootCarbox{j}=[SootCarbox{j},Sinp.AvSootCarb];
            TotalCarbon{j}=[TotalCarbon{j},Sinp.AvTotC]; %% height of total carbon/particle
            Carbox{j}=[Carbox{j},Sinp.AvCarbox]; %% this is the height of the carbox peak/particle
            Sp2{j}=[Sp2{j},Sinp.AvSp2]; %% This is the height of the Sp2 peak/particle
            SootDistCent{j}=[SootDistCent{j},Sinp.SootDistCent];
            SootDistCentInscribed{j}=[SootDistCentInscribed{j},Sinp.SootDistCentInscribed];
            SootEcc{j}=[SootEcc{j};Sinp.SootEccentricity];
            SootMaj{j}=[SootMaj{j};Sinp.SootMajorAxisLength];
            SootMin{j}=[SootMin{j};Sinp.SootMinorAxisLength];
            SootCvex{j}=[SootCvex{j};Sinp.SootConvexArea];
            SootArea{j}=[SootArea{j};Sinp.SootArea];
            CroppedParts{j}=[CroppedParts{j};Sinp.CroppedParts];
            OutRad{j}=[];RadStd{j}={};SingRad{j}={};
            [OutRad{j},RadStd{j},SingRad{j}]=SumRad(AvgRadClass,AvgStdClass,npart,SingRadScans);
            ImageProps{j}=[ImageProps{j};Sinp.ImageProps];
            PartDirs{j}=[PartDirs{j};Sinp.PartDirs];
            PartSN{j}=[PartSN{j};Sinp.PartSN];
            %%     figure,boxplot(SingRad{j}{4}','plotstyle','compact')
            %%     figure,errorbar([1:11],OutRad{j}(:,4),RadStd{j}(:,4))
            %%     OutRad=NaN;
            %% clean house
            clear ind NewCount;
            loopctr=loopctr+1;
            clear siz;
            close all;
        end
        %         catch ME
        %             ME.stack
        %             ME.message
        %             disp('.mat file probably not a STXM stack')
        %         end
    end
    %% clean house
    clear loopctr ColLab collabel %SingPTab;
end
%% assign output to data structure
DirLabelS.LabelCnt=LabelCnt;
DirLabelS.PartSize=PartSize;
DirLabelS.label=label;
DirLabelS.CmpSiz=CmpSiz;
DirLabelS.SootCarbox=SootCarbox;
DirLabelS.TotalCarbon=TotalCarbon;
DirLabelS.Carbox=Carbox;
DirLabelS.Sp2=Sp2;
DirLabelS.OutRad=OutRad; % radial scans: for each particle, a matrix of radial scans of [pre/
DirLabelS.RadStd=RadStd;
DirLabelS.SingRad=SingRad;
% DirLabelS.SootDistCent=SootDistCent;
% DirLabelS.SootDistCentInscribed=SootDistCentInscribed;
% DirLabelS.SootEcc=SootEcc;
% DirLabelS.SootMaj=SootMaj;
% DirLabelS.SootMin=SootMin;
% DirLabelS.SootCvex=SootCvex;
% DirLabelS.SootArea=SootArea;
DirLabelS.CroppedParts=CroppedParts; %% Extract data by calling like this: DirLabelS.CroppedParts{1}{1}
DirLabelS.ImageProps=ImageProps;
DirLabelS.PartDirs=PartDirs;
DirLabelS.PartSN=PartSN;
return


