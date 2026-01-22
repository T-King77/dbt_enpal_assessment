# Exploratory Data Analysis (EDA)

This analysis investigates the structure, relationships, and business logic of the six Pipedrive CRM source tables. SQL queries were executed to validate assumptions, identify table grain, and derive rules for dbt modeling.

---

# 1. Table-Level Validation

## 1.1 stages

### Uniqueness check

```sql
select 
    count(*) as total_rows,
    count(distinct stage_id) AS distinct_stage_ids

from stages;
```

### Field inspection
```sql
select 
    stage_id, 
    stage_name

from stages
order by stage_id;
```

**Insights:**  
- Clean primary key: `stage_id` has 9 unique values.  
- Direct mapping to funnel stages (1–9) defined in assignment.

---

## 1.2 activity_types

### Uniqueness check 

```sql
select 
    count(*) AS total_rows,
    count(distinct id) as distinct_type_ids

from activity_types;
```

### Field inspection 

```sql
select 
    type, 
    name

from activity_types;
```

**Insights:**  
- Unique primary key.  
- The dataset includes multiple distinct activity types. A review of the corresponding name field indicates these represent meaningful CRM actions.
- These activity types (e.g., "meeting", "sc_2") can be mapped to specific funnel sub-steps such as Sales Call 1 and Sales Call 2, which contribute to Steps 2.1 and 3.1 of the funnel.

---

## 1.3 activity

### Uniqueness check

```sql
select
    count(*) as total_rows,
    count(distinct activity_id) AS distinct_ids,
    count(distinct deal_id) AS distinct_deals

from activity;

---
select 
    deal_id,
    activity_id 
    
from activity
group by 1,2
having count(*) > 1;
```

**Insight:**   
- `activity_id` is not globally unique and can appear across multiple deals.  
- Each `(activity_id, deal_id)` combination appears only once, indicating that activities may be reassigned between deals rather than duplicated within the same deal.

### Check "done" distribution

```sql
select 
    done, 
    count(*) 

from activity
group by done;
```

**Insight:**  
- Funnel steps 2.1 and 3.1 should use only done = true. Since the two funnel sub-steps - Sales Call 1 and Sales Call 2, depend on `activity` data, using only completed activities (`done = true`) provides an accurate reflection of actual funnel progress.

---

## 1.4 deal_changes

### Uniqueness check

```sql
select 
    count(*) as total_rows,
    count(distinct deal_id) as distinct_deals

from deal_changes;
```

**Insight:**  
- Multiple change events per deal → event-grain table.

### Change fields observed

```sql
select 
    distinct changed_field_key

from deal_changes;
```

**Insight:**  
- Key fields of interest:  
  - `add_time` (creation time)  
  - `stage_id` (funnel transitions)  

### Validate stage_id references

```sql
select 
    distinct new_value

from deal_changes
where changed_field_key = 'stage_id';
```

**Insight:**  
- All values appear in stages table — consistent dataset.

### Creation timestamp extraction feasibility

```sql
select deal_id,
    min(change_time) filter (where changed_field_key = 'add_time') as created_at

from deal_changes
group by deal_id;
```

**Insight:**  
- `add_time` exists for all deals → reliable cohorting field.

### deal stage distribution

```sql
select 
    new_value as stage_id,
    count(distinct deal_id) as deals_reached_stage

from deal_changes
where changed_field_key = 'stage_id'
group by new_value
order by stage_id;
```

**Insight:**  
- The number of deals decreases as stage_id increases, reflecting natural funnel drop-off.
- Deals that never appear for a given stage_id simply did not reach that step and therefore will not have a timestamp for it.

## 1.5 fields

### validate structure

```sql
select * from fields;
```

**Insight:**  
- Fields table contains metadata only.  
- No direct obvious role in funnel modeling except enrichment of source data like deal_changes.


### Expand and inspect JSON values
```sql
select 
    f.field_key,
    value->>'id' as option_id,
    value->>'label' as option_label

from fields f,
     json_array_elements(f.field_value_options::json) as value
where f.field_key in ('stage_id', 'lost_reason')
order by f.field_key, option_id;
```

**Insight:**
- JSON arrays expand cleanly and contain well-structured `id`/`label` pairs.
- The stage metadata includes exactly 9 stages, matching the stages table and the required funnel steps.
- Although not required for funnel KPIs, these lookups can enrich intermediate models (e.g., mapping lost_reason to its label)

---

## 1.6 users

### Uniqueness validation

