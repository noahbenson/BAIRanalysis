function design = bidsTSVtoDesign(projectDir, subject, session, tasks, runnum, designFolder)
%Convert tsv files from BIDS directory to design matrices for GLM
% design = bidsTSVtoDesign(projectDir, subject, [session], [tasks], [runnum], [designFolder])
%
% Input
%     projectDir:       path where the BIDS projects lies (string)
%     subject:          BIDS subject name (string, all lower case)
%     session:          BIDS session name (string, all lower case)
%                           default: folder name inside subject dir (if
%                           more than one or less than one, return error)
%     tasks:            one or more BIDS tasks (string or cell array of strings)
%                           default: all tasks in session
%     runnum:           BIDS run numbers (vector or cell array of vectors)
%                           default: all runs for specified tasks
%     designFolder:     folder name to save design matrices as tsv files
%                           Note that this folder is assumed to reside in 
%                               <projectDir>/derivatives/design_matrices/
%                           default = [], which means no subfolder inside
%                           design_matrices
% Output
%     design:           Matrix or cell array of matrices, time by condition
%
% Example 1
%     projectDir        = '/Volumes/server/Projects/BAIR/Data/BIDS/visual'; 
%     subject           = 'wlsubj054';
%     session           = 'nyu3t01';
%     tasks             = 'spatialobject';
%     runnum            = 1:4;
%     design = bidsTSVtoDesign(projectDir, subject, session, tasks, runnum);
%
% Example 2
%     projectDir        = '/Volumes/server/Projects/BAIR/Data/BIDS/visual'; 
%     subject           = 'wlsubj054';
%     session           = 'nyu3t01';
%     tasks             = 'spatialobject';
%     design = bidsTSVtoDesign(projectDir, subject, session, tasks)
%
% See also bidsGLM.m


if ~exist('session', 'var'),    session = [];   end
if ~exist('tasks', 'var'),      tasks   = [];   end
if ~exist('runnum', 'var'),     runnum  = [];   end

[session, tasks, runnum] = bidsSpecifyEPIs(projectDir, subject,...
    session, tasks, runnum);

% Specifiy the path to the design matrices for saving as tsv files
if ~exist('designFolder', 'var'), designFolder = []; end
designPath = fullfile(projectDir, 'derivatives', 'design_matrices', ...
    sprintf('sub-%s',subject), sprintf('ses-%s',session), designFolder);
if ~exist(designPath, 'dir'), mkdir(designPath); end

% TSV file with onsets to make the design matrix (vector)
pth = fullfile(projectDir, sprintf('sub-%s', subject), ...
    sprintf('ses-%s', session), 'func');

assert(exist(pth, 'dir')>0)

% total number of runs across tasks
n = sum(cellfun(@numel, runnum));

% initialize design matrix
design = cell(1,n);
T      = cell(1,n);
numvol = zeros(1,n);
TR     = zeros(1,n);

% Get tsv files
scan = 1;
for ii = 1:length(tasks)
    for jj = 1:length(runnum{ii})
        
              
        prefix = sprintf('sub-%s_ses-%s_task-%s_run-%d', ...
            subject, session, tasks{ii}, runnum{ii}(jj));
        
        epifile  = sprintf('%s_bold.nii.gz', prefix);
        jsonfile = sprintf('%s_bold.json', prefix);
        tsvfile  = sprintf('%s_events.tsv', prefix);
        
        assert(exist(fullfile(pth,epifile), 'file')>0)        
        assert(exist(fullfile(pth,tsvfile), 'file')>0)
        assert(exist(fullfile(pth,jsonfile), 'file')>0)
        
        % check scan length and TR length
        hdr          = niftiinfo(fullfile(pth, epifile));
        numvol(scan) = hdr.ImageSize(end);
        json         = fileread(fullfile(pth, jsonfile));
        json_info    = jsondecode(json);
        TR(scan)     = json_info.RepetitionTime; % 850 ms
                
        T{scan}      = tdfread(fullfile(pth,tsvfile));
        
        scan = scan+1;
        
    end
end

% Now convert the tsv tables into matrices
%   figure out the number of unique conditions across all runs
%   that should be the width of the matrix
all_trial_types = [];
for ii = 1:n    
    all_trial_types = cat(1, all_trial_types, T{ii}.trial_type);
end

unique_conditions = unique(all_trial_types);
num_conditions = length(unique_conditions);


%   loop over all runs and make each matrix
for ii = 1:n   
    
    m = zeros(numvol(ii), num_conditions);
    these_conditions = T{ii}.trial_type;    
    [~,col_num] = ismember(these_conditions, unique_conditions);
    
    % time in seconds of start of each event
    row_nums = round(T{ii}.onset / TR(ii))+1;
    
    linearInd = sub2ind(size(m), row_nums, col_num);

    m(linearInd) = 1;
    design{ii} = m;
end

% save figure with images of design matrices
f = figure('visible', 'off'); 
for ii = 1:length(design)
    subplot(1,length(design), ii); 
    imagesc(design{ii});
    title(sprintf('Run %d', ii));
    axis off;
end
saveas(f, fullfile(designPath, 'designMatrices.png'))

%% save
scan = 1;

for ii = 1:length(tasks)
    for jj = 1:length(runnum{ii})
        m = design{scan};

        % sub-wlsubj054_ses-nyu3T01_task-spatialobject_run-1_events.tsv
        fname = sprintf('sub-%s_ses-%s_task-%s_run-%d_design.tsv', ...
            subject, session, tasks{ii}, runnum{ii}(jj));
        
        savepth = fullfile(designPath, fname);
        dlmwrite(savepth, m, 'delimiter','\t');
        
        scan = scan + 1;
    end
end