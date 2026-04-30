# 근본 원인 리포트: ODSB-17593 — KB증권 (kr.kbsec.iplustar) iOS 인스톨 지속 하락 · **v2**

> 🌐 **언어:** 한국어 (현 문서) · [English version →](./investigation_57f49cb_REPORT_v2.md)
> 📄 **HTML 버전:** [KO →](./investigation_57f49cb_REPORT_v2_ko.html) · [EN →](./investigation_57f49cb_REPORT_v2.html)

> **v2 개정 (2026-04-19):** 5-파트 내러티브 구조로 재편 (증상 → 조절 요인 → 메커니즘 → 종합 → 액션 + 부록). 크리에이티브 단위 finding을 §5a로 승격 (CDN 프리뷰 포함). NEW IPM gap-fill 쿼리 추가. TL;DR 개선.

> **⚠️ 고지사항:** 본 리포트와 데이터는 정확하지 않을 수 있습니다. 오류, 누락된 데이터, 또는 공개 적절성이 없는 민감 정보가 포함될 수 있습니다. 재현 가능한 쿼리를 포함하였으니 독립 검증 가능합니다. 외부 공유 전 반드시 확인 바랍니다.

**작성자:** Haewon Yum · KOR GDS
**일자:** 2026-04-19

**티켓:** ODSB-17593
**광고주:** KB증권 (KB Securities) / 앱 `kr.kbsec.iplustar` / iTunes 350742701
**Ad account:** `syFnKP76xSYZQcMW`
**MMP:** AIRBRIDGE (non-SKAN postback의 99.4%); SKADNETWORK 병행
**대행사:** DPLAN360 (확인 필요)
**조사 기간:** 2026-02-01 ~ 04-18
**리포트 일자:** 2026-04-19 (v2) · v1: 2026-04-17
**조사 세션:** 57f49cb (3 iterations, JUDGE_FINAL: PASS)
**Confidence:** MIXED — 대부분 인과 요인 HIGH; **3/20 07 UTC 특정 트리거에 대해서는 LOW**

---

## 티켓 요약

KB증권 iOS UA 캠페인은 지출/임프레션은 회복되었으나, MMP (AIRBRIDGE) attributed install은 2월 베이스라인의 33–50% 수준에서 정체. 영업 (dongkwon.yoo)이 client-side 에스컬레이션 주도. 본 조사는 (a) 언제 (b) 왜 (c) 다음 액션은 무엇인가에 답합니다.

---

## TL;DR — 결론 먼저

**인스톨이 돌아오지 않는 이유는 두 개의 별개 이벤트가 복합적으로 작용했기 때문이며, 그 중 하나만이 Moloco 통제 범위 내에 있습니다.** 3/20 07 UTC: 외부 postback-forwarding 장애로 KB의 *전체* AIRBRIDGE→Moloco 볼륨이 −71% 감소 (Moloco 상위 단계, KB 고유). 4/3: −50% 수동 예산 컷과 신규 nl 크리에이티브 활성화가 동시에 발생 → 포맷+크리에이티브 레짐 변화 → 블렌디드 IPM이 0.135 → 0.015/1k imp로 −89% 붕괴.

1. **4-레이어 인과 cascade (단일 원인 아님):**
   - *베이스라인 스트레서* — 3/1–10 PIM-2841 Moloco action-model 장애로 라벨 코퍼스 고갈.
   - *조절 요인* — KB 구조적 취약성: AFP=FALSE + 깊은 퍼널 KPI `account_step16_complete` (양성 tfexample 0–4/일) + 피어 대비 21× 작은 예산 + KAKAO/TPMN 65% 공급 집중.
   - *트리거* — 3/20 07 UTC 2단계 cliff (KB 단독): Phase 1 전체 pb 볼륨 **−71%** (attr/unattr 비례 drop = AIRBRIDGE-forwarding 장애, Moloco 상위 단계); Phase 2 attribution-specific 추가 열화.
   - *가속 요인* — 4/3 수동 예산 컷 + **신규 크리에이티브 `IhrxSOh9QzmyZyzv` (nl)** 동일 일자 활성화, 1일차에 KAKAO 임프레션의 60% 점유.

2. **Phase 1은 Moloco 이슈가 아님.** 동일 MMP · OS · 지역 9개 피어 (삼성증권 포함) 모두 정상. pb 테이블 레벨 볼륨 드롭은 Moloco attribution 로직보다 상위 단계. **KB 앱 측 / DPLAN360 agency / AIRBRIDGE tenant 측 조사가 최우선 다음 액션.**

