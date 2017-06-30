%% SPM12 Dartel using one structural file (just MPRAGE or just MBW)
% Created by Kevin Tan on Jun 29, 2017 (some code adopted from Bob Spunt)

% DESCRIPTION:
% 1) Functionals realigned to mean functional orientation
% 2) Co-register structural with mean functional (saved in nifti header)
% 3) Segment structural
% 4) Create DARTEL templates
% 5) Normalize functionals to MNI space via DARTEL
% 6) Normalize structural to MNI space via DARTEL

% INSTRUCTIONS:
% Edit parameters at the top of the wrapper then run the wrapper. The wrapper will
% call "run_dartel_1struct" so make sure that is in the same directory. This
% will save a "runStatus" struct that will contain each subjects'
% pre-Dartel status. It will also save the pre-Dartel workspace that will
% be used for Dartel. 


%% User-editable Parameters

% Path/directory/name information
owd = '/u/project/sanscn/kevmtan/scripts/SPM12_DARTEL/spm12_dartel_1struct/endo2';  % base study directory
codeDir = '/u/project/sanscn/kevmtan/scripts/SPM12_DARTEL/spm12_dartel_1struct'; % where code lives
output = '/u/project/sanscn/kevmtan/scripts/SPM12_DARTEL/spm12_dartel_1struct/endo2batch'; % dir in which to save scripts
subID = 'endo*'; % pattern for finding subject folders (use wildcards)
runID = 'BOLD_*'; % pattern for finding functional run folders (use wildcards)
funcID ='BOLD_'; % first character(s) in your functional images? (do NOT use wildcards)
structID = 'MBW_*'; % pattern for finding structural folder (use wildcards)

% Subjects to do/skip
subNam = {}; % do which subjects? (leave empty to do all)
skipSub = {};

% 4d or 3d functional .nii?
fourDnii = 1; % 1=4d, 0=3d

% Path of TPM tissues in your SPM directory
tpmPath = '/u/project/CCN/apps/spm12/tpm';

% Customizable preprocessing parameters
vox_size=3;    % voxel size at which to re-sample functionals (isotropic)
smooth_FWHM=8; % smoothing kernel (isotropic)

% Execute (1) or just make matlabbatches (0)
execPreDartel = 1;
execDartel = 1;

%% Setup subjects

% Find subject directories
if isempty(subNam)
    d = dir([owd '/' subID]);
    for ii = 1:length(d)
        subNam{ii} = d(ii).name;
        fprintf('Adding %s\n', subNam{ii})
    end
end
numSubs = length(subNam);
cd(codeDir);

% Prepare status struct
runStatus = struct('subNam',[],'status',[],'error',[]);
runStatus(numSubs).subNam = [];
runStatus(numSubs).status = [];
runStatus(numSubs).error = [];

%% Run Pre-dartel (explicitly parallelized per subject)
try
    mkdir(output);
catch
end

pool = parpool('local', numSubs);
parfor i = 1:numSubs
    % Pre-allocate subject in runStatus struct
    runStatus(i).subNam = subNam{i};
    
    % Cross-check subject with run/skip list
    if ismember(subNam{i}, skipSub)
        runStatus(i).status = 0;
        runStatus(i).error = 'Subject in exclusion list';
        disp(['Skipping subject ' subNam{i} ', is in exclusion list']);
        continue
    else % Run subject
        disp(['Running subject ' subNam{i}]);
        [runStatus(i).status, runStatus(i).error, a_allfuncs{i}, allt1{i},...
            allrc1{i}, allrc2{i}, allu_rc1{i}] = run_dartel_1struct(subNam{i},...
            owd, codeDir, output, runID, funcID, structID, fourDnii, execPreDartel);
        if runStatus(i).status == 1
            disp(['subject ' subNam{i} ' successful']);
        else
            runStatus(i).status = 0;
            disp([runStatus(i).error ' for ' subNam{i}]);
        end
    end
end
delete(pool);

% Get rid of image frame specification for func images (SPM idiosyncrasy)
if fourDnii == 1
    for ia = 1:length(a_allfuncs)
        for ib = 1:length(a_allfuncs{ia})
            chars = length(a_allfuncs{ia}{ib}{1})-2;
            allfuncs{ia}{ib,1} = a_allfuncs{ia}{ib}{1}(1:chars);
        end
    end
else
    for ia = 1:length(a_allfuncs)
        for ib = 1:length(a_allfuncs{ia})
            chars = length(a_allfuncs{ia}{ib})-2;
            allfuncs{ia}{ib,1} = a_allfuncs{ia}{ib}(1:chars);
        end
    end
end

