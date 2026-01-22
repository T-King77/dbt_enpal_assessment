/*
    Model: int_deal_activity_summary
    
    Purpose:
        Aggregates activity engagement patterns per deal across ALL activity types.
        Captures first completed timestamps for Sales Call milestones and provides
        activity volume metrics for engagement analysis.
    
    Grain: One row per deal
    
    Business Logic:
        - Filters to completed activities only (is_done = true)
        - Captures first completed timestamp for each activity type
        - Includes activity counts by type for engagement metrics
        - Filters to deals that exist in deal_changes (addresses 99.8% disconnect)
*/

with activities as (

    select
        deal_id,
        activity_type_code,
        due_at

    from {{ ref('stg_activity') }}
    
    where is_done = true

),

valid_deals as (

    select 
        distinct deal_id

    from {{ ref('stg_deal_changes') }}

),

activities_valid as (
    -- Only include deals that exist in deal_changes
    -- This filters out activities for deleted or missing deals
    select activities.* from activities
    
    inner join valid_deals on activities.deal_id = valid_deals.deal_id

),

activity_summary as (

    select
        deal_id,
        
        -- Sales Call milestones (for funnel sub-steps)
        min(case when activity_type_code = 'meeting' then due_at end) as sales_call_1_completed_at,
        min(case when activity_type_code = 'sc_2' then due_at end) as sales_call_2_completed_at,
        
        -- Activity volume metrics (for future engagement analysis)
        count(case when activity_type_code = 'meeting' then 1 end) as meeting_count,
        count(case when activity_type_code = 'sc_2' then 1 end) as sc_2_count,
        count(case when activity_type_code = 'call' then 1 end) as call_count,
        count(case when activity_type_code = 'email' then 1 end) as email_count,
        
        -- Total engagement
        count(*) as total_completed_activities,
        min(due_at) as first_activity_completed_at,
        max(due_at) as last_activity_completed_at

    from activities_valid
    
    group by deal_id

),

final as (

    select * from activity_summary

)

select * from final
