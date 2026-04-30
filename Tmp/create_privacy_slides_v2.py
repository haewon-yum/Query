#!/usr/bin/env python3
"""
Create Google Slides v2: 개인정보 유출에 따른 손해배상 책임
중앙대 특강 — 류승균
Changes: expanded bullets (~2 lines), callout boxes (Q&A / 판례 / 보충 설명), case-slide type
"""

import subprocess, uuid, requests, sys

# ── auth ──────────────────────────────────────────────────────────────────────
def get_token():
    r = subprocess.run(["gcloud", "auth", "print-access-token"],
                       capture_output=True, text=True, check=True)
    return r.stdout.strip()

TOKEN = get_token()
HEADERS = {
    "Authorization": f"Bearer {TOKEN}",
    "Content-Type": "application/json",
    "x-goog-user-project": "moloco-ods",
}
SLIDES_API = "https://slides.googleapis.com/v1/presentations"

def api_post(url, body):
    r = requests.post(url, headers=HEADERS, json=body)
    if not r.ok:
        print("ERROR:", r.status_code, r.text[:800])
        sys.exit(1)
    return r.json()

def api_get(url):
    r = requests.get(url, headers=HEADERS)
    r.raise_for_status()
    return r.json()

def batch(pres_id, reqs):
    for i in range(0, len(reqs), 50):
        chunk = reqs[i:i+50]
        api_post(f"{SLIDES_API}/{pres_id}:batchUpdate", {"requests": chunk})
        print(f"  requests {i}–{i+len(chunk)} ok")

# ── colours ───────────────────────────────────────────────────────────────────
NAVY        = {"red": 0.067, "green": 0.180, "blue": 0.373}
WHITE       = {"red": 1.0,   "green": 1.0,   "blue": 1.0}
LGREY       = {"red": 0.933, "green": 0.941, "blue": 0.953}
ACCENT      = {"red": 0.941, "green": 0.498, "blue": 0.141}   # orange
DGREY       = {"red": 0.45,  "green": 0.45,  "blue": 0.45}
CASE_BG     = {"red": 0.93,  "green": 0.96,  "blue": 1.0}     # pale blue slide bg
CASE_LBG    = {"red": 0.87,  "green": 0.92,  "blue": 0.98}    # label bar bg
CASE_ACCENT = {"red": 0.20,  "green": 0.45,  "blue": 0.80}    # medium blue
QA_BG       = {"red": 1.0,   "green": 0.96,  "blue": 0.83}    # pale amber
QA_ACCENT   = {"red": 0.80,  "green": 0.50,  "blue": 0.05}    # dark amber
NOTE_BG     = {"red": 0.94,  "green": 0.94,  "blue": 0.97}    # pale grey-blue
NOTE_ACCENT = {"red": 0.35,  "green": 0.50,  "blue": 0.70}    # slate blue

def uid():
    return "x" + uuid.uuid4().hex[:12]

def solid(c):
    return {"solidFill": {"color": {"rgbColor": c}}}

def opaque(c):
    return {"opaqueColor": {"rgbColor": c}}

def pt(v):
    return {"magnitude": v, "unit": "PT"}

def transform(x, y):
    return {"scaleX": 1, "scaleY": 1,
            "translateX": x, "translateY": y, "unit": "PT"}

def elem_props(page_id, x, y, w, h):
    return {
        "pageObjectId": page_id,
        "size": {"width": pt(w), "height": pt(h)},
        "transform": transform(x, y),
    }

