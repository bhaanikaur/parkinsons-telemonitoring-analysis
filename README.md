# Parkinson's Telemonitoring: A Product Analysis

**A PM-oriented SQL analysis of remote patient monitoring data.** I approached the UCI Parkinson's Telemonitoring dataset the way a product manager on a healthtech team would: starting from two real product decisions a remote-monitoring team would face, and using SQL to inform them.

The dataset contains 5,875 voice recordings from 42 early-stage Parkinson's patients, collected over roughly six months of at-home telemonitoring (developed by the University of Oxford, Intel, and 10 US medical centers). Each recording pairs 16 biomedical voice measures with a clinician-assessed severity score (UPDRS). [Source: UCI Machine Learning Repository](https://archive.ics.uci.edu/dataset/189/parkinsons+telemonitoring).

---

## The two product questions are as follows:

**1. Patient triage:** In a remote-monitoring product where clinicians can't watch every patient continuously, which patients are deteriorating fast enough to warrant proactive outreach before their next scheduled visit?

**2. Feature viability:** Should the product ship a feature that estimates a patient's disease severity from a voice sample? Is voice a trustworthy enough signal to build on?

---

## Finding 1: A triage-alert layer that flags the fastest-declining patients

I computed each patient's **progression velocity**. This is the rate their total UPDRS severity score changes per day across their six months in the trial. I then compared each patient against the cohort to produce a triage flag.

**Result:** 22 of 42 patients were flagged for proactive outreach (velocity above the cohort average of 0.0192 UPDRS points/day). The cohort spans real clinical variation, from the fastest progressor (subject 37, climbing 0.093 points/day, nearly 5x the cohort average) to patients holding steady or improving over the period.

| subject | start_updrs | end_updrs | updrs_per_day | triage_status |
|---|---|---|---|---|
| 37 | 32.87 | 48.53 | 0.0932 | FLAG: proactive outreach |
| 3 | 25.73 | 39.95 | 0.0883 | FLAG: proactive outreach |
| 14 | 10.65 | 25.42 | 0.0879 | FLAG: proactive outreach |
| ... | | | | |
| 28 | 41.58 | 25.77 | -0.0941 | routine monitoring |

*(Full output: `finding1_triage.png`)*

**Product takeaway:** This velocity metric is the logic layer behind a triage alert. Rather than a clinician manually reviewing all 42 patients, the product surfaces the ~half of the panel pulling away from the norm, turning limited clinical attention toward the patients who need it most.

### Validating the method

Progression velocity here is measured first-vs-last (comparing each patient's earliest and latest recording). I chose this method becyase it is simple and readable, but it is also sensitive to noise at the endpoints, meaning a single unusual recording could distort a patient's slope. So before building on it, I tested it to check for accuracy.

I computed the true least-squares **regression slope** across all ~200 recordings per patient (in pure SQL, using the covariance-over-variance formula) and compared it against the endpoint velocity.

**The two methods agree to within ~0.002 for nearly every patient, and produce an identical ranking.** The endpoint method is a valid proxy on this dataset, so I kept it for readability while documenting the more rigorous alternative.

*(Comparison output: `finding1_validation.png`)*

---

## Finding 2: Voice alone is not a shippable severity signal

I computed the Pearson correlation between each voice measure and total UPDRS severity (again in pure SQL, since SQLite has no built-in correlation function).

**Result:** Every voice measure correlates only weakly with severity. The strongest, HNR (harmonics-to-noise ratio), reaches just -0.16, meaning it explains roughly 2-3% of the variation in clinical severity.

| voice_measure | correlation |
|---|---|
| HNR | -0.1621 |
| RPDE | 0.1569 |
| PPE | 0.1562 |
| DFA | -0.1135 |
| Shimmer | 0.0921 |
| Jitter(%) | 0.0742 |
| NHR | 0.0610 |

*(Full output: `finding2_correlations.png`)*

**Product takeaway: do not ship voice as a standalone severity estimate.** No single voice measure is strong enough to drive a clinical severity readout on its own. If voice is used, it should be one input among several, or paired with the longitudinal trend rather than a point-in-time snapshot.

---

## The combined product insight

The two findings connect into one conclusion:

- **Finding 1:** A patient's *trajectory over time* is a meaningful, robust signal.
- **Finding 2:** Any *single voice snapshot* is a weak signal for severity.

Together: **a voice-telemonitoring product's value lies in the longitudinal trend, not the individual reading.** The right product bet is trend-based triage, not point-in-time severity estimation.

---

## Key notes and limitations

- **Linear association only:** Pearson correlation captures linear relationships. A voice measure could relate to severity non-linearly, which correlation would understate; that would warrant modeling beyond correlation.
- **Interpolated scores:** UPDRS values in this dataset are linearly interpolated by the original researchers, which smooths the progression signal.
- **Correlated features:** The five jitter measures are near-duplicates of one another (as are the five shimmer measures), so I reported one representative from each family rather than all 16 columns.

---

## Repo contents

- `README.md` — this analysis
- `finding1_triage.sql` — progression-velocity triage logic
- `finding1_validation.sql` — endpoint vs. regression-slope comparison
- `finding2_voice_correlation.sql` — voice-measure correlation ranking
- `results/` — query output screenshots

**Tools:** SQLite (DB Browser for SQLite). **Techniques:** window functions, CTEs, hand-computed regression slope and Pearson correlation.