3. **4/3은 복합 레짐 체인지** — 예산 컷 + 크리에이티브 교체 + 모델 응답이 동시 작용. 크리에이티브 단위 IPM (KAKAO, 4/3 이후): 신규 nl `IhrxSOh9QzmyZyzv` = 0.0121 / 기존 ib `ogMJ5cQEBJ4fNbOw` = 0.0196 (nl이 apples-to-apples 38% 열위). 그러나 기존 ib의 IPM도 동일 일자에 −82% 붕괴 → 포맷 믹스만으로 설명 불가, 동시 발생한 외부 KAKAO 오디언스/attribution 열화가 연관됨.

4. **회복은 두 축 동시 수행 필요**: (A) KB/DPLAN360 측에서 3/20 cliff 원인 규명·수정, (B) 구조적 취약성 완화 (AFP=TRUE, exchange mix 다변화, 간이 KPI). **(A) 없이 예산만 복구하면 비용 낭비** — 3/23–27 divergence로 결정적 증명: 지출 Feb 베이스라인 +90% 상회 → SoI는 베이스라인의 12% 수준 유지.

5. **배제된 가설** (code-trace + 데이터 교차 검증): nrt_resolver, MPID capper, pickByPerformance, tracking_link_auto_standardization, MM-138/PR #70212, vertical-wide AIRBRIDGE 장애.

---

## 핵심 지표

| 지표 | 값 | 해석 |
|---|---|---|
| **전체 pb 볼륨 드롭** (3/20 07 UTC) | **−71%** (381 → 111/hr) | Moloco 상위 단계, KB 단독 · Phase 1 트리거 위치 |
| **Attributed vs Unattributed 드롭** (동일 시각) | **−73% / −71%** (비례) | Upstream forwarding 장애의 signature — Moloco attribution 코드 아님 |
| **삼성증권 피어** (3/20-21) | **안정** (−13.9%, 노이즈 내) | 범위 테스트 — shock이 KB 단독, vertical/agency-wide 아님 |
| **블렌디드 KB iOS IPM** (4/3 복합) | **−89%** (0.135 → 0.015 /1k imp) | 4/3 크리에이티브+예산 shock 규모 |

---

## 근본 원인 요약 — Confidence 별 계층화

### Layer 1 — Moloco action model 기존 장애 (3/1–10) · CONFIDENCE: HIGH
- PIM-2841 인시던트: 2/26 배포 실패 → 3/5–3/8 P1 장애 → 3/10 07:53 UTC 복구. KB는 인시던트 impacted-campaigns 시트에 포함됨.
- `validation_i2i`는 `kr.kbsec.iplustar` iOS의 3/1–5 데이터 없음; KB AIRBRIDGE attribution rate = 0.06% (3/1–5, Feb 베이스라인 10.49% 대비).
- 3/14–15 short zero-episode는 PIM-2841 aftershock과 정합 (MEDIUM confidence).
- **영향:** KB action model의 Feb 라벨 코퍼스 파괴. KB의 0–4 양성 tfexample/일 조건상 회복이 구조적으로 느림.

### Layer 2 — KB 구조적 취약성 (지속 조절 요인, 트리거 아님) · CONFIDENCE: HIGH

주 피어: **삼성증권 (`com.samsungpop.ios.mpop`)** — 동일 vertical (한국 리테일 증권 / MTS), 동일 MMP (AIRBRIDGE), 동일 OS/지역, 동일 agency 클러스터 추정. "한국 증권 MMP iOS 광고주가 달성 가능한 범위"에 영향 주는 구조적 변수를 비즈니스 모델 고유 변수로부터 격리.

