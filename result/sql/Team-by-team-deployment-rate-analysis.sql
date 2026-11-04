-- [팀별 투입 분석: 4~9월 / 주말 제외 / 제외항목 제거 후 월별 합=100%, 기간 합=100%]
WITH
params AS (
  SELECT date('2025-04-01') AS d_start,
         date('2025-09-30') AS d_end
),

/* 0) 원천 로우 (작성자/날짜 보정 + 특정 인원 제외) */
raw0 AS (
  SELECT
    date(COALESCE(NULLIF(작성일자,''), NULLIF("만든 날짜",''))) AS d,
    TRIM(작성자)                                AS person,
    COALESCE(NULLIF(TRIM(팀),''),'(미지정팀)')           AS team,
    TRIM(COALESCE(업무_계정,''))                 AS cat_raw,
    TRIM(COALESCE(프로젝트명,''))                AS proj_raw,
    CAST(작업시간 AS REAL)                      AS hours
  FROM Daily_DB
  WHERE 작성자 IS NOT NULL
    AND TRIM(작성자) <> ''
    AND TRIM(작성자) NOT IN (
      '사용자14','사용자18','미사용자C','사용자19','사용자20','사용자21','사용자22','개발자A',
      '사용자23','사용자24','사용자25','사용자26','사용자27','사용자28'
    )
),

/* 0-1) 최종 필터 + 재분류 (TF/기타업무/교육/연차 규칙) */
raw AS (
  SELECT
    d,
    person,
    team,
    CASE
      WHEN cat_raw = '기타업무' AND proj_raw IN ('국내 인증(제품A)','국외 인증(제품A)','제품A시험','검정/인증')
        THEN '제품개발(제품A)'
      WHEN TRIM(COALESCE(cat_raw,'')) = '' THEN '(미지정계정)'
      ELSE cat_raw
    END AS cat,
    CASE
      WHEN TRIM(COALESCE(proj_raw,'')) = '' THEN '기타업무'
      ELSE proj_raw
    END AS proj,
    hours
  FROM raw0
  WHERE d IS NOT NULL
    AND (
      COALESCE(cat_raw,'') NOT IN ('TF','교육','기타업무','연차(반차)')
      OR (cat_raw = 'TF' AND proj_raw <> 'TF 프로젝트X')
      OR (cat_raw = '기타업무' AND proj_raw IN ('국내 인증(제품A)','국외 인증(제품A)','제품A시험','검정/인증'))
    )
    AND COALESCE(cat_raw,'') NOT IN ('교육','연차(반차)')
),

/* 1) 기간 + 주말 제외 */
raw_cut AS (
  SELECT *
  FROM raw, params
  WHERE d BETWEEN params.d_start AND params.d_end
    AND strftime('%w', d) IN ('1','2','3','4','5')
),

/* 2) 동일 인물·일자·대분류·소분류 합산 */
base AS (
  SELECT d, person, team, cat, proj, SUM(hours) AS hours
  FROM raw_cut
  GROUP BY d, person, team, cat, proj
),

/* 3) 1인-1일 합계 */
person_day AS (
  SELECT d, person, team, SUM(hours) AS sum_hours
  FROM base
  GROUP BY d, person, team
),

/* 4) 미작성/미달 → '기타업무' 생성(집계에선 제외) */
remainder AS (
  SELECT d, person, team, MAX(8.0 - sum_hours, 0.0) AS etc_add
  FROM person_day
),
completed AS (
  SELECT d, person, team, cat, proj, hours FROM base
  UNION ALL
  SELECT d, person, team, '기타업무' AS cat, '기타업무' AS proj, etc_add
  FROM remainder
  WHERE etc_add > 0
),

/* 5) 보정 후 재합산 */
completed_aggr AS (
  SELECT d, person, team, cat, proj, SUM(hours) AS hours
  FROM completed
  GROUP BY d, person, team, cat, proj
),

/* 6) 일별 참여 인원 (기타업무 제외) */
writers_day AS (
  SELECT d, COUNT(DISTINCT person) AS writers_cnt
  FROM completed_aggr
  WHERE proj <> '기타업무'
  GROUP BY d
),

/* 7) 일자-대분류-소분류 시간 (기타업무 제외) */
project_day AS (
  SELECT d, cat, proj, SUM(hours) AS proj_hours
  FROM completed_aggr
  WHERE proj <> '기타업무'
  GROUP BY d, cat, proj
),

/* 8) 월 키 */
keys AS (
  SELECT DISTINCT d, strftime('%Y-%m', d) AS ymonth
  FROM project_day
),

/* 9) (참고) 전체 월 표준용량(참여자×8h) */
month_capacity AS (
  SELECT strftime('%Y-%m', d) AS ymonth,
         SUM(writers_cnt * 8.0) AS month_capacity_hours
  FROM writers_day
  GROUP BY ymonth
),

/* 10) 월×대분류×소분류 시간(분자) */
cat_proj_month AS (
  SELECT k.ymonth, p.cat, p.proj, SUM(p.proj_hours) AS proj_hours
  FROM project_day p
  JOIN keys k ON k.d = p.d
  GROUP BY k.ymonth, p.cat, p.proj
),

/* ───────────── 팀 단위 집계 ───────────── */
/* T1) 일자-팀 시간(기타업무 제외) */
team_day AS (
  SELECT d, team, SUM(hours) AS team_hours
  FROM completed_aggr
  WHERE proj <> '기타업무'
  GROUP BY d, team
),

/* T2) 월×팀 시간 */
team_month AS (
  SELECT k.ymonth, td.team, SUM(td.team_hours) AS team_hours_month
  FROM team_day td
  JOIN keys k ON k.d = td.d
  GROUP BY k.ymonth, td.team
),

