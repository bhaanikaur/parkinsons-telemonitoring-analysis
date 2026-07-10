-- ============================================================
-- FINDING 2: Voice-measure feature viability
-- ------------------------------------------------------------
-- Product question: Should the product ship a feature that estimates
-- a patient's disease severity from a voice sample? Is any voice
-- measure a strong enough signal to build on?
--
-- Approach: Compute the Pearson correlation between each voice
-- measure and total UPDRS severity, then rank by strength. SQLite
-- has no built-in correlation function, so it is computed by hand
-- from component sums.
--
-- Result: every measure correlates only weakly with severity
-- (strongest is HNR at -0.16). Recommendation: do not ship voice as
-- a standalone severity signal.
--
-- Note: the 5 jitter measures are near-duplicates of each other, as
-- are the 5 shimmer measures, so one representative from each family
-- is reported rather than all 16 columns.
--
-- Techniques: hand-computed Pearson correlation in pure SQL,
-- UNION ALL stacking, wrap-and-sort pattern.
-- ============================================================

WITH parts AS (
  -- Component sums needed for Pearson's r, computed once for every
  -- voice measure against total_UPDRS (y).
  SELECT
    COUNT(*) AS n,
    SUM(CAST(total_UPDRS AS REAL)) AS sum_y,
    SUM(CAST(total_UPDRS AS REAL) * CAST(total_UPDRS AS REAL)) AS sum_yy,

    SUM(CAST("Jitter(%)" AS REAL)) AS sx_jit_pct,
    SUM(CAST("Jitter(%)" AS REAL) * CAST("Jitter(%)" AS REAL)) AS sxx_jit_pct,
    SUM(CAST("Jitter(%)" AS REAL) * CAST(total_UPDRS AS REAL)) AS sxy_jit_pct,

    SUM(CAST("Shimmer" AS REAL)) AS sx_shim,
    SUM(CAST("Shimmer" AS REAL) * CAST("Shimmer" AS REAL)) AS sxx_shim,
    SUM(CAST("Shimmer" AS REAL) * CAST(total_UPDRS AS REAL)) AS sxy_shim,

    SUM(CAST("NHR" AS REAL)) AS sx_nhr,
    SUM(CAST("NHR" AS REAL) * CAST("NHR" AS REAL)) AS sxx_nhr,
    SUM(CAST("NHR" AS REAL) * CAST(total_UPDRS AS REAL)) AS sxy_nhr,

    SUM(CAST("HNR" AS REAL)) AS sx_hnr,
    SUM(CAST("HNR" AS REAL) * CAST("HNR" AS REAL)) AS sxx_hnr,
    SUM(CAST("HNR" AS REAL) * CAST(total_UPDRS AS REAL)) AS sxy_hnr,

    SUM(CAST("RPDE" AS REAL)) AS sx_rpde,
    SUM(CAST("RPDE" AS REAL) * CAST("RPDE" AS REAL)) AS sxx_rpde,
    SUM(CAST("RPDE" AS REAL) * CAST(total_UPDRS AS REAL)) AS sxy_rpde,

    SUM(CAST("DFA" AS REAL)) AS sx_dfa,
    SUM(CAST("DFA" AS REAL) * CAST("DFA" AS REAL)) AS sxx_dfa,
    SUM(CAST("DFA" AS REAL) * CAST(total_UPDRS AS REAL)) AS sxy_dfa,

    SUM(CAST("PPE" AS REAL)) AS sx_ppe,
    SUM(CAST("PPE" AS REAL) * CAST("PPE" AS REAL)) AS sxx_ppe,
    SUM(CAST("PPE" AS REAL) * CAST(total_UPDRS AS REAL)) AS sxy_ppe
  FROM parkinsons_updrs_recordings
),
correlations AS (
  -- Pearson's r for each measure:
  --   r = (n*Sxy - Sx*Sy) / ( sqrt(n*Sxx - Sx^2) * sqrt(n*Syy - Sy^2) )
  SELECT 'Jitter(%)' AS voice_measure,
    ROUND((n*sxy_jit_pct - sx_jit_pct*sum_y) /
      (SQRT(n*sxx_jit_pct - sx_jit_pct*sx_jit_pct) * SQRT(n*sum_yy - sum_y*sum_y)), 4) AS correlation FROM parts
  UNION ALL
  SELECT 'Shimmer',
    ROUND((n*sxy_shim - sx_shim*sum_y) /
      (SQRT(n*sxx_shim - sx_shim*sx_shim) * SQRT(n*sum_yy - sum_y*sum_y)), 4) FROM parts
  UNION ALL
  SELECT 'NHR',
    ROUND((n*sxy_nhr - sx_nhr*sum_y) /
      (SQRT(n*sxx_nhr - sx_nhr*sx_nhr) * SQRT(n*sum_yy - sum_y*sum_y)), 4) FROM parts
  UNION ALL
  SELECT 'HNR',
    ROUND((n*sxy_hnr - sx_hnr*sum_y) /
      (SQRT(n*sxx_hnr - sx_hnr*sx_hnr) * SQRT(n*sum_yy - sum_y*sum_y)), 4) FROM parts
  UNION ALL
  SELECT 'RPDE',
    ROUND((n*sxy_rpde - sx_rpde*sum_y) /
      (SQRT(n*sxx_rpde - sx_rpde*sx_rpde) * SQRT(n*sum_yy - sum_y*sum_y)), 4) FROM parts
  UNION ALL
  SELECT 'DFA',
    ROUND((n*sxy_dfa - sx_dfa*sum_y) /
      (SQRT(n*sxx_dfa - sx_dfa*sx_dfa) * SQRT(n*sum_yy - sum_y*sum_y)), 4) FROM parts
  UNION ALL
  SELECT 'PPE',
    ROUND((n*sxy_ppe - sx_ppe*sum_y) /
      (SQRT(n*sxx_ppe - sx_ppe*sx_ppe) * SQRT(n*sum_yy - sum_y*sum_y)), 4) FROM parts
)
-- Wrap-and-sort: the UNION result is materialized as a CTE so
-- ORDER BY can reference the correlation column reliably.
SELECT voice_measure, correlation
FROM correlations
ORDER BY ABS(correlation) DESC;
