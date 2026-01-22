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

Stage-based steps are derived from deal stage transitions.
Sales call sub-steps are derived from completed CRM activities.

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
