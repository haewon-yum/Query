가능해요! STRING_AGG 를 쓰면 한 컬럼의 값을 콤마로 이어 붙인 한 줄 문자열로 만들 수 있어요.

1) 기본: DISTINCT + 정렬
SELECT
  STRING_AGG(DISTINCT app_market_bundle, ',' ORDER BY app_market_bundle) AS csv
FROM app
WHERE unified_app_id IN (SELECT unified_app_id FROM top_apps);

2) IN 절에 바로 붙여 쓰고 싶다면(따옴표 포함)
SELECT
  '(' ||
  STRING_AGG(
    "'" || REPLACE(app_market_bundle, "'", "''") || "'",  -- 값 안의 ' 이스케이프
    ',' ORDER BY app_market_bundle
  )
  || ')' AS in_list
FROM app
WHERE unified_app_id IN (SELECT unified_app_id FROM top_apps);

3) 참고 팁

IGNORE NULLS 옵션으로 NULL 값은 건너뛸 수 있어요:
STRING_AGG(expr, ',' IGNORE NULLS)

결과 길이가 아주 길면 UI에서 잘려 보일 수 있어요. 그럴 땐 Save results나 EXPORT DATA를 사용하세요.

같은 효과로 ARRAY_TO_STRING(ARRAY_AGG(...), ',')도 가능하지만, STRING_AGG가 더 간단합니다.