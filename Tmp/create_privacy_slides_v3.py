#!/usr/bin/env python3
"""
Google Slides v3: 개인정보 유출에 따른 손해배상 책임
Changes vs v2:
  - 판례 원문 박스 (사각 박스 with verbatim court text)
  - 모든 본문에 bullet 기호 (• / – 2단계)
  - 본문 최소 16pt
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
ACCENT      = {"red": 0.941, "green": 0.498, "blue": 0.141}
DGREY       = {"red": 0.45,  "green": 0.45,  "blue": 0.45}
CASE_BG     = {"red": 0.93,  "green": 0.96,  "blue": 1.0}
CASE_ACCENT = {"red": 0.20,  "green": 0.45,  "blue": 0.80}
CASE_LBG    = {"red": 0.87,  "green": 0.92,  "blue": 0.98}
QA_BG       = {"red": 1.0,   "green": 0.96,  "blue": 0.83}
QA_ACCENT   = {"red": 0.80,  "green": 0.50,  "blue": 0.05}
NOTE_BG     = {"red": 0.94,  "green": 0.94,  "blue": 0.97}
NOTE_ACCENT = {"red": 0.35,  "green": 0.50,  "blue": 0.70}

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

# ── primitives ────────────────────────────────────────────────────────────────
def make_textbox(page_id, obj_id, text, x, y, w, h,
                 font_size=16, bold=False, color=None,
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

def make_callout(page_id, x, y, w, h, label, text, style):
    """Styled callout box: bg + left accent + label + content"""
    MAP = {
        "qa":   (QA_BG,    QA_ACCENT,    NAVY),
        "case": (CASE_LBG, CASE_ACCENT,  NAVY),
        "note": (NOTE_BG,  NOTE_ACCENT,  {"red":0.12,"green":0.18,"blue":0.32}),
    }
    bg_c, acc_c, txt_c = MAP[style]
    reqs = []
    reqs.extend(make_rect(page_id, uid(), x, y, w, h, bg_c))
    reqs.extend(make_rect(page_id, uid(), x, y, 5, h, acc_c))
    reqs.extend(make_textbox(page_id, uid(), label,
                              x+11, y+6, w-15, 17,
                              font_size=9.5, bold=True, color=acc_c))
    reqs.extend(make_textbox(page_id, uid(), text,
                              x+11, y+25, w-15, h-30,
                              font_size=12, bold=False, color=txt_c,
                              line_spacing=140))
    return reqs

# ── bullet helpers ────────────────────────────────────────────────────────────
B1 = "• "          # level-1 bullet
B2 = "    – "      # level-2 bullet (4-space indent + dash)

def b(*items):
    """Join bullet items. Each item is str (level-1) or ("–", str) (level-2)."""
    lines = []
    for item in items:
        if isinstance(item, tuple):
            lines.append(B2 + item[1])
        else:
            lines.append(B1 + item)
    return "\n".join(lines)

# ── slide content ─────────────────────────────────────────────────────────────
# Slide dimensions: 720 × 405 PT (16:9)
# Layout:
#   Title/Section slides   — dark background
#   Content slides         — white bg, NAVY header bar (0-54), body (62, h≤330)
#   Content-with-box       — body (62, h=162), callout box (230, h=164)
#   Case slides            — light-blue bg, NAVY header, white inner box (58-398)

slides_data = [

    # ── 0. TITLE ─────────────────────────────────────────────────────────────
    {
        "type": "title",
        "title": "개인정보 유출에 따른\n손해배상 책임",
        "subtitle": "법과 판례, 그리고 실무상 쟁점\n\n류승균  |  중앙대학교 특강",
    },

    # ── 1. 강의 순서 ──────────────────────────────────────────────────────────
    {
        "type": "section",
        "title": "강의 순서",
        "body": b(
            "들어가면서 — 최근 유출 사건 배경과 강의 목적",
            "일반 손해배상 vs 개인정보 손해배상 — 특수성과 특칙",
            "현행법상 개인정보 손해배상 제도",
            ("–", "고의·과실 입증책임 전환"),
            ("–", "법정손해배상"),
            ("–", "징벌적 손해배상"),
            "법정손해배상 개정안 (2026년)",
            "최근 논의 — 집단소송 · 동의의결 · 과징금 피해구제",
            "나가면서",
        ),
    },

    # ── 2. 들어가면서 ─────────────────────────────────────────────────────────
    {
        "type": "content",
        "title": "들어가면서",
        "body": b(
            "최근 SKT·쿠팡 등 대규모 개인정보 유출 사건이 잇따르면서 기업의 법적 리스크가 그 어느 때보다 높아졌음. 개인정보 유출 문제는 2014년 카드3사 사건이 본격적 계기였으나, 이후에도 수시로 발생하고 있음.",
            "국회는 2026년 2월 개인정보 보호법 개정안을 통과시켰고, 개인정보보호위원회(개보위)는 손해배상 제도 등 추가 개정을 국회와 함께 추진 중. 입법·행정 양측에서 기업의 법적 책임 강화 추세가 뚜렷함.",
            "개인정보 유출 시 법적 책임은 크게 두 가지:",
            ("–", "(i)  행정상 제재 — 개보위 시정명령·과징금"),
            ("–", "(ii) 손해배상 — 피해자의 민사소송  ← 오늘의 주제"),
            "강의 목표: 법정 경험 없는 기업 담당자도 이해할 수 있도록, 민법·민사소송법 선행 지식 없이 설명함.",
        ),
    },

    # ── 3. 일반 vs 개인정보 손해배상  +  Q&A box ─────────────────────────────
    {
        "type": "content+box",
        "title": "일반 손해배상 vs 개인정보 손해배상",
        "body": b(
            "민법 제750조 — 일반 손해배상 4대 요건 (원고가 입증):",
            ("–", "① 고의 또는 과실  ② 위법행위  ③ 손해(손해액)  ④ 인과관계"),
            "개인정보 유출 사건의 특수성:",
            ("–", "입증 자료 대부분 피고(기업) 측에 집중"),
            ("–", "손해 대부분 정신적 손해(위자료) — 금액 산정 어려움"),
            ("–", "원고는 개인, 피고는 대규모 기업"),
            "개인정보보호법 특칙 3종: 입증책임 전환 · 법정손해배상 · 징벌적 손해배상(최대 5배)",
        ),
        "box": {
            "style": "qa",
            "label": "Q&A",
            "text": (
                "Q.  손해배상은 소송 제기로만 가능한지?\n\n"
                "A.  그렇진 않음. 손해가 발생하면 바로 배상 책임이 인정되므로, 원론적으로 소송이 필요한 건 아님. "
                "피해자가 전화/이메일/고객센터 연락/내용증명 발송 등으로 손해배상을 요구할 수 있음. "
                "그러나 개인정보 유출 사건에서는 손해배상 요건의 충족 여부가 논란이 되는 경우가 많아서, "
                "대부분 소송으로 진행됨."
            ),
        },
    },

    # ── 4. 현행법 개괄 ────────────────────────────────────────────────────────
    {
        "type": "content",
        "title": "현행법 — 개인정보 손해배상 개괄",
        "body": b(
            "근거: 개인정보보호법 제39조 제1항. 위법성·유책성 판단 기준 = 개인정보보호법 위반 여부.",
            ("–", "대법원 옥션 사건 — '법상 보호조치를 다하였다면 특별한 사정이 없는 한 위법하다고 볼 수 없다'"),
            "손해 발생이 필요 — 유출 발생만으로 손해가 자동 성립하는 것은 아님.",
            ("–", "대법원 GS칼텍스 사건: 저장매체 즉시 폐기·압수된 경우 → \"위자료로 배상할 만한 정신적 손해가 발생하였다고 보기는 어렵다\" 판시"),
            "기타 요건: 인과관계·고의·과실. 단, 고의·과실은 입증책임이 전환되어 처리자(피고)가 무과실을 증명해야 함.",
            "정신적 손해 발생 여부의 판단 기준 — 대법원이 제시한 7가지 요소 (다음 슬라이드 참조)",
        ),
    },

    # ── 5. 판례 기준 7가지 (CASE — 원문 박스) ───────────────────────────────
    {
        "type": "case",
        "title": "정신적 손해 발생 여부 — 대법원 판례 기준",
        "case_label": "판례  |  대법원 GS칼텍스 사건  —  아래 7가지 사정을 종합적으로 고려하여 구체적 사건에 따라 개별적으로 판단하여야 함",
        "body": (
            "(i)   유출된 개인정보의 종류와 성격이 무엇인지,\n"
            "(ii)  개인정보의 유출로 정보주체를 식별할 가능성이 발생하였는지,\n"
            "(iii) 제3자가 유출된 개인정보를 열람하였는지 또는 제3자의 열람 여부가 밝혀지지 않았다면\n"
            "      제3자의 열람 가능성이 있었거나 앞으로 그 열람 가능성이 있는지,\n"
            "(iv)  유출된 개인정보가 어느 범위까지 확산되었는지,\n"
            "(v)   개인정보의 유출로 추가적인 법익침해의 가능성이 발생하였는지,\n"
            "(vi)  개인정보를 처리하는 자가 개인정보를 관리해온 실태와\n"
            "      개인정보가 유출된 구체적인 경위는 어떠한지,\n"
            "(vii) 개인정보의 유출로 인한 피해의 발생 및 확산을 방지하기 위하여\n"
            "      어떠한 조치가 취하여졌는지"
        ),
    },

    # ── 6. 입증책임 전환 ─────────────────────────────────────────────────────
    {
        "type": "content",
        "title": "고의·과실 입증책임 전환",
        "body": b(
            "개인정보 유출 사건에서 '과실' = 사회생활상 주의의무 위반 ≈ 안전조치 의무 위반 (법 제29조). 실무상 두 개념은 거의 동일하게 해석됨.",
            "일반 원칙: 피해자(원고)가 가해자의 과실을 직접 입증해야 함.",
            ("–", "개인정보 유출 사건에서는 입증 자료가 피고 측에 집중 → 원고의 입증이 사실상 매우 어려움"),
            "개인정보보호법 특칙: 입증책임을 개인정보처리자(피고)에게 전환.",
            ("–", "처리자가 '과실 없음'을 스스로 입증하지 못하면 배상 의무 인정"),
            "실무적 의미: 기업은 안전조치 이행 내역 (접근 통제·암호화·취약점 점검 등)을 사전에 체계적으로 기록·보관해야 함. 소송 시 무과실 항변의 핵심 증거가 됨.",
        ),
    },

    # ── 7. 법정손해배상 ──────────────────────────────────────────────────────
    {
        "type": "content",
        "title": "법정손해배상",
        "body": b(
            "미국 statutory damages 제도 영향, 카드3사 사건 계기로 2015년 도입. 손해배상의 요건·효과를 법률로 미리 정하는 것.",
            "해석 논쟁 — '손해액만 법정'인지 '손해까지 법정'인지:",
            ("–", "[전자] 손해 발생 입증 여전히 필요 — 미국 제도 본래 의미 기준"),
            ("–", "[후자] 유출 사실만으로 충분 — 제39조의2 제1항에 '손해' 요건 없음 (법 문언)"),
            "최근 대법원 판결: 후자(손해의 법정)에 가까운 입장 취함.",
            ("–", "단, 손해가 없으면 면책 가능 → 완전한 자동 성립론은 아님"),
            "개인당 배상액: 통상 10~30만 원 (위자료 중심)",
        ),
    },

    # ── 8. 징벌적 손해배상  +  보충 설명 box ─────────────────────────────────
    {
        "type": "content+box",
        "title": "징벌적 손해배상",
        "body": b(
            "연혁: 2016년 3배 도입 → 2023년 5배 상향. 종래 '손해 전보' 중심 법체계에 예방 기능을 추가한 제도.",
            "추가 요건: '고의 또는 중대한 과실' + '개인정보 유출 등' 심각한 침해 유형.",
            ("–", "개인정보 유출 대부분이 과실에 의함 → 고의·중과실 요건 충족이 현실적으로 매우 어려움"),
            "실효성 문제: 도입 이후 징벌적 손해배상 선고 사례 사실상 없음.",
            ("–", "배상액 결정 시: ① 고의·우려 인식 정도, ② 피해 규모, ③ 개인정보 회수 노력 등 종합 고려"),
        ),
        "box": {
            "style": "note",
            "label": "보충 설명",
            "text": (
                "하급심은 정신적 손해에는 성격상 징벌적 손해배상이 적용되지 아니한다고 한 바 있음. "
                "그러나 이러한 판단은 타당하지 않음. (i) 징벌적 손해배상 규정은 그 대상을 '손해'라고 하고, "
                "(ii) 손해에는 재산적인 손해뿐 아니라 정신적인 손해(위자료)도 포함된다는 것에 이견이 없으며, "
                "(iii) 개인정보 손해배상의 대부분이 위자료 청구인데 법은 위자료를 배제하는 규정을 두지 않았음. "
                "위자료를 자의적으로 배제하는 것은 징벌적 손해배상 제도 도입 취지를 몰각시키는 것임."
            ),
        },
    },

    # ── 9. 법정손해배상 개정안  +  보충 해석 box ─────────────────────────────
    {
        "type": "content+box",
        "title": "법정손해배상 개정안 (2026년)",
        "body": b(
            "발의: 박범계 의원 대표발의 (2026. 2. 12.). '고의 또는 과실로 인하여' 및 인과관계('인하여') 문구 삭제. 개인정보 유출 시 처리자의 배상 책임을 원칙으로 명문화.",
            "면책 사유 명문화: '안전성 확보에 필요한 조치를 다한 경우' 등 '책임 없는 사유'가 있으면 면책.",
            ("–", "'책임 없는 사유' = 고의·과실 없는 경우 → 무과실책임이 아님, 과실책임 구조 유지"),
            "효과: 정보주체 — 입증 부담 경감 / 개인정보처리자 — 면책 요건 명문화로 법적 안정성 제고",
        ),
        "box": {
            "style": "note",
            "label": "보충 해석",
            "text": (
                "개인정보 유출 사건에서는 사실상 고의가 문제되지 않으므로, 과실에 초점을 맞추고 이를 주의의무 위반으로 새긴다면, "
                "해당 규정은 과실 판단 기준이 되는 주의의무를 법 제29조상 안전조치 의무로 명확히 한 것임. "
                "면책 요건을 명문의 규정으로 정함으로써 정보주체뿐만 아니라 개인정보처리자 역시 "
                "보다 명확한 규정에 따라 법적안정성을 누릴 수 있게 됨."
            ),
        },
    },

    # ── 10. 집단소송 ─────────────────────────────────────────────────────────
    {
        "type": "content",
        "title": "최근 논의 ① — 집단소송 도입",
        "body": b(
            "개인정보 유출 손해배상 사건의 특징: 소액·다수.",
            ("–", "개별 배상액 통상 10~30만 원 (소액)  vs  피해자 수천만 명 (다수)"),
            "현행 제도의 문제: 피해자 개인이 소송 제기할 유인이 극히 낮음.",
            ("–", "법원 인지대 + 변호사 비용 > 배상액 ('배보다 배꼽')"),
            ("–", "실체적 권리는 갖춰졌으나 절차적 권리 구제 실질화가 부재"),
            "집단소송(Class Action): 다수 피해자가 대표 당사자를 통해 공동으로 소송 제기.",
            ("–", "우리나라 — 증권관련 집단소송법으로 이미 입법한 선례 있음"),
            ("–", "유럽 — 소비자집단소송지침에 따라 대륙 각국도 도입 확산"),
        ),
    },

    # ── 11. 동의의결 ─────────────────────────────────────────────────────────
    {
        "type": "content",
        "title": "최근 논의 ② — 동의의결 도입",
        "body": b(
            "동의의결: 규제기관과 피심인이 위법행위 중지·피해 구제·재발 방지 등을 합의하여 사건 종결하는 제도.",
            ("–", "미국 독점금지법 동의명령(consent order) 모델, 2011년 공정거래법에 도입"),
            "현행 시정조치와의 차이: 현행은 소극적 시정 명령에 그침.",
            ("–", "동의의결은 향후 예방 조치 등 적극적·탄력적 내용 설계 가능"),
            "피해 구제 연계 가능: 과징금(국고 귀속)과 달리, 피해자 직접 구제 내용 포함 가능.",
            ("–", "행정제재와 민사적 피해 구제를 연결하는 효과"),
        ),
    },

    # ── 12. 과징금 피해 구제 ──────────────────────────────────────────────────
    {
        "type": "content",
        "title": "최근 논의 ③ — 과징금 수입으로 피해 구제",
        "body": b(
            "현행 문제: 개인정보 유출 과징금 → 전액 국고 귀속. 피해자 정보주체에게 직접 구제 효과 없음.",
            "개선 방향: 법률 특례로 과징금을 특정 기금에 귀속 → 피해 구제에 활용.",
            "입법례:",
            ("–", "[기금 귀속] 신에너지법(전력산업기반기금), 식품위생법(식품진흥기금), 국민건강보험법(응급의료기금)"),
            ("–", "[목적 특정] 저작권법(이용 질서 확립), 청소년보호법(청소년 보호사업)"),
            "논거: 개인정보 유출 과징금(법 제64조의2 제1항 제9호)은 권리 침해 피해자 존재를 전제로 부과됨.",
            ("–", "→ 과징금을 피해자를 위해 사용하는 것이 제도적 정합성에 부합"),
        ),
    },

    # ── 13. 나가면서 ─────────────────────────────────────────────────────────
    {
        "type": "content",
        "title": "나가면서",
        "body": b(
            "손해배상의 두 기능:",
            ("–", "전보(塡補): 피해자 손해 회복"),
            ("–", "예방: 잠재적 침해자의 행동 억제 — 비재산적 손해(위자료)에서 예방 기능이 더욱 중요"),
            "현행법 평가: 실체적 특칙은 갖춰졌으나, 정보주체 권리 보호와 예방 기능이 충분히 작동하지 않음.",
            "세 가지 제도 개선이 절실히 요구됨:",
            ("–", "① 법정손해배상 제도 개선 — 2026년 개정안으로 입증 부담 경감"),
            ("–", "② 집단소송 도입 — 소액·다수 피해의 절차적 권리 구제 실질화"),
            ("–", "③ 동의의결 및 피해구제 기금 도입 — 행정제재와 민사 구제의 연계"),
        ),
    },
]

N = len(slides_data)  # 14

# ── slide builder ─────────────────────────────────────────────────────────────
# Slide = 720 × 405 PT
# Header bar: y=0, h=54
# Body (no box): y=62, h=330
# Body (with box): y=62, h=162; box y=230, h=165

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
        r.extend(make_textbox(slide_id, uid(), sd["body"],
                               20, 100, 680, 295,
                               font_size=15, bold=False, color=WHITE,
                               line_spacing=155))

    # ── CASE (판례 원문 박스) ─────────────────────────────────────────────────
    elif stype == "case":
        r.append(bg_req(slide_id, CASE_BG))
        # NAVY header
        r.extend(make_rect(slide_id, uid(), 0, 0, 720, 54, NAVY))
        r.extend(make_rect(slide_id, uid(), 0, 0, 5, 54, ACCENT))
        r.extend(make_textbox(slide_id, uid(), sd["title"],
                               14, 8, 690, 40,
                               font_size=18, bold=True, color=WHITE))
        # White 사각 박스 for 판례 원문
        r.extend(make_rect(slide_id, uid(), 20, 58, 680, 338, WHITE))
        r.extend(make_rect(slide_id, uid(), 20, 58, 5, 338, CASE_ACCENT))
        # 판례 label
        r.extend(make_textbox(slide_id, uid(), sd.get("case_label", "판례"),
                               30, 62, 666, 18,
                               font_size=9.5, bold=True, color=CASE_ACCENT))
        # Thin separator line
        r.extend(make_rect(slide_id, uid(), 30, 82, 660, 1, CASE_LBG))
        # Verbatim text
        r.extend(make_textbox(slide_id, uid(), sd["body"],
                               30, 86, 660, 302,
                               font_size=15, bold=False, color=NAVY,
                               line_spacing=150))
        r.extend(make_textbox(slide_id, uid(), str(num),
                               686, 390, 28, 14,
                               font_size=8, bold=False, color=DGREY))

    # ── CONTENT (no box) ─────────────────────────────────────────────────────
    elif stype == "content":
        r.append(bg_req(slide_id, WHITE))
        r.extend(make_rect(slide_id, uid(), 0, 0, 720, 54, NAVY))
        r.extend(make_rect(slide_id, uid(), 0, 0, 5, 54, ACCENT))
        r.extend(make_textbox(slide_id, uid(), sd["title"],
                               14, 8, 690, 40,
                               font_size=18, bold=True, color=WHITE))
        r.extend(make_textbox(slide_id, uid(), sd["body"],
                               20, 62, 680, 330,
                               font_size=16, bold=False, color=NAVY,
                               line_spacing=148))
        r.extend(make_textbox(slide_id, uid(), str(num),
                               686, 390, 28, 14,
                               font_size=8, bold=False, color=DGREY))

    # ── CONTENT + CALLOUT BOX ────────────────────────────────────────────────
    elif stype == "content+box":
        r.append(bg_req(slide_id, WHITE))
        r.extend(make_rect(slide_id, uid(), 0, 0, 720, 54, NAVY))
        r.extend(make_rect(slide_id, uid(), 0, 0, 5, 54, ACCENT))
        r.extend(make_textbox(slide_id, uid(), sd["title"],
                               14, 8, 690, 40,
                               font_size=18, bold=True, color=WHITE))
        # Shorter body
        r.extend(make_textbox(slide_id, uid(), sd["body"],
                               20, 62, 680, 158,
                               font_size=15, bold=False, color=NAVY,
                               line_spacing=143))
        # Callout box
        box = sd["box"]
        r.extend(make_callout(slide_id, 20, 228, 680, 166,
                               box["label"], box["text"], box["style"]))
        r.extend(make_textbox(slide_id, uid(), str(num),
                               686, 390, 28, 14,
                               font_size=8, bold=False, color=DGREY))

    return r


# ── main ──────────────────────────────────────────────────────────────────────
def main():
    print("Creating presentation v3…")
    pres = api_post(SLIDES_API,
                    {"title": "개인정보 유출에 따른 손해배상 책임 — 중앙대 특강"})
    pres_id = pres["presentationId"]
    print(f"  ID: {pres_id}")

    first_id = pres["slides"][0]["objectId"]
    existing = [el["objectId"]
                for el in pres["slides"][0].get("pageElements", [])]

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

    del_reqs = []
    for i, slide in enumerate(pres_full["slides"]):
        if i == 0:
            continue
        for el in slide.get("pageElements", []):
            del_reqs.append({"deleteObject": {"objectId": el["objectId"]}})
    if del_reqs:
        batch(pres_id, del_reqs)

    all_reqs = []
    for idx, (sid, sd) in enumerate(zip(all_ids, slides_data)):
        all_reqs.extend(build_slide(sid, sd, idx))

    batch(pres_id, all_reqs)

    url = f"https://docs.google.com/presentation/d/{pres_id}/edit"
    print(f"\n✅ Done:\n  {url}\n")

if __name__ == "__main__":
    main()
