## https://mlc.atlassian.net/browse/ODSB-13887
## Ref: https://colab.research.google.com/drive/1TvpCGf7nzQ2F9N_Oeqka6JqDIoTWLdS9?usp=drive_open#scrollTo=mu-Y9SH4iPI8

# change parameters to your use case -
# time period of interest (agreed upon with GM e.g. https://mlc.atlassian.net/browse/ODSB-5482?focusedCommentId=120195),
# install leakage data pull is done at the app bundle level.

account = 'com2us' # name of account for output csv file

app_params = {
    "start_date": "2025-08-01",
    "end_date": "2025-09-07",
    "adv_id": "pXUn4VXuQc11Wryh",
    "app_bundle": "com.com2us.legion.android.google.global.normal",
    # "country": "IND"
    }



### CT 1-Hour Install leakage

    %%time
    %%bigquery df_leakage --params $app_params --project focal-elf-631


    # THIS_QUERY_WILL_LEAD_MOLOCO_TO_UNICORN_DO_NOT_KILL

    WITH
    install_attr AS (
        SELECT
        COUNT(DISTINCT device.ifa) AS cnt_attributed_install,
        # MAX(timestamp) install_ts
        FROM
        `focal-elf-631.prod_stream_view.pb`
        WHERE
        DATE(timestamp) BETWEEN @start_date AND DATE_ADD(@end_date, INTERVAL 1 DAY) -- takes into account unattributed installs that occurred in the next day
        AND app.bundle = @app_bundle
        AND LOWER(event.name) = 'install'
        AND moloco.attributed IS TRUE
        AND `moloco-ods.general_utils.is_userid_truly_available`(device.ifa)
        # AND device.country = @country
    ),
    install_unattr AS ( -- install subquery: GAID and their last recorded unattributed install timestamp (technically there should only be one install timestamp)
    SELECT
        device.ifa,
        MAX(timestamp) install_ts
    FROM
        `focal-elf-631.prod_stream_view.pb`
    WHERE
        DATE(timestamp) BETWEEN @start_date AND DATE_ADD(@end_date, INTERVAL 1 DAY) -- takes into account unattributed installs that occurred in the next day
        AND app.bundle = @app_bundle
        AND LOWER(event.name) = 'install'
        AND moloco.attributed IS FALSE
        AND `moloco-ods.general_utils.is_userid_truly_available`(device.ifa)
        # AND device.country = @country
    GROUP BY
        1),
    click_unattr AS ( -- click subequery: GAID and their corresponding last click timestamp
        SELECT
        click.req.device.ifa,
        MAX(timestamp) last_click,
        FROM
        `focal-elf-631.prod_stream_view.click` click
        INNER JOIN install_unattr
        ON install_unattr.ifa = click.req.device.ifa
        WHERE timestamp < install_unattr.install_ts
        AND DATE(timestamp) BETWEEN @start_date AND @end_date
        AND advertiser_id = @adv_id
        AND api.product.app.tracking_bundle = @app_bundle
        AND `moloco-ods.general_utils.is_userid_truly_available`(req.device.ifa)
        # AND req.device.geo.country = @country
        GROUP BY
        1),
    -- inner join click and install subqueries on GAID, where the unattributed install timestamp is within 60 minutes after the click timestamp
    leakage_unattr AS (
        SELECT
        # *,
        # TIMESTAMP_DIFF(install_ts, last_click, minute) minute_from_click
        COUNT(DISTINCT click_unattr.ifa) AS cnt_leakage_unattr_installs
        FROM
        click_unattr
        INNER JOIN
        install_unattr
        USING
        (ifa)
        WHERE
        install_ts > last_click
        AND TIMESTAMP_DIFF(install_ts, last_click, minute) BETWEEN 0 and 60
    ),
    leakage_ratio AS(
        SELECT
        cnt_leakage_unattr_installs,
        cnt_attributed_install,
        ROUND(SAFE_DIVIDE(cnt_leakage_unattr_installs,(cnt_attributed_install+cnt_leakage_unattr_installs)),2) AS leakage_ratio
        FROM
        install_attr,
        leakage_unattr
    )
    SELECT *
    FROM leakage_ratio


