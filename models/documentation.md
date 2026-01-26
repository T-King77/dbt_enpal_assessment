# Project Documentation

## Business Context

This project models CRM data from Pipedrive using a **four-layer dbt architecture** designed for maximum reusability. While the immediate deliverable is a monthly sales funnel report, the data layers are structured to serve unlimited future analytical needs beyond this single use case.

---

## Funnel Overview

The sales funnel consists of the following steps:

1. Lead Generation  
2. Qualified Lead  
2.1 Sales Call 1  
3. Needs Assessment  
3.1 Sales Call 2  
4. Proposal / Quote Preparation  
5. Negotiation  
6. Closing  
7. Implementation / Onboarding  
8. Follow-up / Customer Success  
9. Renewal / Expansion  

Stage-based steps (1-9) are derived from deal stage transitions.
Activity-based sub-steps (2.1, 3.1) are included but return zero counts due to data quality issues (see EDA for details).

---

## Modeling Layers

### Staging
The staging layer cleans and standardizes raw source data.
Models are 1:1 with source tables and contain no business logic.
Provides the foundation for all downstream transformations.

### Intermediate
The intermediate layer applies business logic transformations
while maintaining granular grain. Prepares data for curated
entity models through pivoting, filtering, and aggregation.

### Curated
The curated layer contains reusable business entities at deal-level grain.
This is the **foundation layer** designed to serve multiple analytical needs including:
funnel analysis at any time grain, win/loss analysis, sales cycle metrics,
conversion rates, and forecasting. Built for flexibility and reuse.

### Marts
The marts layer contains pre-aggregated, use-case-specific models
optimized for reporting and BI consumption. Each mart demonstrates
one application of the curated layer's capabilities.

---

## Model Documentation

{% docs stg_deal_changes %}
Event-level staging model capturing all deal-related change events from Pipedrive.
The model preserves the original event grain while standardizing column names
and data types for downstream transformations.
{% enddocs %}

{% docs stg_stages %}
Staging model containing deal stage reference data from Pipedrive.
Each row represents a single funnel stage and provides a stable
mapping between stage identifiers and human-readable stage names.
{% enddocs %}

{% docs stg_activity_types %}
Staging model containing activity type reference data from Pipedrive.
Each row represents a distinct CRM activity type and provides a mapping
between internal type codes and activity names.
{% enddocs %}

{% docs stg_activity %}
Staging model containing CRM activity records from Pipedrive.
Each row represents an activity record linked to a deal and optionally
assigned to a user. The model standardizes column names and data types
without applying business logic.
{% enddocs %}

{% docs stg_users %}
Staging model containing CRM user records from Pipedrive.
Each row represents a single user and provides stable identifiers
for joining activities and deal ownership in downstream models.
{% enddocs %}

{% docs stg_fields %}
Staging model containing CRM field metadata from Pipedrive.
Each row represents a field definition with JSON-encoded value options
for dropdown fields. Enables enrichment of deal outcomes such as
lost_reason labels in downstream models.
{% enddocs %}

{% docs int_deal_milestones %}
Captures deal lifecycle milestones including stage progression, creation
timestamp, and outcome metadata. Pivots stage transitions to wide format
with one timestamp column per stage (9 total), extracts deal creation time
from add_time events, and captures latest lost_reason if deal was lost.
One row per deal with all temporal milestones and outcomes.
{% enddocs %}

{% docs deals %}
Complete deal entity combining stage progression, creation metadata, and outcome
information. Serves as the foundational business entity for all deal-related
analysis. One row per deal with all stage milestones, creation timestamps at
multiple grains (day, week, month, quarter), and derived metrics. Enables
funnel analysis at any time grain, win/loss analysis, sales cycle metrics,
conversion rates, forecasting, and cohort analysis. This is the primary
reusable entity designed to serve unlimited future analytical needs.
{% enddocs %}

{% docs rep_sales_funnel_monthly %}
Monthly sales funnel report showing deal progression through 9 stage-based steps.
Aggregates deals by creation month cohort and counts how many reached each funnel
milestone. Uses a date spine to ensure all month × step combinations exist, preventing
gaps in time-series visualizations. Activity-based sub-steps (2.1, 3.1) excluded due
to documented data quality issues.
{% enddocs %}

---

## Column Documentation

{% docs deal_id %}
Unique identifier of the deal associated with the change event.
{% enddocs %}

{% docs change_time %}
Timestamp indicating when the change event occurred.
{% enddocs %}