% Save stuff
date = datestr(now,'yyyymmdd_HHMM');
filename = [output '/runStatus_' date '.mat'];
save(filename,'runStatus');
filename = [output '/forDartel_workspace_' date '.mat']; % Use this to re-do "run dartel" if it fails
save(filename);

%% Create DARTEL matlabbatch

spm('defaults','fmri'); spm_jobman('initcfg');

% Subjects with no errors in pre-dartel
inds = find([runStatus.status]);

% Create Segmentation matlabbatch (implicitly parallelized in SPM)
for s = 1:length(inds)
    matlabbatch{1}.spm.spatial.preproc.channel.vols{s,1} = allt1{inds(s)};
end
matlabbatch{1}.spm.spatial.preproc.channel.biasreg = 0.0001;
matlabbatch{1}.spm.spatial.preproc.channel.biasfwhm = 60;
matlabbatch{1}.spm.spatial.preproc.channel.write = [0 1];
matlabbatch{1}.spm.spatial.preproc.tissue(1).tpm = cellstr([tpmPath '/TPM.nii,1']);
matlabbatch{1}.spm.spatial.preproc.tissue(1).ngaus = 2;
matlabbatch{1}.spm.spatial.preproc.tissue(1).native = [1 1];
matlabbatch{1}.spm.spatial.preproc.tissue(1).warped = [0 0];
matlabbatch{1}.spm.spatial.preproc.tissue(2).tpm = cellstr([tpmPath '/TPM.nii,2']);
matlabbatch{1}.spm.spatial.preproc.tissue(2).ngaus = 2;
matlabbatch{1}.spm.spatial.preproc.tissue(2).native = [1 1];
matlabbatch{1}.spm.spatial.preproc.tissue(2).warped = [0 0];
matlabbatch{1}.spm.spatial.preproc.tissue(3).tpm = cellstr([tpmPath '/TPM.nii,3']);
matlabbatch{1}.spm.spatial.preproc.tissue(3).ngaus = 2;
matlabbatch{1}.spm.spatial.preproc.tissue(3).native = [1 0];
matlabbatch{1}.spm.spatial.preproc.tissue(3).warped = [0 0];
matlabbatch{1}.spm.spatial.preproc.tissue(4).tpm = cellstr([tpmPath '/TPM.nii,4']);
matlabbatch{1}.spm.spatial.preproc.tissue(4).ngaus = 3;
matlabbatch{1}.spm.spatial.preproc.tissue(4).native = [0 0];
matlabbatch{1}.spm.spatial.preproc.tissue(4).warped = [0 0];
matlabbatch{1}.spm.spatial.preproc.tissue(5).tpm = cellstr([tpmPath '/TPM.nii,5']);
matlabbatch{1}.spm.spatial.preproc.tissue(5).ngaus = 4;
matlabbatch{1}.spm.spatial.preproc.tissue(5).native = [0 0];
matlabbatch{1}.spm.spatial.preproc.tissue(5).warped = [0 0];
matlabbatch{1}.spm.spatial.preproc.tissue(6).tpm = cellstr([tpmPath '/TPM.nii,6']);
matlabbatch{1}.spm.spatial.preproc.tissue(6).ngaus = 2;
matlabbatch{1}.spm.spatial.preproc.tissue(6).native = [0 0];
matlabbatch{1}.spm.spatial.preproc.tissue(6).warped = [0 0];
matlabbatch{1}.spm.spatial.preproc.warp.mrf = 1;
matlabbatch{1}.spm.spatial.preproc.warp.cleanup = 1;
matlabbatch{1}.spm.spatial.preproc.warp.reg = [0 0.001 0.5 0.05 0.2];
matlabbatch{1}.spm.spatial.preproc.warp.affreg = 'mni';
matlabbatch{1}.spm.spatial.preproc.warp.fwhm = 0;
matlabbatch{1}.spm.spatial.preproc.warp.samp = 3;
matlabbatch{1}.spm.spatial.preproc.warp.write = [0 1];

% DARTEL: create templates
for s = 1:length(inds)
    matlabbatch{2}.spm.tools.dartel.warp.images{1,1}{s,1} = allrc1{inds(s)};
    matlabbatch{2}.spm.tools.dartel.warp.images{1,2}{s,1} = allrc2{inds(s)};