# ── primitive builders ────────────────────────────────────────────────────────
def make_textbox(page_id, obj_id, text, x, y, w, h,
                 font_size=12, bold=False, color=None,
                 line_spacing=None, align=None):
    color = color or NAVY
    reqs = [
        {"createShape": {
            "objectId": obj_id, "shapeType": "TEXT_BOX",
            "elementProperties": elem_props(page_id, x, y, w, h),
        }},
        {"insertText": {"objectId": obj_id, "text": text, "insertionIndex": 0}},
        {"updateTextStyle": {
            "objectId": obj_id,
            "textRange": {"type": "ALL"},
            "style": {
                "fontSize": pt(font_size),
                "bold": bold,
                "foregroundColor": opaque(color),
                "weightedFontFamily": {"fontFamily": "Noto Sans KR"},
            },
            "fields": "fontSize,bold,foregroundColor,weightedFontFamily",
        }},
    ]
    para_style, fields = {}, []
    if line_spacing:
        para_style["lineSpacing"] = line_spacing
        fields.append("lineSpacing")
    if align:
        para_style["alignment"] = align
        fields.append("alignment")
    if fields:
        reqs.append({"updateParagraphStyle": {
            "objectId": obj_id,
            "textRange": {"type": "ALL"},
            "style": para_style,
            "fields": ",".join(fields),
        }})
    return reqs

def make_rect(page_id, obj_id, x, y, w, h, fill_color):
    return [
        {"createShape": {
            "objectId": obj_id, "shapeType": "RECTANGLE",
            "elementProperties": elem_props(page_id, x, y, w, h),
        }},
        {"updateShapeProperties": {
            "objectId": obj_id,
            "shapeProperties": {"shapeBackgroundFill": solid(fill_color)},
            "fields": "shapeBackgroundFill",
        }},
    ]

def bg_req(page_id, color):
    return {"updatePageProperties": {
        "objectId": page_id,
        "pageProperties": {"pageBackgroundFill": solid(color)},
        "fields": "pageBackgroundFill",
    }}

def make_callout_box(page_id, x, y, w, h, label, text, style):
    """Callout box: background + left accent strip + label + content text"""
    MAP = {
        "qa":   (QA_BG,    QA_ACCENT,    NAVY),
        "case": (CASE_LBG, CASE_ACCENT,  NAVY),
        "note": (NOTE_BG,  NOTE_ACCENT,  {"red": 0.15, "green": 0.20, "blue": 0.35}),
    }
    bg_c, acc_c, txt_c = MAP[style]
    reqs = []
    reqs.extend(make_rect(page_id, uid(), x, y, w, h, bg_c))
    reqs.extend(make_rect(page_id, uid(), x, y, 4, h, acc_c))
    reqs.extend(make_textbox(page_id, uid(), label,
                              x+10, y+5, w-14, 16,
                              font_size=9, bold=True, color=acc_c))
    reqs.extend(make_textbox(page_id, uid(), text,
                              x+10, y+23, w-14, h-28,
                              font_size=10.5, bold=False, color=txt_c,
                              line_spacing=138))
    return reqs

# ── slide data ────────────────────────────────────────────────────────────────
# type: "title" | "section" | "case" | "content"
# content slides may also have "box": {"style", "label", "text"}

