
/*

ExpLab has recently implemented the new V3 pipeline, introducing features such as the Global View Report and various pipeline optimizations. To facilitate a smooth transition, table generation for the existing V2 pipeline (summary_v2 dataset) will continue for one additional month, but will be discontinued starting September 12, 2025.
All ExpLab users relying on tables in summary_v2 must migrate to the appropriate tables in summary_v3 prior to the deprecation date.
For your convenience, please refer to the table mappings below:
`explab-298609.summary_v2` Tables  <--> Replacement in V3 Pipeline
summary_v2.experiment_summary <--> summary_view.experiment_summary
summary_v2.statistical_summary_multi_level_view <--> summary_view.statistical_summary_multi_level
Other tables in summary_v2 dataset <--> Available in summary_v3 dataset
We recommend reviewing your workflows to ensure all queries and processes are updated to use the new tables.


*/

SELECT
	if(exp_group_id=4661,'control','test') as exp_group,
	SUM(count_imp) as imp,
	SUM(count_click) as click,
	SUM(count_install) as install,
	SUM(total_moloco_spent) as spend,
	SUM(count_kpi_d7) as d7action,
	SUM(count_distinct_kpi_d7) as d7distinct_action,
	sum(total_revenue_kpi_d7) as d7_revenue
FROM
	`explab-298609.summary_v3.experiment_summary`
WHERE
	utc_date BETWEEN '2023-12-15' AND '2024-01-04'
	AND campaign_id IN ('WhNQQYcrMHHvt31d','YJLPTUb4y4kzGren')
	AND exp_group_id IN (4661, 4662, 4663)
GROUP BY 1


