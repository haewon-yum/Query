/* 
    Check if a RE action model is eligible to be served, use the table
    `moloco-dsp-ml-prod.training_log_exporter_evaluation_prod.media`

    FYI RE Model eligibility
    1. Days since first impression >= 2
    2. Model calibration (p over a) between 0.5 and 2
    3. Daily d7 unique actions >= 5

    Schema
    - b_campaign
    - data_timestamp
    - is_self_traffic
    - model_timestamp
    - model_version
    - prediction_type
    - data_type
    - auc_roc
    - num_examples
    - num_positives
    - mean_label
    - mean_prediction
    - log_loss
    

*/

SELECT  *, 
  num_positives / 
FROM `moloco-dsp-ml-prod.training_log_exporter_evaluation_prod.media` 
WHERE TIMESTAMP_TRUNC(model_timestamp, HOUR) >= TIMESTAMP("2025-03-26T00:00:00") 
  AND b_campaign = 'UfS41AvUCHhiXzCw'
ORDER BY model_timestamp