slides_data = [

    # ── 0. TITLE ──────────────────────────────────────────────────────────────
    {
        "type": "title",
        "title": "개인정보 유출에 따른\n손해배상 책임",
        "subtitle": "법과 판례, 그리고 실무상 쟁점\n\n류승균  |  중앙대학교 특강",
    },

    # ── 1. AGENDA ─────────────────────────────────────────────────────────────
    {
        "type": "section",
        "title": "강의 순서",
        "bullets": [
            "① 들어가면서 — 최근 유출 사건 배경과 강의 목적",
            "② 일반 손해배상 vs 개인정보 손해배상 — 특수성과 특칙",
            "③ 현행법상 개인정보 손해배상 제도",
            "    • 고의·과실 입증책임 전환",
            "    • 법정손해배상",
            "    • 징벌적 손해배상",
            "④ 법정손해배상 개정안 (2026년)",
            "⑤ 최근 논의 — 집단소송 · 동의의결 · 과징금 피해구제",
            "⑥ 나가면서 — 손해배상의 역할과 제도 개선 방향",
        ],
    },

    # ── 2. 들어가면서 ──────────────────────────────────────────────────────────
    {
        "type": "content",
        "title": "들어가면서",
        "bullets": [
            "최근 SKT·쿠팡 등 대규모 개인정보 유출 사건이 잇따르면서 기업의 법적 리스크가 그 어느 때보다 높아졌음."
            " 개인정보 유출 문제는 2014년 카드3사 사건이 본격적인 시작점이었으나, 이후에도 수시로 발생하면서 국민적 관심이 크게 증가함.",
            "",
            "국회는 2026년 2월 개인정보 보호법 개정안을 통과시켰고, 개인정보보호위원회(개보위)는 손해배상 제도 등의 추가 개정을"
            " 국회와 함께 추진 중임. 입법·행정 양측에서 기업의 법적 책임 강화 추세가 뚜렷하게 나타나고 있음.",
            "",
            "개인정보 유출 발생 시 법적 책임은 크게 두 가지로 나뉨: (i) 개보위가 조사·심의·의결하는 행정상 제재(시정명령·과징금),"
            " (ii) 피해자 정보주체가 법원에 민사소송을 제기하는 손해배상. 이번 강의는 후자인 손해배상에 초점을 맞춤.",
            "",
            "강의 목표: 법정을 다니지 않는 기업 개인정보 담당자를 대상으로, 민법·민사소송법 선행 지식 없이도"
            " 손해배상의 법리와 실무상 쟁점을 이해할 수 있도록 설명함.",
        ],
    },

    # ── 3. 일반 vs 개인정보 손해배상 + Q&A box ────────────────────────────────
    {
        "type": "content",
        "title": "일반 손해배상 vs 개인정보 손해배상",
        "bullets": [
            "민법 제750조는 손해배상의 일반 원칙을 규정함. 피해자(원고)가 ① 고의·과실, ② 위법행위,"
            " ③ 손해(손해액 포함), ④ 인과관계 네 가지 요건을 모두 직접 입증해야 배상을 받을 수 있음.",
            "",
            "개인정보 유출 사건에는 특수성이 있음: (i) 입증 자료가 피고(기업) 측에 집중되어 있고, (ii) 피해는 대부분"
            " 정신적 손해(위자료)라 금액 산정이 쉽지 않으며, (iii) 원고는 개인인데 피고는 대규모 기업인 구조임.",
            "",
            "이에 개인정보보호법은 일반 손해배상에 대한 특칙 세 가지를 마련함:"
            " 고의·과실 입증책임 전환, 법정손해배상(손해액 법정), 징벌적 손해배상(최대 5배 배상).",
        ],
        "box": {
            "style": "qa",
            "label": "Q&A",
            "text": (
                "Q.  손해배상 청구는 반드시 소송을 제기해야만 가능한가요?\n\n"
                "A.  원론적으로는 그렇지 않습니다. 손해가 발생하면 바로 배상 청구권이 생기므로, 피해자는 전화·이메일·고객센터 연락·내용증명 발송 등을 통해 "
                "배상을 요구할 수 있습니다. 다만 개인정보 유출 사건에서는 손해배상 요건(손해 발생, 과실, 인과관계)의 충족 여부가 다투어지는 경우가 많아, "
                "실무상 대부분 소송으로 진행됩니다."
            ),
        },
    },

    # ── 4. 현행법 개괄 ─────────────────────────────────────────────────────────
    {
        "type": "content",
        "title": "현행법 — 개인정보 손해배상 개괄",
        "bullets": [
            "근거 조문: 개인정보보호법 제39조 제1항. 이 규정은 민법 제750조의 일반 손해배상에 대한 특별 규정으로,"
            " 위법성 및 유책성 판단 기준을 '개인정보보호법 위반 여부'로 명확히 함."
            " (대법원 옥션 사건 — 법상 보호조치를 다하였다면 특별한 사정이 없는 한 위법하다고 볼 수 없음)",
            "",
            "손해 발생이 필요함. 개인정보가 유출되기만 하면 자동으로 손해가 성립하는지에 대해 견해 대립이 있으나,"
            " 판례는 유출 사실만으로 손해가 성립하는 것은 아니라는 입장임."
            " 대법원 GS칼텍스 사건에서 저장매체가 즉시 폐기·압수된 경우, '위자료로 배상할 만한 정신적 손해가 발생하였다고 보기 어렵다'고 판단함.",
            "",
            "인과관계 및 고의·과실도 요건임. 고의·과실에 관하여는 법상 입증책임이 전환되어 개인정보처리자가 무과실을 입증해야 하고,"
            " 이를 입증하지 못하면 배상 의무가 인정됨. 정신적 손해 발생 여부를 판단하는 기준은 대법원이 제시한 7가지 요소임 (다음 슬라이드).",
        ],
    },

    # ── 5. 정신적 손해 7가지 (CASE type — 판례 박스 스타일) ────────────────────
    {
        "type": "case",
        "title": "정신적 손해 발생 여부 — 대법원 판단 기준 (7가지)",
        "case_label": "대법원 판례  |  GS칼텍스 사건 — 구체적 사건에 따라 아래 7가지를 종합하여 개별 판단",
        "bullets": [
            "① 유출된 개인정보의 종류와 성격",
            "    — 민감정보(건강, 신체, 신념 등)·식별정보일수록 손해 인정 가능성이 높아짐",
            "② 정보주체 식별 가능성",
            "    — 유출된 정보만으로 개인을 특정·추적할 수 있는지 여부",
            "③ 제3자 열람 여부 또는 열람 가능성",
            "    — 아직 열람되지 않더라도 열람 가능성이 있으면 손해 인정 가능",
            "④ 유출 정보의 확산 범위",
            "    — 소수 내부자에 국한되었는지, 불특정 다수에게 퍼졌는지",
            "⑤ 추가적인 법익침해 가능성",
            "    — 보이스피싱·신원 도용·스팸 등 2차 피해 발생 위험 여부",
            "⑥ 개인정보 관리 실태 및 유출 경위",
            "    — 처리자의 안전조치 수준과 유출 원인(외부 해킹 vs 내부 부주의 등)",
            "⑦ 피해 확산 방지를 위한 사후 조치",
            "    — 유출 사실 고지·접근 차단·저장매체 폐기 등 신속한 대응 여부",
        ],
    },

    # ── 6. 고의·과실 입증책임 전환 ────────────────────────────────────────────
    {
        "type": "content",
        "title": "고의·과실 입증책임 전환",
        "bullets": [
            "개인정보 유출 사건에서의 '과실'은 사회생활상 요구되는 주의를 게을리하는 것으로,"
            " 실무상 개인정보보호법 제29조상 안전조치 의무 위반과 거의 동일하게 해석됨."
            " 즉, 과실 ≈ 안전조치 의무 위반으로 볼 수 있음.",
            "",
            "일반 민사소송에서는 피해자(원고)가 가해자의 과실을 직접 입증해야 하나,"
            " 개인정보보호법은 이 입증책임을 개인정보처리자(피고)에게 전환함."
            " 처리자가 '과실 없음'을 스스로 입증하지 못하면 배상 의무가 인정됨.",
            "",
            "실무적 의미: 기업은 유출 사고 발생 여부와 무관하게 안전조치 이행 내역"
            " (접근 통제 기록, 암호화 조치, 취약점 점검 이력 등)을 사전에 체계적으로 기록·보관해야 함."
            " 이 기록이 소송에서 무과실 항변의 핵심 증거가 됨.",
        ],
    },

    # ── 7. 법정손해배상 ────────────────────────────────────────────────────────
    {
        "type": "content",
        "title": "법정손해배상",
        "bullets": [
            "법정손해배상은 손해배상의 요건·효과를 법률로 미리 정하는 제도로, 미국 statutory damages 제도의 영향을 받아 도입됨."
            " 개인정보 분야에서는 2014년 카드3사 유출 사건을 계기로 2015년 개인정보보호법에 처음 도입됨.",
            "",
            "해석 논쟁 — 법정손해배상의 구체적 의미를 둘러싸고 학설 대립이 있었음:",
            "    [전자 — 손해액만 법정] 미국 제도 본래 의미 기준. 손해액은 법정하되, 손해 발생 자체는"
            " 원고가 여전히 입증해야 한다는 견해.",
            "    [후자 — 손해까지 법정] 법 문언 기준. 제39조의2 제1항에 '손해' 요건이 없으므로,"
            " 유출 사실만 입증하면 손해 발생 입증 없이도 배상받을 수 있다는 견해.",
            "",
            "최근 대법원 판결은 후자(손해의 법정)에 가까운 입장을 취함. 다만 실제 손해가 없으면 면책될 수 있다고 하여"
            " 완전한 자동 성립론은 아님. 개인당 배상액은 통상 10~30만 원(위자료 중심).",
        ],
    },

    # ── 8. 징벌적 손해배상 + 보충 설명 box ───────────────────────────────────
    {
        "type": "content",
        "title": "징벌적 손해배상",
        "bullets": [
            "연혁: 2016년 3배 배상이 도입된 이후 2023년 개정으로 배상 한도가 5배로 상향됨."
            " 종래 '손해 전보'만을 인정하던 우리 법체계에서, 예방 기능을 목적으로 도입된 제도임.",
            "",
            "추가 요건: 일반 손해배상(고의·과실)보다 가중된 '고의 또는 중대한 과실'을 요구하며, '개인정보 유출 등'"
            " 특히 심각한 침해 유형에만 적용됨. 개인정보 유출의 대부분이 과실에 의하므로 고의·중과실 요건 충족이 현실적으로 매우 어려움.",
            "",
            "실효성 문제: 도입 이후 현재까지 법원에서 징벌적 손해배상을 선고한 사례가 사실상 없어 제도가 작동하지 못하고 있음."
            " 배상액 산정 시에는 ① 고의·우려 인식 정도, ② 피해 규모, ③ 개인정보 회수 노력 등을 종합 고려해야 함.",
        ],
        "box": {
            "style": "note",
            "label": "보충 설명 — 위자료와 징벌적 손해배상",
            "text": (
                "하급심 판결 중 '위자료(정신적 손해)에는 성격상 징벌적 손해배상이 적용되지 않는다'고 한 사례가 있으나, 이는 타당하지 않음. "
                "① 징벌적 손해배상 규정의 대상은 '손해'로 규정되어 있고, ② 손해에는 재산적 손해뿐 아니라 정신적 손해(위자료)도 포함되는 것에 이견이 없으며, "
                "③ 개인정보 손해배상의 대부분이 위자료인데 법에 이를 배제하는 규정이 없음. "
                "위자료를 자의적으로 배제하는 것은 징벌적 손해배상 도입 취지를 몰각시키는 것임."
            ),
        },
    },

    # ── 9. 법정손해배상 개정안 + 보충 해석 box ───────────────────────────────
    {
        "type": "content",
        "title": "법정손해배상 개정안 (2026년)",
        "bullets": [
            "발의: 박범계 의원 대표발의 (2026. 2. 12.). '현행 법정손해배상 요건이 엄격하여 실효적 피해구제가 어렵다'는 이유로,"
            " 개인정보 유출 시 처리자에게 배상 책임이 있음을 명확히 하고, 처리자는 '책임 없는 사유'로 면책되는 구조로 개편함.",
            "",
            "핵심 변경: 기존 '고의 또는 과실로 인하여'와 '인하여(인과관계)' 문구를 삭제함."
            " ① 처리자가 고의·과실 없음을 입증하면 면책(과실책임 구조 유지, 무과실책임 아님),"
            " ② '인하여' 삭제로 인과관계는 더 이상 요구되지 않는 것으로 해석됨.",
            "",
            "효과: 정보주체는 입증 부담이 경감되고, 개인정보처리자는 면책 요건이 명문화되어 법적 안정성이 제고됨."
            " 안전조치 의무 준수 여부가 면책의 핵심 기준이 됨.",
        ],
        "box": {
            "style": "note",
            "label": "보충 해석 — 개정안과 과실책임의 관계",
            "text": (
                "개정안이 '고의 또는 과실로 인하여'를 삭제했다고 무과실책임이 되는 것은 아님. "
                "제2항은 '안전성 확보에 필요한 조치를 다한 경우' 등 처리자의 책임 없는 사유를 면책 사유로 명문화하고 있음. "
                "결국 개정안은 과실 판단 기준을 법 제29조상 안전조치 의무로 명확히 한 것이며, "
                "면책 요건의 명문화는 정보주체와 처리자 모두에게 법적 안정성을 가져다 주는 개선임."
            ),
        },
    },

    # ── 10. 집단소송 ──────────────────────────────────────────────────────────
    {
        "type": "content",
        "title": "최근 논의 ① — 집단소송 도입",
        "bullets": [
            "개인정보 유출 손해배상 사건의 가장 두드러진 특징은 '소액·다수' 구조임."
            " 개별 피해자에 대한 배상액은 통상 10~30만 원에 불과하지만, 동시에 수천만 명이 피해자가 되는 경우가 대부분임.",
            "",
            "현행 소송 제도에서는 피해자 개인이 소송을 제기할 유인이 극히 낮음."
            " 법원 인지대부터 변호사 비용에 이르기까지 소송에 드는 비용·시간이 배상액을 초과('배보다 배꼽')하여,"
            " 법상 실체적 권리가 있더라도 실질적으로 권리를 행사하지 못하는 구조가 지속됨.",
            "",
            "집단소송(Class Action)은 다수 피해자가 대표 당사자를 통해 공동으로 소송을 제기하는 제도로, 미국에서 발달함."
            " 우리나라도 증권관련 집단소송법으로 입법한 선례가 있으며, 유럽 대륙 각국도 '소비자집단소송지침'에 따라 도입 확산 중임.",
        ],
    },

    # ── 11. 동의의결 ──────────────────────────────────────────────────────────
    {
        "type": "content",
        "title": "최근 논의 ② — 동의의결 도입",
        "bullets": [
            "동의의결이란 규제기관과 피심인이 위법행위 중지·피해 구제·재발 방지 등의 내용을 합의하는 방식으로 사건을 종결하는 제도임."
            " 미국 독점금지법상 동의명령(consent order)을 모델로, 한-미 FTA를 계기로 2011년 공정거래법에 도입됨.",
            "",
            "개별 사건에서 합의를 통해 내용을 설계하므로 탄력적인 조치가 가능함."
            " 현행 시정조치가 위반행위에 대한 소극적 시정에 그치는 것과 달리,"
            " 동의의결은 향후 유출 예방을 위한 적극적 조치를 개별 사건에 맞게 설계할 수 있음.",
            "",
            "과징금 부과만으로는 피해자 정보주체의 손해를 직접 보전할 수 없다는 문제가 있음."
            " 동의의결에는 피해 구제를 위한 내용을 포함할 수 있어,"
            " 행정제재와 민사적 피해 구제를 연결하는 효과를 가질 수 있음.",
        ],
    },

    # ── 12. 과징금 피해 구제 ───────────────────────────────────────────────────
    {
        "type": "content",
        "title": "최근 논의 ③ — 과징금 수입으로 피해 구제",
        "bullets": [
            "현행 제도에서는 개인정보 유출에 대해 과징금이 부과되더라도 이는 원칙적으로 국고에 귀속되어 일반 세출에 충당됨."
            " 권리를 침해당한 피해자 정보주체에게 직접적인 구제 효과가 연결되지 않는다는 근본적인 문제가 있음.",
            "",
            "법률의 특별 규정이 있으면 과징금을 특정 기금에 귀속하거나 용도를 제한할 수 있음."
            " 입법례: [기금 귀속] 신에너지법(전력산업기반기금), 식품위생법(식품진흥기금), 국민건강보험법(응급의료기금);"
            " [목적 특정] 저작권법(이용 질서 확립), 청소년보호법(청소년 보호사업) 등.",
            "",
            "개인정보 유출 관련 과징금(법 제64조의2 제1항 제9호)은 권리 침해 피해자가 현존함을 전제로 부과되는 것임."
            " 따라서 이 과징금을 기금에 귀속하여 피해 구제에 활용하는 것이 제도적 정합성과 예방 패러다임에 부합함.",
        ],
    },

    # ── 13. 나가면서 ──────────────────────────────────────────────────────────
    {
        "type": "content",
        "title": "나가면서",
        "bullets": [
            "손해배상은 피해자의 손해를 전보(塡補)하는 기능 외에도 예방적 기능을 수행함."
            " 불법행위법은 잠재적 가해자에게 행위 기준을 제시하고 위반 시 제재 효과를 통해 일반 예방 기능을 수행하며,"
            " 정신적 손해(비재산적 손해)에서 이 예방 기능이 더욱 중요함.",
            "",
            "현행 개인정보보호법은 입증책임 전환·법정손해배상·징벌적 손해배상 등 실체적 특칙을 갖추고 있으나,"
            " 정보주체의 권리를 실질적으로 보호하고 예방 패러다임을 구현하는 데에는 여전히 한계가 있음.",
            "",
            "세 가지 제도 개선이 절실히 요구됨:",
            "    ① 법정손해배상 제도 개선 — 2026년 개정안으로 입증 부담 경감",
            "    ② 집단소송 도입 — 소액·다수 피해의 절차적 권리 구제 실질화",
            "    ③ 동의의결 및 피해구제 기금 도입 — 행정제재와 민사 구제의 연계",
        ],
    },
]

