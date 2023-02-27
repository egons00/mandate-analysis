--Data check 
SELECT *
FROM gc_paysvc_live.mandates
LIMIT 5

SELECT *
FROM gc_paysvc_live.organisations
LIMIT 5

SELECT * 
FROM gc_paysvc_live.payments 
LIMIT 5;

select 
 count(distinct mandate_id)
,count(distinct id) 
from gc_paysvc_live.payments limit 5;
;;



--What’s the activation rate of mandates, split by vertical?
SELECT
     parent_vertical                AS parent_vertical
    ,ROUND(activation_rate, 2)      AS activation_rate
FROM (
    SELECT
           o.parent_vertical                                                                AS parent_vertical
           ,COUNT(DISTINCT m.id)                                                            AS total_mandates
           ,COUNT(DISTINCT CASE WHEN p.id IS NOT NULL THEN m.id END)                        AS activated_mandates
           ,COUNT(DISTINCT CASE WHEN p.id IS NOT NULL THEN m.id END) / COUNT(DISTINCT m.id) AS activation_rate
    FROM gc_paysvc_live.mandates m
    LEFT JOIN gc_paysvc_live.payments p ON
        m.id = p.mandate_id
    JOIN gc_paysvc_live.organisations o ON
        m.organisation_id = o.id
    GROUP BY o.parent_vertical
)
;


--Campaign analysis
WITH pre_campaign_payments AS (
    SELECT 
    COUNT(DISTINCT CASE WHEN created_at < '2018-12-01' THEN id END) AS pre_campaign_count
    FROM gc_paysvc_live.payments
),
post_campaign_payments AS (
    SELECT 
    COUNT(DISTINCT CASE WHEN created_at >= '2018-12-01' THEN id END) AS post_campaign_count
    FROM gc_paysvc_live.payments
)
SELECT
     pre.pre_campaign_count
    ,post.post_campaign_count
    ,(post.post_campaign_count - pre.pre_campaign_count)                                 AS increase_in_payments
    ,(post.post_campaign_count - pre.pre_campaign_count) / (pre.pre_campaign_count)      AS percent_increase
FROM pre_campaign_payments pre, post_campaign_payments post
;
--Campaign wasn't efective


--On which vertical should the company focus next?
SELECT parent_vertical,
       num_usages,
       avg_amount,
       total_amount,
       num_organizations,
       RANK() OVER (ORDER BY num_usages DESC, total_amount DESC, avg_amount DESC, num_organizations DESC) AS rank
FROM (
         SELECT o.parent_vertical,
                COUNT(DISTINCT m.id)              AS num_usages,
                AVG(p.amount)                     AS avg_amount,
                SUM(p.amount)                     AS total_amount,
                COUNT(DISTINCT m.organisation_id) AS num_organizations,
         FROM gc_paysvc_live.organisations o
                  JOIN gc_paysvc_live.mandates m
                       ON o.id = m.organisation_id
                  JOIN gc_paysvc_live.payments p
                       ON m.id = p.mandate_id
         GROUP BY o.parent_vertical
     )
ORDER BY rank
;