```sql
select 
    count(*) as total_rows,
    count(distinct id) as distinct_ids

from users;
```

**Insight:**  
- User table contains unique IDs with no duplication.

### Check for missing emails or names

```sql
select 
    sum(case when coalesce(email,'') = '' then 1 else 0 end) as missing_emails,
    sum(case when coalesce(name,'') = '' then 1 else 0  end) as missing_names

from users;
```

**Insight:**  
- CRM users have no missing names or emails; dataset complete.

---

# 2. Relationship Validation

## 2.1 Check activity types present in data

```sql
select 
    distinct a.type

from activity a
left join activity_types t on a.type = t.type
where t.type is null;
```

**Insight:**  
- The query returns 0 rows, confirming that every activity `type` used in the `activity` table is defined in `activity_types`, indicating a consistent and complete mapping of activity categories

---

## 2.2 Validate assigned_to_user exists

```sql
select
    count(*) as missing_users

from activity a
left join users u on a.assigned_to_user = u.id
where u.id is null;
```

**Insight:**  
- Missing users would indicate incomplete CRM extraction.  
- Dataset is complete as no missing users.

## 2.3 Activity-to-deal linkage validation
```sql
select 
    count(*) as missing_deal_links

from activity a

left join deal_changes dc on a.deal_id = dc.deal_id
where dc.deal_id is null;
```

**Finding:**  
The query returns **4,000+ rows**, indicating that a significant number of activity records reference deal_ids that do not exist in the deal_changes table.

### Focus on sales call activities
```sql
select 
    count(distinct a.deal_id) as activity_deals,
    count(distinct dc.deal_id) as deals_also_in_changes,
    count(distinct case when dc.deal_id is null then a.deal_id end) as unmatched_deals

from activity a
left join deal_changes dc on a.deal_id = dc.deal_id
where a.done = true
  and a.activity_type_code in ('meeting', 'sc_2');
```

**Insight:**
- Of 1,128 deals with completed sales call activities, only 2 (0.2%) exist in deal_changes
- 1,126 deals (99.8%) are unmatched
- This represents a near-complete disconnect between activity logging and deal tracking systems

### Date range comparison
```sql
select 
    'deal_changes' as source,
    min(change_time) as earliest_date,
    max(change_time) as latest_date

from deal_changes

union all

select 
    'activity (meeting/sc_2)' as source,
    min(due_to) as earliest_date,
    max(due_to) as latest_date
from activity

where done = true
  and type in ('meeting', 'sc_2');
```

**Insight:**
- deal_changes: Jan 2024 - Mar 2025 (15 months)
- activity data: Jan 2024 - Sept 2024 (9 months)
- Both datasets cover the same deal creation period (Jan-Sept 2024)
- Activity-deal disconnect is not due to temporal mismatch

### Deal creation timeline
```sql
select 
    date_trunc('month', change_time) as creation_month,
    count(distinct deal_id) as deals_created

from deal_changes
where changed_field_key = 'add_time'
group by creation_month
order by creation_month;
```

**Insight:**
- All 1,995 deals were created between January and September 2024
- No new deals created after September 2024
- Peak in May 2024 (262 deals), lowest in September (91 deals)

### Deal lifecycle beyond creation period
```sql
select 
    date_trunc('month', change_time) as change_month,
    count(distinct deal_id) as deals_with_changes

from deal_changes
where change_time > '2024-09-30'
group by change_month
order by change_month;
```

**Insight:**
- Deals continued to have stage transitions through March 2025
- Peak change activity in October 2024 (650 deals)
- Demonstrates that deals created Jan-Sept 2024 continued progressing through the funnel

**Conclusion:**

The 1,126 unmatched activities were logged during the same period as deal creation (Jan-Sept 2024), suggesting either:
1. Deals were deleted from Pipedrive after activity logging
2. Incomplete data extraction where deals exist in the activity system but not in deal_changes
3. Activities logged for "leads" that never progressed to formal "deals"

---

# 3. Key Insights Relevant to Funnel Modeling

- Stages map exactly to 9 funnel steps → direct alignment.  
- Stage transitions from deal_changes determine entry timestamp for each funnel step.  
- Activity types for Sales Calls 1 and 2 come exclusively from activity table.  
- Funnel modeling requires *first occurrence per step* per deal.  
- Deals may not reach all steps; those steps will simply have no timestamp.  
- Monthly funnel = group deals by creation month then count reached steps.

---

# 4. Data Quality Observations