| 구조적 요인 | KB증권 | **삼성증권 (주 vertical 피어)** | 비고 |
|---|---|---|---|
| **AIRBRIDGE attribution rate** 3/18-22 | **10–14% → 0.74%** (−93.7%) | **5–6% flat** (−13.9%, 노이즈 내) | 삼성은 3/20-21 cliff 기간 정상 → cliff가 KB 고유임을 확증 |
| `allow_fingerprinting` (AFP) | **FALSE** (전 캠페인) | Mixed: **TRUE=8 / FALSE=4** (~67% / 33%) | 삼성의 AFP=FALSE 캠페인도 정상 → AFP 단독 차이 아님 |
| 최적화 KPI | `account_step16_complete` (deep funnel) | 미조회 [TBC] | Vertical 피어들이 규제 account-opening flow로 인해 deep-funnel KPI 공유 가능성 |
| tfexample 양성 라벨/일 | **0–4** | 미조회 [TBC] | KB 라벨 기아 상태; 삼성 미확인 |
| 일일 예산 | ~182k–363k KRW | 미조회 [TBC] | 예산 스케일 비교 보류 |
| Exchange mix | KAKAO+TPMN ≈ 65% | 미조회 [TBC] | KB의 KR-publisher 집중 관찰; 삼성 mix 미조회 |
| Supply SKAN 4.0 declared share | 98.9% | 미조회 [TBC] | Bid-request supply-framework 플래그 (traffic type 아님). 아래 caveat 참조. |
| LAT rate 궤적 (iOS, IDFA 부재) [BQ 확인, KB only] | 73.5% (2/2) → 44.9% (3/2) → 24.1% (4/6) → 20.3% (4/13 partial) — **−53 pp** | 미조회 [TBC] | KB의 IDFA availability 개선 (tailwind, 취약성 요인 아님) |

**✅ 삼성증권이 주 피어인 이유.** 동일 vertical, 동일 MMP, 동일 OS/지역, 동일 agency 클러스터 추정. "한국 증권 MMP iOS 광고주 달성 가능 범위"의 구조적 변수를 비즈니스 모델 고유 변수로부터 격리. 삼성의 3/20-21 기간 5–6% 안정 attribution이 이 cliff가 vertical-wide 또는 agency-wide 이벤트가 아님을 확증.

**⚠ 데이터 갭.** 삼성증권에 대해 직접 조회되지 않은 차원: 최적화 KPI, tfexample 양성/일, 일일 예산, exchange mix, SKAN 4.0 공급 점유율, LAT rate. "구조적 취약성" 내러티브 강화를 위해 후속 조사에서 보충 필요.

**⚠ 용어 caveat (BQ 확인).** "SKAN"은 *측정 프레임워크* (Apple의 SKAdNetwork postback 메커니즘)이지 traffic type이 아님. F8의 "98.9% SKAN 4.0"은 bid request의 `req.ext.skadn.version`에서 유래 — publisher/exchange supply-side의 SKAN framework 지원 선언으로, 유저 IDFA 상태와는 독립적. KB의 `skadn.version=4.0` 점유율은 Feb-Apr 기간 98.7-99.9% 안정 유지, 같은 기간 LAT는 73%에서 20%로 붕괴 — 두 차원이 독립적임을 확인. 올바른 traffic-type 지표는 **LAT rate / IDFA availability**. KB의 IDFA availability는 10주간 26.5% → 79.7%로 극적 개선 (tailwind) — 따라서 LAT 차원은 fragility story의 일부가 아님.

### Layer 3 — 3/20 KB 고유의 cliff · CONFIDENCE: 범위 및 구조에 대해 HIGH, Phase 1 드라이버에 대해 LOW

**본 조사의 중심 finding — 2단계 분해.**

#### Phase 1 (3/20 07 UTC) — pb 레벨 볼륨 cliff, Moloco 상위 단계
- **전체 postback 볼륨이 1시간 내에 -71% drop:** 381 → 111 pb/hr.
- **Attributed (-73%)와 Unattributed (-71%) 비례 감소.** Attribution rate는 13.5%로 안정적 유지 (14% → 13.5%).
- AIRBRIDGE가 이 구체적 시점에 KB bundle에 대해 Moloco로 보내는 postback 자체가 71% 감소 중 — 이는 `pb` 테이블의 수신 레벨이며, Moloco attribution 로직보다 *상위 단계*.
- **Moloco attribution-side 코드는 이 신호를 유발할 수 없음** — incoming 볼륨을 줄이는 것은 Moloco 속성 결정 이전에 발생해야 함.

#### Phase 2 (3/20 08 UTC부터) — 이미 감소된 볼륨 위 attribution-specific 열화
- 전체 pb는 낮지만 non-zero 유지 (26-88/hr)
- Attributed share 점진적 열화: 8.3% → 7% → 1.5% → 0%
- **3/20 16:00 UTC: 최초 완전 zero 시간.** 3/22 20:00 UTC까지 0 유지.
- 3/22 21:00+ UTC: 5-7%로 부분 회복 (rollback/fix signature 가능성).
- Phase 2 attribution rate는 볼륨과 **독립적으로** 하락 — 이미 감소된 볼륨 분모의 downstream 아티팩트일 수도, 별개로 일치하는 Moloco-side 이벤트일 수도. 이미 낮은 분모로 인해 분리 어려움.

