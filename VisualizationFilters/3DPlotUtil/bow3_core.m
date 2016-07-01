function conf_struct = bow3_core(conf_struct)
% bow_core: Complete implementation of a Bag-of-words model. The
% process described in this function starts with the 2 Raw sections of EEG
% data (section A and section B). This function executes in overall 
% the following steps:
% * Split sections in training and testing data according with cross-validation
% * Perform Time-frequency analysis using wavelet transform
% * Find discriminant features
% * Extract ranked top-X (defined by user) discriminant features
% * discretize the data with K-means clustering and special config.
% * Divide sections into epochs, according to the defined length
% * Calculate words probability on the training data (model selection)
% * Get the probabilities for testing data, make a desicion
% * Evaluate results and calculate error rate
% * Save decision socres and all important data to the input struct
% The function returns complete stats of the model execution into a struct


%-------- SETP 1: LOAD SPECIFIED EEG DATASET, EXTRACT RAW SECTIONS --------
% Load the EEG dataset and extract the RAW Section A and Section B data
% Get the sizes for testing and training data, check for errors in config.
[raw_section_A, raw_section_B, conf_struct] = bow3_step_1(conf_struct);

%--------- STEP 2: TIME-FREQUENCY ANALYSIS ON RAW DATA SECTIONS  ----------
% Returns a [Channel - Frequency - Time] 3D matrix using Wavelet transform
fprintf('Performing Time-Frequency Analysis....');
[section_A_3D, section_B_3D] = bow_step_2(raw_section_A, raw_section_B);
fprintf('done');


%-------------  INITIALIZATE VARIABLES AND START LOOPS  ------------------
% Individual corss-validation error rates
error_r = zeros(1,conf_struct.crossv_fold);

% IMPORTANT!: Save all the probability values for testing epochs. These
% values will be used to build ROC curve. Details:
% Rows: All the cross-validation iterations
% Column 1: testing epoch A => probability using traing A words values
% Column 2: testing epoch A => probability using traing B words values
% Column 3: testing epoch B => probability using traing B words values
% Column 4: testing epoch B => probability using traing A words values
conf_struct.test_epoch_prob_values = zeros...
    (conf_struct.crossv_fold * conf_struct.crossv_num_test_epochs, 4); 
tmp_var = 1;


%****************  THE MODEL SELECTION CYCLE [A to B Words] ***************
for model = conf_struct.model_selection(1):conf_struct.model_selection(2)
        
    % Display an indicator Message with the partial results
    disp('                                                            ');
    disp('============================================================');
    words_msg = char(['Bag of Words Model for: ', num2str(model), ' Words']);
    disp(words_msg);
    words_msg2 = char([num2str(conf_struct.crossv_fold), ...
        ' - Fold Cross-Validation configured.']);
    disp(words_msg2);
    disp('                                                            ');
    
    
    % Save the top N discriminat features location (chan, freq) for every
    % crossv  interation.
    conf_struct.discriminant_features_location = zeros...
        (conf_struct.rank_n,2,conf_struct.crossv_fold); 
    
       
    %**********************  THE CROSS-VALIDATION CYCLE *******************
    for i=1:conf_struct.crossv_fold
        
        conf_struct.crossv_iteration = i;    % Save current iteration
    
        %-------- STEP 3: SPLIT SECTIONS IN TRAINING AND TESTING ----------
        % Sizes are the same but data change according to the current
        % cross-validation iteration
        [training_A_3D, training_B_3D, testing_A_3D, testing_B_3D, conf_struct] = ...
            bow_step_3(section_A_3D, section_B_3D, conf_struct, i);
        
        
        %-------- STEP 4: FIND AND EXTRACT DISCRIMINAT FEATURES ----------
        % Perform Two sample T-test between all the Channel - Frequency
        % combinations on training A and training B data, rank top N
        % discriminant features. Extract data samples of the discrminant
        % channels - frequency pairs
        [disc_training_A, disc_training_B, disc_testing_A, disc_testing_B, conf_struct] = ...
            bow_step_4(training_A_3D, training_B_3D, testing_A_3D, testing_B_3D, conf_struct);
        
              
        %---------- STEP 5: CONCATENATE ALL DATA FOR CLUSTERING -----------
        % Concatenate all the discriminant data accodingly to the original
        % data points order, once done perform K-means clustering with some
        % additional options. After clustering is complete, split again the results
        % according the order they were before into training and testing samples
        conf_struct.current_words_number = model;
        [Cluster_training_A, Cluster_training_B, conf_struct] = ...
            bow_step_5v2(disc_training_A, disc_training_B, conf_struct);
          
        
        %------------  STEP 6: PERFORM THE BAG OF WORDS MODEL  ------------
        % The bag-of-words model. Calculates the words probabilty on the
        % training sections and uses them to obtaing the testing probabilty
        % values and estimate whether or not testing epochs belongs to
        % section A or B (desicion making)
        [error_r(i), conf_struct] = bow_step_6v2(Cluster_training_A,...
            disc_testing_A, Cluster_training_B, disc_testing_B, conf_struct);
        
        words_msg3 = char(['Iteration ', num2str(i), ' Succesfully Complete. Error rate: ',...
             num2str(error_r(i))]);
        disp(words_msg3);    
        
    end    
    %-------------------  END OF THE CROSS-VALIDATION CYCLE ---------------------
        
    % Save all the error rates per model selection iteration
    er_record_start = (conf_struct.crossv_fold*(tmp_var - 1)) + 1;
    er_record_end = (conf_struct.crossv_fold*tmp_var);
    conf_struct.all_error_rate(er_record_start:er_record_end) = error_r;
     
    % Display an indicator Message with the partial results
    erro_msg = char(['Cross-Validation Complete!.  Average error rate is:  ',...
        num2str(mean(error_r))]);
    disp(erro_msg);
    disp('============================================================');
    disp('                                                            ');
    
    % Save every ave. error rate result in the config struct
    conf_struct.crossv_error_rates(1,tmp_var) = mean(error_r);
    conf_struct.crossv_error_rates(2,tmp_var) = model;
    error_r(1:end) = 0; 
    tmp_var = tmp_var + 1;
    
end  
%--------------------  END OF THE MODEL SELECTION CYCLE CYCLE --------------------

end
