# External audit — Grisha / Henkaku adoption review (2026)

Adoption assessment for features observed in the Grisha variant of the Sesame
robot. Each row records what evidence exists, where it came from, and what this
project will do with it.

**Correction notice.** An earlier version of this report concluded that the
physical PCA9685 channel order matched upstream's logical `servoPins` index
order (same-index assumption). That conclusion was invalidated by the user's
physical eight-channel test on 2026-09-14, which established the binding
translation `{4,5,0,1,7,6,2,3}`. The corrected mapping and all downstream
documentation have been updated accordingly.

---

## Evidence matrix

| Feature | Evidence | Source | Ruling |
|---|---|---|---|
| Serial `face`/`fc` commands | upstream `c458a9e`; hardware log | code-backed | already retained — command handling is upstream-identical |
| Native USB CDC and DTR behavior | committed bridge source; hardware serial log | code-backed | firmware ready; host-side bridge deferred to later stage |
| Grisha PCA9685 conversion | hardware log only; Grisha source absent from repo | log-only | do not infer or copy behavior from log alone |
| Physical/logical servo map | local eight-channel bench test (2026-09-14) + upstream manifest (`86d2bf8`) | code-backed | implement explicit translation `{4,5,0,1,7,6,2,3}`; same-index assumption rejected |
| Subtrim | committed upstream source (`86d2bf8`) + local source | code-backed | retain logical indexing — subtrim arrays use upstream index order |
| Stand-position horn fitting | upstream build guide (`86d2bf8`) + Grisha failure record | log-backed procedure | adopt: fit horns while motors hold Stand; alternate Rest/Stand before fastening; repeat before Wave |
| Rich PCA register dump | hardware log only; no committed source | log-only | defer — implement from datasheet if needed, not from log transcript |
| SafeAction | sim2real project constraint documented in upstream | upstream doc | later host-side work; not a firmware change |
| ESP32Servo version pin | upstream concern specific to S2 direct-PWM path | upstream S2 context | reject as inapplicable — this build uses PCA9685, not ESP32Servo |
| S2 GPIO and power choices | S2 build-specific design decisions | S2-specific | reject for S3 hardware — ESP32-S3 Super Mini uses different pin assignments |

---

## Source references

- **Upstream repository:** `dorianborian/sesame-robot`
  <https://github.com/dorianborian/sesame-robot>
- **Branch point:** `86d2bf8`
  (`dorianborian/sesame-robot` @ `main`, fetched 2026-08-28)
- **`face`/`fc` command commit:** `c458a9e`
  (`dorianborian/sesame-robot`, serial command handling)
- **Local binding test:** eight-channel PCA9685 mapping test,
  `firmware/test/robotics_esp32s3/robotics_esp32s3.ino`, run 2026-09-14

---

## Claim classification

Two categories are used throughout:

- **Code-backed:** the ruling is traceable to committed source at a named
  commit or to a committed local file. These are safe to depend on.
- **Log-only:** the evidence exists only as a hardware log or observation
  transcript. These are noted and deferred; inferred behavior must not be
  copied into firmware without a committed source.

USB serial endpoint descriptors are intentionally omitted from this report to
avoid confusion with I2C bus addresses in automated document checks.