end
matlabbatch{2}.spm.tools.dartel.warp.settings.template = 'Template';
matlabbatch{2}.spm.tools.dartel.warp.settings.rform = 0;
matlabbatch{2}.spm.tools.dartel.warp.settings.param(1).its = 3;
matlabbatch{2}.spm.tools.dartel.warp.settings.param(1).rparam = [4 2 1e-06];
matlabbatch{2}.spm.tools.dartel.warp.settings.param(1).K = 0;
matlabbatch{2}.spm.tools.dartel.warp.settings.param(1).slam = 16;
matlabbatch{2}.spm.tools.dartel.warp.settings.param(2).its = 3;
matlabbatch{2}.spm.tools.dartel.warp.settings.param(2).rparam = [2 1 1e-06];
matlabbatch{2}.spm.tools.dartel.warp.settings.param(2).K = 0;
matlabbatch{2}.spm.tools.dartel.warp.settings.param(2).slam = 8;
matlabbatch{2}.spm.tools.dartel.warp.settings.param(3).its = 3;
matlabbatch{2}.spm.tools.dartel.warp.settings.param(3).rparam = [1 0.5 1e-06];
matlabbatch{2}.spm.tools.dartel.warp.settings.param(3).K = 1;
matlabbatch{2}.spm.tools.dartel.warp.settings.param(3).slam = 4;
matlabbatch{2}.spm.tools.dartel.warp.settings.param(4).its = 3;
matlabbatch{2}.spm.tools.dartel.warp.settings.param(4).rparam = [0.5 0.25 1e-06];
matlabbatch{2}.spm.tools.dartel.warp.settings.param(4).K = 2;
matlabbatch{2}.spm.tools.dartel.warp.settings.param(4).slam = 2;
matlabbatch{2}.spm.tools.dartel.warp.settings.param(5).its = 3;
matlabbatch{2}.spm.tools.dartel.warp.settings.param(5).rparam = [0.25 0.125 1e-06];
matlabbatch{2}.spm.tools.dartel.warp.settings.param(5).K = 4;
matlabbatch{2}.spm.tools.dartel.warp.settings.param(5).slam = 1;
matlabbatch{2}.spm.tools.dartel.warp.settings.param(6).its = 3;
matlabbatch{2}.spm.tools.dartel.warp.settings.param(6).rparam = [0.25 0.125 1e-06];
matlabbatch{2}.spm.tools.dartel.warp.settings.param(6).K = 6;
matlabbatch{2}.spm.tools.dartel.warp.settings.param(6).slam = 0.5;
matlabbatch{2}.spm.tools.dartel.warp.settings.optim.lmreg = 0.01;
matlabbatch{2}.spm.tools.dartel.warp.settings.optim.cyc = 3;
matlabbatch{2}.spm.tools.dartel.warp.settings.optim.its = 3;

% DARTEL: normalize functional images to MNI
matlabbatch{3}.spm.tools.dartel.mni_norm.template(1) = cfg_dep('Run Dartel (create Templates): Template (Iteration 6)', substruct('.','val', '{}',{2}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','template', '()',{7}));
for s = 1:length(inds)
    matlabbatch{3}.spm.tools.dartel.mni_norm.data.subj(s).flowfield{1} = allu_rc1{inds(s)};
    matlabbatch{3}.spm.tools.dartel.mni_norm.data.subj(s).images = allfuncs{inds(s)};
end                                             
matlabbatch{3}.spm.tools.dartel.mni_norm.vox = [vox_size vox_size vox_size];
matlabbatch{3}.spm.tools.dartel.mni_norm.bb = [-78 -112 -50; 78 76 85];
matlabbatch{3}.spm.tools.dartel.mni_norm.preserve = 0;
matlabbatch{3}.spm.tools.dartel.mni_norm.fwhm = [smooth_FWHM smooth_FWHM smooth_FWHM];

% DARTEL: normalize structural to MNI
matlabbatch{4}.spm.tools.dartel.mni_norm.template(1) = cfg_dep('Run Dartel (create Templates): Template (Iteration 6)', substruct('.','val', '{}',{2}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','template', '()',{7}));
for s = 1:length(inds)
    matlabbatch{4}.spm.tools.dartel.mni_norm.data.subj(s).flowfield{1} = allu_rc1{inds(s)};
    matlabbatch{4}.spm.tools.dartel.mni_norm.data.subj(s).images{1} = allt1{inds(s)};
end                                            
matlabbatch{4}.spm.tools.dartel.mni_norm.vox = [1 1 1];
matlabbatch{4}.spm.tools.dartel.mni_norm.bb = [-78 -112 -50; 78 76 85];
matlabbatch{4}.spm.tools.dartel.mni_norm.preserve = 0;
matlabbatch{4}.spm.tools.dartel.mni_norm.fwhm = [0 0 0];

%% Save & run DARTEL matlabbatch

% save matlabbatch struct in output folder
time_stamp = datestr(now,'yyyymmdd_HHMM');
filename = [output '/DARTEL_1struct_' time_stamp];
save(filename,'matlabbatch');                         

% Execute matlabbatch
if execDartel == 1
    spm_jobman('run',matlabbatch);
    disp('DARTEL COMPLETED');
end
