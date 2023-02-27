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
    SELECT COUNT(DISTINCT CASE WHEN created_at <= '2018-12-01' AND created_at >= '2018-10-01' THEN id END) AS pre_campaign_count
    FROM gc_paysvc_live.payments
),
post_campaign_payments AS (
    SELECT COUNT(DISTINCT CASE WHEN created_at >= '2018-12-01' AND created_at <= '2019-02-01' THEN id END) AS post_campaign_count
    FROM gc_paysvc_live.payments
)
SELECT
    pre.pre_campaign_count
    ,post.post_campaign_count
    ,(post.post_campaign_count - pre.pre_campaign_count)                                        AS increase_in_payments
    ,ROUND((post.post_campaign_count - pre.pre_campaign_count) / (pre.pre_campaign_count), 2)   AS percent_increase
FROM pre_campaign_payments pre, post_campaign_payments post
--Payment count increased by 23%
--Campaign was efective


-- Although the difference between when the payments were made and when charged increased after the campaign launch
WITH pre_camp AS (
    SELECT   o.parent_vertical
            ,DATE_DIFF(cast(charge_date AS date), cast(p.created_at AS date), DAY) AS days_diff
    FROM gc_paysvc_live.payments p
             LEFT JOIN gc_paysvc_live.mandates m
                       on p.mandate_id = m.id
             JOIN gc_paysvc_live.organisations o ON
        m.organisation_id = o.id
    WHERE p.created_at <= '2018-12-01'
      AND p.created_at >= '2018-10-01'
),
     post_camp AS (
         SELECT  o.parent_vertical
                ,DATE_DIFF(cast(charge_date AS date), cast(p.created_at AS date), DAY) AS days_diff
         FROM gc_paysvc_live.payments p
                  LEFT JOIN gc_paysvc_live.mandates m
                            on p.mandate_id = m.id
                  JOIN gc_paysvc_live.organisations o ON
             m.organisation_id = o.id
         WHERE p.created_at >= '2018-12-01'
           AND p.created_at <= '2019-02-01'
     )

SELECT  pc.parent_vertical                              AS parent_vertical
       ,CONCAT(ROUND(avg(pc.days_diff), 1),' days')     AS before
       ,CONCAT(ROUND(avg(poc.days_diff), 1), ' days')   AS after
FROM pre_camp pc
LEFT JOIN post_camp poc
ON pc.parent_vertical = poc.parent_vertical
GROUP BY 1


--On which vertical should the company focus next?
SELECT
        parent_vertical
       ,num_usages                                                                                          AS distinct_mandates
       ,ROUND(avg_amount, 2)                                                                                AS avg_amount_paid
       ,ROUND(total_amount, 2)                                                                              AS total_revenue_amount
       ,num_organizations                                                                                   AS organizations_assigned
       ,RANK() OVER (ORDER BY num_usages DESC, total_amount DESC, avg_amount DESC, num_organizations DESC)  AS rank
FROM (
         SELECT  o.parent_vertical
                ,COUNT(DISTINCT m.id)              AS num_usages
                ,AVG(p.amount)                     AS avg_amount
                ,SUM(p.amount)                     AS total_amount
                ,COUNT(DISTINCT m.organisation_id) AS num_organizations
         FROM gc_paysvc_live.organisations o
                  JOIN gc_paysvc_live.mandates m
                       ON o.id = m.organisation_id
                  JOIN gc_paysvc_live.payments p
                       ON m.id = p.mandate_id
         GROUP BY o.parent_vertical
     )
ORDER BY rank

;




