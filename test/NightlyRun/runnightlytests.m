% Define the path to ISSM Nightly Run directory
% Adjust the root path ($ISSM_DIR) according to your environment
issm_dir = getenv('ISSM_DIR');
nightly_dir = fullfile(issm_dir, 'test', 'NightlyRun');
addpath nightly_dir

% Find all test files matching pattern 'test*.m'
files = dir(fullfile(nightly_dir, 'test*.m'));

failed_tests = {};
passed_count = 0;

fprintf('Starting ISSM Nightly Run test loop...\n\n');

for i = 1:length(files)
    filename = files(i).name;
    
    % Extract the test ID number from the filename (e.g., 'test306.m' -> 306)
    test_id = str2double(regexp(filename, '\d+', 'match', 'once'));
    if isnan(test_id), continue; end
    
    fprintf('Running Test %d (%s)... ', test_id, filename);
    
    try
        % CALL CORRECTION: Run natively without expecting an output variable.
        % If the test fails, ISSM will throw an unhandled exception 
        % which will immediately be caught by the catch block below.
        runme('id', test_id);
        
        fprintf('PASSED\n');
        passed_count = passed_count + 1;
        
    catch ME
        % Capture syntax errors, test failures, or crashes
        fprintf('FAILED\n');
        failed_tests{end+1} = sprintf('%s (Error: %s)', filename, ME.message);
    end
end

% Summary Report
fprintf('\n============================\n');
fprintf('ISSM NIGHTLY TEST RESULTS\n');
fprintf('============================\n');
fprintf('Total Ran: %d\n', passed_count + length(failed_tests));
fprintf('Passed:    %d\n', passed_count);
fprintf('Failed:    %d\n', length(failed_tests));

if ~isempty(failed_tests)
    fprintf('\nList of Failed Tests:\n');
    for i = 1:length(failed_tests)
        fprintf(' - %s\n', failed_tests{i});
    end
else
    fprintf('\nAll nightly tests passed successfully!\n');
end