#### 공유 근거 (양 phase 모두에 적용)
- **범위 KB-특정:** 9개 AIRBRIDGE iOS KOR 피어 (삼성증권 포함, 동일 vertical) 전 기간 안정; 최악 피어 Coinone -32% 3/23 회복; KB -93.7% = 자릿수 수준 outlier. [ADV3]
- **AFP 단독으로 차이 아님:** 삼성의 AFP=TRUE/FALSE 믹스 안정. [F9]
- **MM-138 / PR #70212 (3/20 06:11 UTC merge):** 메커니즘으로 기각. MM-138은 `attributionsvc/consumer` dedup 리팩터링; **incoming postback 볼륨을 줄일 수 없음** (Phase 1 신호). Partner-agnostic diff trace를 호출하지 않더라도, 볼륨 드롭 사실 자체가 모든 Moloco-attribution-side PR을 Phase 1 원인에서 배제. [M7, A11]

#### 시사점
Phase 1은 **전혀 Moloco 문제가 아님** — 07:00 UTC에 AIRBRIDGE가 Moloco로 71% 더 적은 postback을 보내는 중. 반드시 KB/DPLAN360/AIRBRIDGE 측에서 해결해야 함. Phase 2는 downstream; Phase 1 해결 시 자체 해소될 수도 있고, 별도 조사 필요한 별개의 Moloco-side 이슈일 수도.

### Layer 4 — 4/3 예산 컷 tipping point · CONFIDENCE: HIGH

| 이벤트 | 4/3 | 활성? |
|---|---|---|
| KB UA 일일 예산 | 363k → 181k KRW (-50%) | **YES** |
| NRT resolver ramp | 10% → 20% | NO (A10 z=0.04 p=0.97; M3 serving-only) |
| MPID capper ramp | 5% → 10% | NO (M3 bid-serving only) |

**피드백 루프:** 낙찰률 29%→14%, demand CPM –34%, 입찰 볼륨 2.8x, nl 크리에이티브 점유율 15%→59%, `cr_format × exchange` 전 셀 (ADPOPCORN 제외) within-cell IPM –70~95%. [A2, A4]

---

## Layer 4a — 4/3 신규 크리에이티브 활성화 (v2 gap-fill) · CONFIDENCE: HIGH

4/3 nl step-function은 크리에이티브 그룹 `EVX0myMHmYIGMRgQ` (크리에이티브 `IhrxSOh9QzmyZyzv` 포함)의 **완전히 새로운 활성화**로 설명되며, 기존 억제되어 있던 nl 인벤토리의 모델 reweight가 아님. KAKAO 내부 creative_id-레벨 임프레션 분해로 검증.

### 크리에이티브 메타데이터

**신규 크리에이티브 (4/3 활성화):**
- **creative_id:** `IhrxSOh9QzmyZyzv`
- **Creative group:** `EVX0myMHmYIGMRgQ` (NEW — 최초 등장 2026-04-03, 이전 footprint 제로)
- **파일:** `몰로코_B_1200X600.jpg`
- **Type:** NATIVE_IMAGE · 1200 × 600 JPEG
- **Serving 포맷:** `nl` (Native Logo) + `ni` (Native Image), 동일 에셋
- **CDN URL:** https://cdn-f.adsmoloco.com/syFnKP76xSYZQcMW/creative/mni9bepx_sqo7bc1_mvvysv3x1erkepfc.jpg

**밀려난 기존 크리에이티브:**
- **creative_id:** `ogMJ5cQEBJ4fNbOw`
- **Creative group:** `oEhJ3TVKrYHMaSWX`
- **파일:** `몰로코_B_1029x258.png`
- **Type:** IMAGE · 1029 × 258 PNG
- **포맷:** ib (image banner), 최초 등장 2/1
- **CDN URL:** https://cdn-f.adsmoloco.com/syFnKP76xSYZQcMW/creative/mmo956nt_l0sktqz_cneoggnewfdr2rja.png

### 크리에이티브 단위 KAKAO 임프레션 점유율 (2/1 – 4/18)

| creative_id | 그룹 | cr_format | 최초 등장 | KAKAO (4/3 이전) | KAKAO (4/3 이후) | Δ |
|---|---|---|---|---|---|---|
| `ogMJ5cQEBJ4fNbOw` | `oEhJ3TVKrYHMaSWX` | **ib** | 2/1 | **94.0%** | 25.4% | **−68.6 pp** |
| `IhrxSOh9QzmyZyzv` | `EVX0myMHmYIGMRgQ` 🆕 | **nl** | **4/3** | 0.0% | **59.6%** | **+59.6 pp** |
| `5d4mE9c14jMHBZlV` | `oEhJ3TVKrYHMaSWX` | ib | 2/1 | 3.2% | 6.5% | +3.3 pp |
| 기타 (15 크리에이티브) | mixed | ib/ni/ii | — | ~2.8% | ~8.5% | +5.7 pp |