/* T3) 기간×팀 총시간 */
team_period AS (
  SELECT team, SUM(team_hours_month) AS team_hours_period
  FROM team_month
  GROUP BY team
),

/* 12) 월별 분모 = '잔여 프로젝트들의 월별 총합' → 월별 합계 100% */
month_included_total AS (
  SELECT ymonth, SUM(proj_hours) AS month_included_hours
  FROM cat_proj_month
  GROUP BY ymonth
),

/* T4) 팀 월별 점유율(잔여 기준) */
team_month_pct AS (
  SELECT
    tm.ymonth,
    tm.team,
    ROUND(tm.team_hours_month * 100.0 / NULLIF(mt.month_included_hours,0), 2) AS pct_month
  FROM team_month tm
  JOIN month_included_total mt ON mt.ymonth = tm.ymonth
),

/* T5) 팀 월별 점유율 피벗(4~9월) */
team_month_pivot AS (
  SELECT
    team,
    ROUND(SUM(CASE WHEN ymonth='2025-04' THEN pct_month END), 2) AS "2025-04_%",
    ROUND(SUM(CASE WHEN ymonth='2025-05' THEN pct_month END), 2) AS "2025-05_%",
    ROUND(SUM(CASE WHEN ymonth='2025-06' THEN pct_month END), 2) AS "2025-06_%",
    ROUND(SUM(CASE WHEN ymonth='2025-07' THEN pct_month END), 2) AS "2025-07_%",
    ROUND(SUM(CASE WHEN ymonth='2025-08' THEN pct_month END), 2) AS "2025-08_%",
    ROUND(SUM(CASE WHEN ymonth='2025-09' THEN pct_month END), 2) AS "2025-09_%"
  FROM team_month_pct
  GROUP BY team
),

/* 14) 기간 총합의 분모 = 잔여 프로젝트들의 4~9월 총합 → 기간 합계 100% */
period_included_total AS (
  SELECT SUM(team_hours_period) AS period_included_hours
  FROM team_period
),

/* 보조지표: 팀 고유 인원/프로젝트/용량(가동률 계산용) */
team_unique_writers AS (
  SELECT team, COUNT(DISTINCT person) AS unique_writers_period
  FROM completed_aggr
  WHERE proj <> '기타업무'
    AND d BETWEEN (SELECT d_start FROM params) AND (SELECT d_end FROM params)
    AND strftime('%w', d) IN ('1','2','3','4','5')
  GROUP BY team
),
team_unique_projects AS (
  SELECT team, COUNT(DISTINCT proj) AS unique_projects_period
  FROM completed_aggr
  WHERE proj <> '기타업무'
    AND d BETWEEN (SELECT d_start FROM params) AND (SELECT d_end FROM params)
    AND strftime('%w', d) IN ('1','2','3','4','5')
  GROUP BY team
),
team_writers_day AS (  -- 팀별 일일 고유 인원
  SELECT d, team, COUNT(DISTINCT person) AS writers_cnt
  FROM completed_aggr
  WHERE proj <> '기타업무'
  GROUP BY d, team
),
team_period_capacity AS (  -- 팀별 기간 용량 = Σ(일별 고유 인원 × 8h)
  SELECT team, SUM(writers_cnt * 8.0) AS cap_hours_period
  FROM team_writers_day
  WHERE d BETWEEN (SELECT d_start FROM params) AND (SELECT d_end FROM params)
    AND strftime('%w', d) IN ('1','2','3','4','5')
  GROUP BY team
)

SELECT
  tp.team                                       AS "팀",
  ROUND(tp.team_hours_period, 1)                AS "기간_총시간",
  /* 잔여 기준 기간 점유율(합=100%) */
  ROUND(tp.team_hours_period * 100.0 / NULLIF(pit.period_included_hours,0), 2) AS "총합_%",
  /* 팀 자체 가동률 = 팀 총시간 / (팀 용량) */
  ROUND(tp.team_hours_period * 100.0 / NULLIF(tpc.cap_hours_period,0), 2)       AS "가동률_%",
  /* 인력/분산 지표 */
  tuw.unique_writers_period                     AS "고유_투입인원",
  ROUND(CASE WHEN tuw.unique_writers_period>0
       THEN tp.team_hours_period * 1.0 / tuw.unique_writers_period END, 1)      AS "1인_평균시간",
  tup.unique_projects_period                     AS "고유_프로젝트수",
  ROUND( CASE WHEN tuw.unique_writers_period>0
         THEN 1.0 * tup.unique_projects_period / tuw.unique_writers_period END
       , 2)                                                                           AS "분산도(프로젝트/인원)",

  /* 월별 점유율(잔여 기준 → 각 월 합 100%) */
  p."2025-04_%", p."2025-05_%", p."2025-06_%",
  p."2025-07_%", p."2025-08_%", p."2025-09_%",

  /* 월별 평균(가독용) */
  ROUND( (COALESCE(p."2025-04_%",0)+COALESCE(p."2025-05_%",0)+COALESCE(p."2025-06_%",0)
        + COALESCE(p."2025-07_%",0)+COALESCE(p."2025-08_%",0)+COALESCE(p."2025-09_%",0)) / 6.0, 2) AS "평균_%"
FROM team_period tp
JOIN period_included_total pit  ON 1=1
LEFT JOIN team_month_pivot p    ON p.team = tp.team
LEFT JOIN team_unique_writers tuw    ON tuw.team = tp.team
LEFT JOIN team_unique_projects tup   ON tup.team = tp.team
LEFT JOIN team_period_capacity tpc   ON tpc.team = tp.team
ORDER BY "총합_%" DESC, "기간_총시간" DESC;
