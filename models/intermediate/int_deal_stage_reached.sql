/*
    Model: int_deal_stage_reached
    
    Purpose:
        Pivots deal stage transitions into wide format with one timestamp column
        per stage. Captures the earliest timestamp each deal reached each of the
        9 pipeline stages.
    
    Grain: One row per deal
    
    Business Logic:
        - Extracts stage_id change events from deal_changes
        - Pivots to wide format with stage_1_reached_at through stage_9_reached_at
        - Uses MIN to capture first entry into each stage
        - NULL indicates stage not reached
*/

with stage_changes as (

    select
        deal_id,
        new_value as stage_id,
        change_time as stage_reached_at

    from {{ ref('stg_deal_changes') }}
    
    where changed_field_key = 'stage_id'

),

pivoted as (

    select
        deal_id,
        
        min(case when stage_id = '1' then stage_reached_at end) as stage_1_reached_at,
        min(case when stage_id = '2' then stage_reached_at end) as stage_2_reached_at,
        min(case when stage_id = '3' then stage_reached_at end) as stage_3_reached_at,
        min(case when stage_id = '4' then stage_reached_at end) as stage_4_reached_at,
        min(case when stage_id = '5' then stage_reached_at end) as stage_5_reached_at,
        min(case when stage_id = '6' then stage_reached_at end) as stage_6_reached_at,
        min(case when stage_id = '7' then stage_reached_at end) as stage_7_reached_at,
        min(case when stage_id = '8' then stage_reached_at end) as stage_8_reached_at,
        min(case when stage_id = '9' then stage_reached_at end) as stage_9_reached_at

    from stage_changes
    
    group by deal_id

),

final as (

    select * from pivoted

)

select * from final