### NEW — 크리에이티브 단위 IPM (KAKAO only, apples-to-apples)

| 크리에이티브 | 구간 | Imp | Clicks | Installs | IPM |
|---|---|---:|---:|---:|---:|
| `ogMJ5cQEBJ4fNbOw` (ib, 기존) | 4/3 이전 | 11,693,071 | 4,921 | 1,282 | **0.1096** |
| `ogMJ5cQEBJ4fNbOw` (ib, 기존) | 4/3 이후 | 4,529,538 | 2,131 | 89 | **0.0196** (−82%) |
| `IhrxSOh9QzmyZyzv` (nl, 신규) | 4/3 이후 | 11,385,144 | 0 | 138 | **0.0121** (ib 대비 38% 열위) |
| *블렌디드 KB iOS (전 크리에이티브 / 전 exchange)* | — | 74,190,860 | — | 10,037 | 0.1353 → **0.0145** (−89%) |

### 해석 — 두 메커니즘 복합 작용

1. **크리에이티브 품질**: 신규 nl 크리에이티브 `IhrxSOh9QzmyZyzv`는 동일한 4/3 이후 KAKAO 인벤토리 위에서 0.0121/1k, 기존 ib는 0.0196/1k — **구조적으로 38% 열위** (install 컨버전).
2. **동시 발생 외부 열화**: 기존 ib 크리에이티브의 IPM 자체가 4/3 일자에 82% 붕괴 (0.1096 → 0.0196), 계속 serving 중임에도 불구. 포맷 믹스로 설명 불가 — 다른 요인 (KAKAO 오디언스 품질 변동, 3/20 cliff부터 이어진 attribution-path 열화, 또는 저품질 인벤토리로의 예산 재배분)이 동시 타격.

**회복 시사점:** `IhrxSOh9QzmyZyzv`를 pause하면 크리에이티브 품질 gap의 ~38%가 회복되지만, 기존 ib의 82% 붕괴는 고쳐지지 않음. 3/20 attribution break가 여전히 핵심 레버.

---

## 시계열 분해 — 변동성이 신호인가, 요일 패턴인가?

Pre-3/20 window (n=48일)에 대해 가법 분해 (7일 주기)를 적용하여 일일 pb 시리즈를 trend (7일 centered MA), 주간 seasonal (요일 편차), residual (미설명 / 이벤트 기인)로 분리.

**결론:** 주간 seasonality는 non-trend variability의 **~43%**를 설명 — 의미 있지만 지배적이지 않음. 주요 이벤트 (3/3 spike, 3/20 cliff)는 분해 후에도 대형 residual로 남음.

| 성분 (pre-cliff, n=48) | Stddev | Non-trend 분산 점유 |
|---|---:|---:|
| Observed total_pb | 920 pb/일 | — |
| Trend (7일 centered MA) | 482 pb/일 | — |
| 주간 seasonal | 439 pb/일 | **42.9%** |
| Residual (irregular / 이벤트) | 507 pb/일 | **57.1%** |

**요일별 seasonal (trend 편차):** 목 +610 (peak) · 수 +432 · 화 +232 · 금 +134 · 월 −303 · 토 −527 · 일 −579 (trough). 평일/주말 gap ≈ 774 pb/일 (pre-cliff 평균 2,395의 32%).

**이벤트 레벨 residual 검증:**

| 날짜 | Observed | Trend | Seasonal (요일) | Residual | 해석 |
|---|---:|---:|---:|---:|---|
| 3/3 (화 spike) | 4,786 | 2,935 | +232 | **+1,619** | 화요일 seasonal은 trend 위 +232만 설명; 실제는 +1,619 — seasonal 효과의 7×. 실제 anomaly. |
| 3/20 (금, pre-cliff 마지막) | 3,319 | 1,960 | +134 | **+1,225** | Pre-cliff 활동이 trend 위로 elevated. |
| 3/21 (토, post-cliff) | 947 | 1,976 | −527 | **−502** | 토요일 seasonal은 trend 아래 −527 예측; 실제는 그보다 −502 residual 추가 하락. |