- No missing stage references.  
- **Significant activity-deal disconnect:** 99.8% of completed sales call activities (1,126 of 1,128) reference deals not present in deal_changes, resulting in only 2 usable activity records for funnel analysis.
- No undefined activity types.  
- Activities include both completed and uncompleted events; only completed activities (`done = true`) are considered for funnel milestones. 
- Some deals stagnate in early stages → expected CRM behavior.
- **Data coverage limitation:** Activity data stops at September 2024 while deal_changes continues through March 2025. Both datasets cover the same deal creation period (Jan-Sept 2024), indicating the disconnect is due to missing deal references rather than a timing mismatch.

---

# 5. Four-Layer Architecture Design

This project implements a **four-layer dbt architecture** prioritizing reusable business entities over report-specific transformations. While the immediate deliverable is a monthly sales funnel report, the data layers are designed to serve unlimited future analytical needs.

## 5.1 Staging Layer
Source-aligned models providing clean, standardized foundation (1:1 with sources).

- **stg_deal_changes** - Event-level deal change history with clean timestamps
- **stg_activity** - Standardized activity records with type normalization
- **stg_fields** - Field metadata with JSON value options for lookups
- **stg_stages** - Stage reference data with ordering
- **stg_activity_types** - Activity type reference with business names
- **stg_users** - User attributes for deal ownership

**Purpose:** Minimal transformation, data type standardization, naming conventions

---

## 5.2 Intermediate Layer
Business logic transformations preparing data for entity models.

- **int_deal_stage_reached**
  - Pivots stage transitions to wide format (9 columns: `stage_1_reached_at` through `stage_9_reached_at`)
  - One row per deal with earliest timestamp for each stage reached
  - Enables efficient downstream aggregation

- **int_deal_activity_summary**
  - Aggregates activity patterns per deal across ALL activity types
  - Captures first completed timestamps for Sales Call milestones
  - Includes activity volume metrics (counts by type)
  - Filters to deals with valid stage data (addresses activity-deal disconnect documented in Section 2.3)

**Purpose:** Apply transformations while maintaining granular grain for flexibility

---

## 5.3 Curated Layer ⭐ (Reusable Business Entities)
**This is the foundation layer designed for maximum reusability.**

- **deals**
  - **Grain:** One row per deal
  - **Content:** Complete deal lifecycle with all stage milestones, creation timestamps at multiple grains (day/week/month), outcome metadata (lost reasons when available), and derived metrics
  - **Enables:** Funnel analysis at any time grain, win/loss analysis, sales cycle metrics, conversion rates, forecasting, cohort analysis

- **deal_activities**
  - **Grain:** One row per deal
  - **Content:** Activity engagement patterns with counts and timestamps for ALL activity types, not just sales calls
  - **Enables:** Activity effectiveness analysis, engagement metrics, multi-touch attribution, activity-to-conversion correlation

**Why This Layer Matters:**
- Supports different aggregation levels (daily, weekly, monthly, quarterly)
- Enables different dimensional cuts (rep, product, region, segment)
- Powers different analysis types (funnel, win/loss, velocity, forecasting)
- Serves different consumers (dashboards, ad-hoc queries, ML models)

---

## 5.4 Marts Layer (Reporting Aggregations)
Pre-aggregated models optimized for specific business questions.

- **mart_sales_funnel_monthly**
  - **Grain:** month × funnel_step
  - **Columns:** month, kpi_name, funnel_step, deals_count
  - **Content:** Monthly funnel progression across all 11 steps (9 stages + 2 activity sub-steps)
  - **Source:** Aggregates from `deal` and `deal_activities` curated models
  - **Purpose:** Required deliverable demonstrating ONE use case of the curated layer

**Future Marts (Examples of What's Possible):**
- `mart_sales_funnel_weekly` - Same funnel logic, weekly grain
- `mart_win_loss_by_reason` - Lost reason analysis by cohort
- `mart_sales_cycle_velocity` - Time-in-stage and conversion metrics

**Design Philosophy:** The curated layer is the investment; marts are specific applications built from that foundation.

---

# 6. Architecture Benefits

The four-layer structure separates concerns:

1. **Staging** - Source truth and data quality
2. **Intermediate** - Reusable transformations
3. **Curated** - Business entities (THE FOUNDATION)
4. **Marts** - Use-case specific aggregations

This enables:
- New reports built quickly from curated layer (no need to rewrite transformations)
- Consistent business logic across all analyses
- Flexibility to aggregate at different grains without rebuilding base logic
- Clear separation between "how we transform data" and "what the business needs"