N = len(slides_data)  # 14 slides

# ── per-slide request generator ───────────────────────────────────────────────
def build_slide(slide_id, sd, num):
    r = []
    stype = sd["type"]

    # ── TITLE ────────────────────────────────────────────────────────────────
    if stype == "title":
        r.append(bg_req(slide_id, NAVY))
        r.extend(make_rect(slide_id, uid(), 0, 0, 720, 8, ACCENT))
        r.extend(make_textbox(slide_id, uid(), sd["title"],
                               50, 88, 620, 158,
                               font_size=34, bold=True, color=WHITE,
                               line_spacing=125, align="CENTER"))
        r.extend(make_rect(slide_id, uid(), 200, 256, 320, 2, ACCENT))
        r.extend(make_textbox(slide_id, uid(), sd["subtitle"],
                               50, 264, 620, 100,
                               font_size=14, bold=False, color=LGREY,
                               line_spacing=145, align="CENTER"))

    # ── SECTION ──────────────────────────────────────────────────────────────
    elif stype == "section":
        r.append(bg_req(slide_id, NAVY))
        r.extend(make_rect(slide_id, uid(), 0, 0, 6, 405, ACCENT))
        r.extend(make_textbox(slide_id, uid(), "CONTENTS",
                               20, 18, 200, 22,
                               font_size=9, bold=True, color=ACCENT))
        r.extend(make_textbox(slide_id, uid(), sd["title"],
                               20, 40, 680, 46,
                               font_size=26, bold=True, color=WHITE))
        r.extend(make_rect(slide_id, uid(), 20, 90, 680, 1, DGREY))
        body = "\n".join(sd.get("bullets", []))
        r.extend(make_textbox(slide_id, uid(), body,
                               20, 100, 680, 295,
                               font_size=14.5, bold=False, color=WHITE,
                               line_spacing=158))

    # ── CASE (판례 박스 스타일) ───────────────────────────────────────────────
    elif stype == "case":
        r.append(bg_req(slide_id, CASE_BG))
        r.extend(make_rect(slide_id, uid(), 0, 0, 720, 54, NAVY))
        r.extend(make_rect(slide_id, uid(), 0, 0, 5, 54, ACCENT))
        r.extend(make_textbox(slide_id, uid(), sd["title"],
                               14, 8, 690, 40,
                               font_size=18, bold=True, color=WHITE))
        # 판례 label bar
        r.extend(make_rect(slide_id, uid(), 24, 60, 672, 22, CASE_LBG))
        r.extend(make_rect(slide_id, uid(), 24, 60, 4, 22, CASE_ACCENT))
        r.extend(make_textbox(slide_id, uid(),
                               sd.get("case_label", "판례"),
                               32, 63, 660, 16,
                               font_size=9, bold=True, color=CASE_ACCENT))
        # Content
        body = "\n".join(sd.get("bullets", []))
        r.extend(make_textbox(slide_id, uid(), body,
                               24, 87, 672, 308,
                               font_size=11, bold=False, color=NAVY,
                               line_spacing=134))
        r.extend(make_textbox(slide_id, uid(), str(num),
                               686, 390, 28, 14,
                               font_size=8, bold=False, color=DGREY))

    # ── CONTENT (with or without callout box) ────────────────────────────────
    else:
        has_box = "box" in sd
        r.append(bg_req(slide_id, WHITE))
        r.extend(make_rect(slide_id, uid(), 0, 0, 720, 54, NAVY))
        r.extend(make_rect(slide_id, uid(), 0, 0, 5, 54, ACCENT))
        r.extend(make_textbox(slide_id, uid(), sd["title"],
                               14, 8, 690, 40,
                               font_size=18, bold=True, color=WHITE))

        body = "\n".join(sd.get("bullets", []))
        if has_box:
            # Shorter bullet area + callout box at bottom
            r.extend(make_textbox(slide_id, uid(), body,
                                   24, 62, 672, 170,
                                   font_size=11.5, bold=False, color=NAVY,
                                   line_spacing=143))
            box = sd["box"]
            r.extend(make_callout_box(
                slide_id, 24, 240, 672, 152,
                box["label"], box["text"], box["style"]
            ))
        else:
            r.extend(make_textbox(slide_id, uid(), body,
                                   24, 62, 672, 330,
                                   font_size=11.5, bold=False, color=NAVY,
                                   line_spacing=143))

        r.extend(make_textbox(slide_id, uid(), str(num),
                               686, 390, 28, 14,
                               font_size=8, bold=False, color=DGREY))
    return r