### VT 1-Day Install leakage
    # change parameters to your use case -

    app_params = {
        "start_date": "2025-08-01",
        "end_date": "2025-09-07",
        "adv_id": "pXUn4VXuQc11Wryh",
        "app_bundle": "com.com2us.legion.android.google.global.normal",
        "vt_hours": 24,
        "click_lookback_days": 7,
        "ct_minutes": 60
        }


    %%time
    %%bigquery df_leakage_vt --params $app_params --project focal-elf-631


    -- Params (예시)
    -- @start_date        DATE
    -- @end_date          DATE
    -- @adv_id            STRING
    -- @app_bundle        STRING
    -- @vt_hours          INT64   -- 기본 24
    -- @click_lookback_days INT64 -- 기본 7

    -- THIS_QUERY_WILL_LEAD_MOLOCO_TO_UNICORN_DO_NOT_KILL

    WITH
    -- 1) 당사에 어트리뷰트된 설치 수
    install_attr AS (
    SELECT
        COUNT(DISTINCT device.ifa) AS cnt_attributed_install
    FROM `focal-elf-631.prod_stream_view.pb`
    WHERE
        DATE(timestamp) BETWEEN @start_date AND DATE_ADD(@end_date, INTERVAL 1 DAY) -- +1day 여유
        AND app.bundle = @app_bundle
        AND LOWER(event.name) = 'install'
        AND moloco.attributed IS TRUE
        AND `moloco-ods.general_utils.is_userid_truly_available`(device.ifa)
    ),

    -- 2) 당사에 어트리뷰트되지 않은 설치(ifa별 마지막 설치시각) 집계
    install_unattr AS (
    SELECT
        device.ifa,
        MAX(timestamp) AS install_ts
    FROM `focal-elf-631.prod_stream_view.pb`
    WHERE
        DATE(timestamp) BETWEEN @start_date AND DATE_ADD(@end_date, INTERVAL 1 DAY)
        AND app.bundle = @app_bundle
        AND LOWER(event.name) = 'install'
        AND moloco.attributed IS FALSE
        AND `moloco-ods.general_utils.is_userid_truly_available`(device.ifa)
    GROUP BY 1
    ),

    -- 3) (참고용) 설치 이전 lookback 기간 내 클릭이 있었는지 여부
    any_click_before_install AS (
    SELECT
        iu.ifa
    FROM install_unattr iu
    JOIN `focal-elf-631.prod_stream_view.click` c
        ON c.req.device.ifa = iu.ifa
    AND c.timestamp < iu.install_ts
    AND c.timestamp >= TIMESTAMP_SUB(iu.install_ts, INTERVAL @click_lookback_days DAY)
    WHERE
        DATE(c.timestamp) BETWEEN @start_date AND @end_date
        AND c.advertiser_id = @adv_id
        AND c.api.product.app.tracking_bundle = @app_bundle
        AND `moloco-ods.general_utils.is_userid_truly_available`(c.req.device.ifa)
    GROUP BY iu.ifa
    ),

    -- 4) 설치 직전 @vt_hours 이내에 있었던 마지막 노출(imp) 포착
    last_imp_within_vt AS (
    SELECT
        iu.ifa,
        MAX(i.timestamp) AS last_imp_ts
    FROM install_unattr iu
    JOIN `focal-elf-631.prod_stream_view.imp` i
        ON i.req.device.ifa = iu.ifa
    AND i.timestamp < iu.install_ts
    AND i.timestamp >= TIMESTAMP_SUB(iu.install_ts, INTERVAL @vt_hours HOUR)
    WHERE
        DATE(i.timestamp) BETWEEN @start_date AND @end_date
        AND i.advertiser_id = @adv_id
        AND i.api.product.app.tracking_bundle = @app_bundle
        AND `moloco-ods.general_utils.is_userid_truly_available`(i.req.device.ifa)
    GROUP BY iu.ifa
    ),

    -- 5) "클릭이 전혀 없었고, VT 윈도 내 노출이 있었던" unattributed 설치 수
    vt_unattr AS (
    SELECT
        COUNT(DISTINCT li.ifa) AS cnt_vt_unattr_installs
    FROM last_imp_within_vt li
    LEFT JOIN any_click_before_install ac
        ON ac.ifa = li.ifa
    WHERE ac.ifa IS NULL   -- lookback 내 클릭이 없었던 경우만
    ),

    -- 6) 비율 계산
    vt_leakage_ratio AS (
    SELECT
        cnt_vt_unattr_installs,
        cnt_attributed_install,
        ROUND(
        SAFE_DIVIDE(
            cnt_vt_unattr_installs,
            (cnt_attributed_install + cnt_vt_unattr_installs)
        ),
        4
        ) AS vt_leakage_ratio
    FROM vt_unattr, install_attr
    )

    SELECT *
    FROM vt_leakage_ratio;