**3/20 → 3/21 cliff 분해:** observed drop −2,372; 금→토 seasonality 기대 −660 (drop의 28%); 미설명 residual drop −1,728 (drop의 72%). 자연스러운 주간 dip은 cliff의 ~28%만 설명 — 나머지 72%는 07 UTC upstream-forwarding 장애와 부합하는 실제 anomaly.

---

## 이벤트 타임라인

| 일시 (UTC) | 이벤트 | 출처 |
|---|---|---|
| 2/1–28 | KB AIRBRIDGE attribution 베이스라인 10.49%; 삼성증권 베이스라인 ~5-6% | A6, F1, ADV3 |
| 2/26+ | PIM-2841 Moloco action model 배포 실패 시작 | F7 |
| 3/1–5 | KB attribution이 0.06%로 붕괴 (PIM-2841 P1 장애) | A6, F7 |
| 3/5 | ad_account syFnKP76xSYZQcMW 하 신규 KB 캠페인 생성, AFP=FALSE | F8 |
| 3/6–10 | 부분 회복; PIM-2841 3/10 07:53 UTC 복구 | F7 |
| 3/2–16 | 코호트-wide IPM 부진 (28 피어), 원인 미식별 (nrt 아님) | A7, A10 |
| 3/10–11 | Platform-wide normalizer wobble: 피어 median –4%, KB –37% 지속 | A12 |
| 3/19–20 | KB attribution이 10–14% (Feb 베이스라인 근처)로 REBOUND | A6 |
| **3/20 06:11** | Moloco MM-138 / PR #70212 merge (attributionsvc dedup — incoming 볼륨 감소 불가) | M7 |
| **3/20 07:00** | **PHASE 1 — 볼륨 cliff: 전체 pb 381→111 (-71%). Attributed -73%와 Unattributed -71% 비례 DROP. Attribution rate 13.5% 유지. Moloco attribution 상위 단계.** | **A11** |
| 3/20 08-15 | **PHASE 2 — Attribution rate 독립적 열화** (8.3% → 7% → 1.5%), 이미 감소된 볼륨 위 | A11 |
| **3/20 16:00** | **최초 완전 zero attribution 시간 (0/26 pb attributed)** | **A11** |
| 3/22 21:00+ | KB 5–7% 부분 회복 | A11 |
| 3/23 | AVI-5757 rollout | F7 |
| 3/24 – 4/3 | nrt_resolver ramp 10→20→50% (배제) | B1, A10 |
| 3/26 | 코호트 일일 IPM trough, 회복 시작 | A7 |
| **4/3** | **KB 예산 363k→181k KRW + NRT 10→20% + MPID 5→10% (예산만 활성)** | A9, A10, M3 |
| **4/3** | **NEW creative `IhrxSOh9QzmyZyzv` (nl) 활성화, 1일차 KAKAO 임프레션 60% 점유** | fact_dsp_creative |
| 4/3–18 | 피드백 루프: WR 29→14%, dCPM –34%, 입찰 2.8x, nl 15→59%, IPM –70~95% | A2, A3, A4 |

---

## 핵심 Findings — 레이어별