# ── main ──────────────────────────────────────────────────────────────────────
def main():
    print("Creating presentation…")
    pres = api_post(SLIDES_API,
                    {"title": "개인정보 유출에 따른 손해배상 책임 — 중앙대 특강 v2"})
    pres_id = pres["presentationId"]
    print(f"  ID: {pres_id}")

    first_id = pres["slides"][0]["objectId"]
    existing = [el["objectId"]
                for el in pres["slides"][0].get("pageElements", [])]

    # Delete defaults + duplicate first slide N-1 times
    init_reqs = [{"deleteObject": {"objectId": oid}} for oid in existing]
    new_ids = []
    for i in range(1, N):
        sid = uid()
        new_ids.append(sid)
        init_reqs.append({
            "duplicateObject": {"objectId": first_id,
                                "objectIds": {first_id: sid}}
        })
    batch(pres_id, init_reqs)

    pres_full = api_get(f"{SLIDES_API}/{pres_id}")
    all_ids = [s["objectId"] for s in pres_full["slides"]]
    print(f"  Total slides: {len(all_ids)}")

    # Remove any inherited elements on duplicated slides
    del_reqs = []
    for i, slide in enumerate(pres_full["slides"]):
        if i == 0:
            continue
        for el in slide.get("pageElements", []):
            del_reqs.append({"deleteObject": {"objectId": el["objectId"]}})
    if del_reqs:
        batch(pres_id, del_reqs)

    # Build all slide content
    all_reqs = []
    for idx, (sid, sd) in enumerate(zip(all_ids, slides_data)):
        all_reqs.extend(build_slide(sid, sd, idx))

    batch(pres_id, all_reqs)

    url = f"https://docs.google.com/presentation/d/{pres_id}/edit"
    print(f"\n✅ Done:\n  {url}\n")

if __name__ == "__main__":
    main()
