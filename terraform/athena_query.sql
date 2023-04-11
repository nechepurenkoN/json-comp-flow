CREATE EXTERNAL TABLE json_comp_view(
    StartDate string,
    Input string
    Output string,
)
ROW FORMAT SERDE 'org.apache.hive.hcatalog.data.JsonSerDe'
LOCATION 's3://${result_bucket}/${run_id_path}/?prefix=SUCCEEDED_';