### 트리거 레이어 (3/20 07 UTC cliff)
- **F-T1.** KB 고유: 9-피어 코호트 (삼성증권 포함) 전 기간 안정; KB만 >50% drop. [ADV3]
- **F-T2.** 시간 단위 정밀 cliff: 07:00 UTC 볼륨 -71%; 16:00 UTC attribution 0; 3/22 21:00+ 부분 회복. 2단계 signature. [A11]
- **F-T3.** AFP 단독으로 차이 아님: 삼성 AFP=TRUE/FALSE 믹스 안정. [F9]
- **F-T4.** 모든 Moloco 코드 배포 감사 (MM-138, #69335, #71341, #71921) — 기각 또는 orthogonal. [M1, M2, M4, M7, B3]

### 구조적 레이어 (지속 조절 요인)
- **F-S1.** AFP=FALSE 전 캠페인 (5대 캠페인 중) [F8]
- **F-S2.** Deep-funnel KPI: `account_step16_complete` (16단계 계좌 개설) [B2]
- **F-S3.** 양성 tfexample 0-4/일, 초저 라벨량
- **F-S4.** KAKAO+TPMN ≈ 65% 공급 집중 (KR 퍼블리셔) [F8]
- **F-S5.** LAT 73% → 20% 열화 (2/2 → 4/13) [BQ weekly]

### 가속/피드백 레이어 (4/3+ 예산 + 신규 크리에이티브)
- **F-A1.** 4/3 KB 일일 예산 수동 -50% (363k → 181k KRW) [A9]
- **F-A2.** 낙찰률 29% → 14%, demand CPM -34% [A3]
- **F-A3.** nl 포맷 iOS imp 점유율 15% → 59% [A2]
- **F-A4.** Within-cell IPM -70~95% (ADPOPCORN 제외) [A2, A4]
- **F-A5.** *NEW v2* — 4/3 신규 크리에이티브 `IhrxSOh9QzmyZyzv` 활성화, 1일차 KAKAO 60% 점유, IPM 0.0121/1k (기존 ib 대비 38% 열위)
- **F-A6.** *NEW v2* — 기존 ib `ogMJ5cQEBJ4fNbOw` 자체 IPM도 4/3 일자에 0.1096 → 0.0196 (−82%) 붕괴 — 포맷 믹스 단독으로 설명 불가

---

## 배제된 가설 (기각 근거와 함께)

| 가설 | 기각 근거 | 출처 |
|---|---|---|
| Moloco attribution-side 코드 변경 (MM-138 / PR #70212) | `attributionsvc/consumer` dedup, incoming 볼륨 감소 불가; Phase 1 볼륨 drop은 pb-level upstream | M7, A11 |
| nrt_resolver ramp | z=0.04, p=0.97; M3 code trace = serving-only, attribution 미영향 | A10, M3 |
| MPID capper ramp | M3 code trace = bid-serving only, attribution 미영향 | M3 |
| `tracking_link_auto_standardization` (PR #71921) | 기능 플래그 off, traffic 미영향 | M1 |
| `pickByPerformance` (#71341) | 서빙 로직 변경, attribution 미영향 | M2 |
| Vertical-wide AIRBRIDGE 장애 | 9개 피어 (삼성증권 포함) 전 기간 안정 | ADV3 |
| Agency-wide (DPLAN360) 장애 | 동일 agency 클러스터 피어 정상 | ADV3 |
| 단순 예산 부족 (spend-driven SoI 하락) | 3/23-27 spend +90% vs Feb 베이스라인, SoI 베이스라인의 12% 유지 — spend와 SoI decouple | A6, BQ-32d |

---

## 권고사항 — 메커니즘별 계층화

### [즉시] 클라이언트 engagement — 최우선
1. **3/20 07 UTC 볼륨 cliff를 KB/DPLAN360와 에스컬레이션 — 삼성증권 비교 데이터 포함.** Moloco 측에서 해결 불가; KB 앱 빌드 / DPLAN360 agency config / AIRBRIDGE tenant 측 변경 확인 필요. "동일 vertical 피어는 정상, 트리거는 KB 측 단독" 메시지로 에스컬레이션 우선순위화.
   - 확인 항목: AIRBRIDGE SDK 버전 변경, iOS 앱 릴리즈 노트 (3/19-20 KST), DPLAN360 tracking-link / postback URL 히스토리, AIRBRIDGE tenant agency 구성.

### [구조적] 장기 취약성 완화
2. **AFP=TRUE 전환 검토.** AFP 단독은 3/20 cliff 원인이 아니나, fingerprinting 활성화는 IDFA 부재 트래픽에서 모델 피드백 회복을 위한 matchable-signal 표면을 확장함. 클라이언트 동의 필요.
3. **KPI 간소화 (회복기 한정).** `account_step16_complete` (깊은 퍼널, 양성 라벨 0-4/일) → `install` 또는 중간 퍼널 이벤트로 전환하여 training label 재축적. 회복 후 원래 KPI로 복귀.

### [예산 / 입찰] 조건부 — MMP 해결 여부에 연동
4. **MMP pb-forwarding 해결 확인까지 예산 유지 — 확인 후 선별적 증액.**
   - **조건 (A) — 미해결 / 미확인:** 예산 flat 유지. 3/20 postback-forwarding 장애가 수정되기 전 (또는 클라이언트가 MMP 측 이슈 없음을 확인하기 전) 증액은 cash burn — 임프레션은 늘어나지만 attribution이 입찰 결정과 분리되어 있어 지출이 측정 가능한 인스톨로 환산되지 않음.
   - **조건 (B) — 해결 또는 no-issue 확인:** 통제된 증액이 크리에이티브 믹스를 *더 높은 IPM의 `ib`* 포맷으로 되돌리는 데 *도움이 될 수 있음*. 예산 압박 하에서 모델은 프리미엄 인벤토리에 under-bid하게 되어 `nl`-heavy 할당이 고착됨. 이 압박이 해소되면 모델이 과거 0.11 IPM으로 전환되던 `ib` 프리미엄 인벤토리에 다시 경쟁 입찰 가능 (현재 `nl`은 0.012 IPM).
   - **운영 게이트:** 클라이언트가 AIRBRIDGE / DPLAN360 측에 3/19-20 KST postback forwarding 변경 여부를 확인하기 전까지 예산 증액 금지. 확인 결과를 티켓에 기록한 뒤 예산 변경 진행.

5. **신규 활성화된 nl 크리에이티브 `IhrxSOh9QzmyZyzv` 차단.** 크리에이티브 `IhrxSOh9QzmyZyzv` (그룹 `EVX0myMHmYIGMRgQ`)는 4/3 활성화 즉시 KAKAO 임프레션의 60%를 점유. 4/3 이후 동일 KAKAO 인벤토리 기준 apples-to-apples 비교 시 IPM은 0.012 vs 기존 ib `ogMJ5cQEBJ4fNbOw`의 0.020 — 동일 오디언스에서 38% 낮은 전환률. 캠페인 레벨에서 본 크리에이티브를 pause하면 최저 IPM 수단이 로테이션에서 제거됨.
   - *참고: floor-price / 포맷 차단 레버는 buy-side에서 불가 (DSP는 입찰만 담당, 퍼블리셔가 floor-price 설정). Actionable 레버는 포맷 레벨 차단이 아닌 크리에이티브 레벨 pause.*

### [모델 피드백 재생성] 병행 트랙
6. **Attribution 회복 후 2주 학습 window 확보.** 일일 모니터링과 함께 단계적 예산 ramp. 정상적인 KOR 증권 iOS advertiser의 참조 궤적으로 삼성증권 활용 (동일 3/20-21 window에서 5-6% attribution rate 안정 유지).

---

## 미해결 질문 — 솔직한 갭

1. **Phase 1 트리거 정확한 원인 미확인** — KB 앱 빌드 변경? DPLAN360 postback 라우팅? AIRBRIDGE tenant config? 3가지 모두 외부 엔티티 정보 필요.
2. **삼성증권 TBC 차원들** — KPI, tfexample 라벨 볼륨, 일일 예산, exchange mix, supply SKAN 점유율, LAT rate. 현재는 attribution rate와 AFP만 직접 조회됨.
3. **Phase 2 독립성 미확정** — Phase 2 attribution-rate 열화가 Phase 1의 downstream 아티팩트인지 별개 Moloco-side 이벤트인지 완전히 disentangle 되지 않음. 분모가 너무 작아 분리 어려움.
4. **4/3 신규 크리에이티브 활성화의 의사결정 주체** — 광고주/대행사가 업로드했는지, Moloco 서빙 모델이 자동 트리거했는지 확인 필요.
5. **기존 ib 크리에이티브의 4/3 −82% IPM 붕괴의 동시 외부 요인** — KAKAO 오디언스 변동, 저품질 인벤토리 재배분, 또는 3/20 attribution degradation의 지속 중 무엇이 지배적인지 미확정.

---

## 출처 범례

- **A#** — A-phase 질문 (iteration N의 데이터/메트릭 질문)
- **B#** — B-phase 질문 (시스템/컨텍스트 질문)
- **ADV#** — ADV 질문 (proof by contradiction, I2+)
- **F#** — F 질문 (cross-validation, fm_phase)
- **M#** — M 질문 (메커니즘/코드, fm_phase)
- **C#** — Code search reference
- **BQ-32d** — 32일 rolling BQ 스냅샷

---

## 재현 가능한 쿼리

주요 쿼리는 EN 리포트 HTML의 §D 또는 `session_log.md` 참조. 핵심 쿼리:

- **A11** — hourly pb attr/unattr 3/19-22 cliff 정밀 분해
- **A6** — 일일 KB attribution rate Feb-Apr
- **ADV3** — 9-피어 코호트 동일 기간 비교
- **F7** — PIM-2841 event timeline + KB impacted-campaigns 시트
- **F8** — KB 캠페인 config, AFP, exchange mix
- **v2 gap-fill** — 크리에이티브 단위 IPM (KAKAO only, `ogMJ5cQEBJ4fNbOw` vs `IhrxSOh9QzmyZyzv`)

---

*v2 개정 2026-04-19. 기반 조사: Session `57f49cb` (3 iterations, JUDGE_I1 REJECT → JUDGE_I2 REJECT → JUDGE_FINAL PASS). v1 생성일: 2026-04-17.*
