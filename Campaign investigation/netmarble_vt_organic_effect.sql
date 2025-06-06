/* 

CONTEXT: https://moloco.slack.com/archives/C07G2UKQPD2/p1744950361880289

네 그래서 저도 그냥 트렌드는 참 우리에게 유리하게 보이는 느낌인데, 이게 VT에 안 잡혔으려면 VT Window 바깥에서 전환을 그만큼 일으키고 있었는지 보여줘야 할거 같아요. 
예를 들어, VT Window는 24시간이었는데, 우리가 타겟팅을 했던 유저들이 24시간이 지나서 신규 유저로 들어왔었던 케이스들의 볼륨이 꽤 있다고 보면 저희가 VT를 무작정 낮추는것이 
과연 넷마블의 매출을 위해서 좋은것인가 얘기를 해줄 수 있을 것 같아요.
그런데 여기에서 저도 말씀드리며 궁금한게, 저희가 iOS에서 노출했던 유저들 중에서 위의 시나리오처럼 Attribution Window 바깥에서 전환을 일으킨 애들을 분석할 수 있나요?? 
저희가 노출한 애들에게는 mtid가 붙는다는건 알고 있는데, 이게 포스트백 상으로 들어왔을 때에도 그 mtid들이 붙어 있는지를 모르겠어서요


*/


DECLARE start_date DEFAULT DATE '2025-03-13';
DECLARE end_date DEFAULT DATE '2025-04-17';


WITH pb_install AS (
  SELECT
    device.ifa AS idfa,
    moloco.attributed AS attributed,
    DATE(event.install_at) AS install_dt,
    MIN(event.install_at) AS install_ts
  FROM `focal-elf-631.prod_stream_view.pb`
  WHERE 
    app.bundle = 'id1662742277'
    AND `moloco-ods.general_utils.is_idfa_truly_available`(device.ifa)
    AND DATE(event.install_at) >= start_date  
    AND DATE(timestamp) >= start_date 
    AND event.name = 'install'
    AND device.country = 'USA'
  GROUP BY 1, 2
),
imp AS (
  SELECT 
    req.device.ifa AS idfa,
    timestamp AS imp_ts
  FROM `focal-elf-631.prod_stream_view.imp`
  WHERE api.campaign.id = 'EJ0ByvFbTnVwDiLE'
    AND DATE(timestamp)>= start_date
)

raw AS (
    SELECT
        pb_install.install_dt, 
        pb_install.idfa,
        pb_install.attributed,
        install_ts,
        MAX(imp_ts) AS last_imp_ts,
        COALESCE(TIMESTAMP_DIFF(install_ts, MAX(imp_ts), HOUR), NULL) AS diff_hour,
        FLOOR(COALESCE(TIMESTAMP_DIFF(install_ts, MAX(imp_ts), HOUR), NULL) / 24) AS diff_day
        --   COALESCE( TIMESTAMP_DIFF(install_ts, MAX(imp_ts) OVER (PARTITION bY pb_install.idfa), HOUR), NULL) AS diff_hour
    FROM pb_install LEFT JOIN imp 
    ON pb_install.idfa = imp.idfa
    AND pb_install.install_ts > imp.imp_ts 
    GROUP BY 1,2,3
)

SELECT 
    install_dt,
    attributed,
    diff_day,
    COUNT(DISTINCT idfa) AS num_idfa
FROM raw
GROUP BY 1,2,3