{% docs changed_field_key %}
Name of the deal field that was changed (e.g. stage_id, add_time, user_id).
{% enddocs %}

{% docs new_value %}
New value assigned to the changed field.
{% enddocs %}

{% docs stage_id %}
Unique identifier of the deal stage.
Used to map deal stage transitions to funnel steps.
{% enddocs %}

{% docs stage_name %}
Name of the deal stage as defined in Pipedrive.
{% enddocs %}

{% docs activity_type_id %}
Unique identifier of the activity type.
{% enddocs %}

{% docs activity_type_code %}
Activity type code indicating the kind of CRM action performed
(e.g. meeting, sc_2).
{% enddocs %}

{% docs activity_type_name %}
Human-readable name describing the activity type.
{% enddocs %}

{% docs is_active %}
Indicates whether the activity type is currently active in Pipedrive.
{% enddocs %}

{% docs activity_id %}
Identifier of the activity in the source system.
An activity may appear in multiple records as its attributes change over time.
{% enddocs %}

{% docs field_id %}
Unique identifier of the field definition in Pipedrive.
{% enddocs %}

{% docs field_key %}
Unique key identifier of the field (e.g., 'stage_id', 'lost_reason').
{% enddocs %}

{% docs field_name %}
Human-readable name of the field as defined in Pipedrive.
{% enddocs %}

{% docs field_value_options %}
JSON array containing valid field values with id/label pairs.
Used for decoding enum field values to business-friendly labels.
{% enddocs %}

{% docs assigned_to_user_id %}
Identifier of the user assigned to the activity.
{% enddocs %}

{% docs is_done %}
Indicates whether the activity was completed.
{% enddocs %}

{% docs due_at %}
Timestamp indicating when the activity was scheduled or due.
{% enddocs %}

{% docs user_id %}
Unique identifier of the user in the source CRM system.
{% enddocs %}

{% docs user_name %}
Full name of the user as stored in Pipedrive.
{% enddocs %}

{% docs user_email %}
Email address associated with the user account.
{% enddocs %}

{% docs modified_at %}
Timestamp indicating when the user account was modified.
{% enddocs %}

{% docs stage_reached_at %}
Timestamp indicating when the deal first entered this stage.
NULL if the deal never reached this stage.
{% enddocs %}

{% docs created_at %}
Timestamp when the deal was first created in Pipedrive.
Derived from the earliest 'add_time' event in deal_changes.
{% enddocs %}

{% docs creation_date %}
Date when the deal was created, truncated to day grain.
Used for daily cohort analysis and aggregations.
{% enddocs %}

{% docs creation_week %}
First day of the week when the deal was created.
Used for weekly cohort analysis and aggregations.
{% enddocs %}

{% docs creation_month %}
First day of the month when the deal was created.
Used for monthly cohort analysis and grouping in funnel reports.
{% enddocs %}

{% docs creation_quarter %}
First day of the quarter when the deal was created.
Used for quarterly cohort analysis and aggregations.
{% enddocs %}

{% docs is_won %}
Boolean flag indicating whether the deal reached the final stage (Renewal/Expansion).
True if stage_9_reached_at is not null, false otherwise.
{% enddocs %}

{% docs lost_reason_id %}
ID of the reason why the deal was lost, if applicable.
References the lost_reason field value options in the fields table.
Null if the deal was not lost.
{% enddocs %}

{% docs lost_reason %}
Human-readable label explaining why the deal was lost.
Decoded from the fields metadata using lost_reason_id.
Null if the deal was not lost.
{% enddocs %}

{% docs is_lost %}
Boolean flag indicating whether the deal has a lost reason recorded.
True if lost_reason_id is not null, false otherwise.
Useful for filtering to closed-lost deals in win/loss analysis.
{% enddocs %}

{% docs sales_cycle_duration %}
Time interval between deal creation and reaching the final stage.
Null if the deal has not reached stage 9. Useful for velocity analysis.
{% enddocs %}

{% docs month %}
First day of the month when deals were created. Used for cohort analysis.
{% enddocs %}

{% docs kpi_name %}
Human-readable funnel step name (e.g., "Lead Generation", "Qualified Lead").
{% enddocs %}

{% docs funnel_step %}
Numeric funnel step identifier (1-9). Corresponds to pipeline stages.
{% enddocs %}

{% docs deals_count %}
Number of deals from this creation month cohort that reached this funnel step.
Includes zero counts to ensure complete time-series data.
{% enddocs %}
