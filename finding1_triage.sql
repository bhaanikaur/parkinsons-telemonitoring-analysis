-- ============================================================
-- FINDING 1: Patient triage-alert logic
-- ------------------------------------------------------------
-- Product question: In a remote-monitoring product where clinicians
-- cannot watch every patient continuously, which patients are
-- deteriorating fast enough to warrant proactive outreach before
-- their next scheduled visit?
--
-- Approach: Compute each patient's progression velocity (rate of
-- total UPDRS change per day over their ~6 months in the trial),
-- then flag anyone progressing faster than the cohort average.
--
-- Techniques: window functions (FIRST_VALUE / LAST_VALUE with a
-- full-partition frame), CTEs, CASE-based decision logic.
-- ============================================================

WITH patient_span AS (
  -- Grab each patient's first and last UPDRS score and their
  -- first and last recording day. The full-partition frame
  -- (UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) is required so
  -- LAST_VALUE sees the patient's final recording, not just up to
  -- the current row.
  SELECT DISTINCT
    "subject#" AS subject,
    FIRST_VALUE(CAST(total_UPDRS AS REAL)) OVER w AS start_updrs,
    LAST_VALUE(CAST(total_UPDRS AS REAL))  OVER w AS end_updrs,
    MIN(CAST(test_time AS REAL)) OVER w     AS first_day,
    MAX(CAST(test_time AS REAL)) OVER w     AS last_day
  FROM parkinsons_updrs_recordings
  WINDOW w AS (
    PARTITION BY "subject#"
    ORDER BY CAST(test_time AS REAL)
    ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
  )
),
velocity AS (
  -- Convert start/end scores into a per-day rate of change.
  SELECT
    subject,
    start_updrs,
    end_updrs,
    (end_updrs - start_updrs) / (last_day - first_day) AS updrs_per_day
  FROM patient_span
)
-- Compare each patient to the cohort average and assign a triage flag.
SELECT
  subject,
  ROUND(start_updrs, 2) AS start_updrs,
  ROUND(end_updrs, 2)   AS end_updrs,
  ROUND(updrs_per_day, 4) AS updrs_per_day,
  ROUND((SELECT AVG(updrs_per_day) FROM velocity), 4) AS cohort_avg,
  CASE
    WHEN updrs_per_day > (SELECT AVG(updrs_per_day) FROM velocity)
    THEN 'FLAG: proactive outreach'
    ELSE 'routine monitoring'
  END AS triage_status
FROM velocity
ORDER BY updrs_per_day DESC;
