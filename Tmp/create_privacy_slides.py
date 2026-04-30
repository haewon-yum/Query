#!/usr/bin/env python3
"""
Create Google Slides: 개인정보 유출에 따른 손해배상 책임
중앙대 특강 — 류승균
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
DRIVE_API  = "https://www.googleapis.com/drive/v3/files"

def api_post(url, body):
    r = requests.post(url, headers=HEADERS, json=body)
    if not r.ok:
        print("ERROR:", r.status_code, r.text[:600])
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
NAVY   = {"red": 0.067, "green": 0.180, "blue": 0.373}
WHITE  = {"red": 1.0,   "green": 1.0,   "blue": 1.0}
LGREY  = {"red": 0.933, "green": 0.941, "blue": 0.953}
ACCENT = {"red": 0.941, "green": 0.498, "blue": 0.141}
DGREY  = {"red": 0.45,  "green": 0.45,  "blue": 0.45}

def uid():
    return "x" + uuid.uuid4().hex[:12]

def solid(c):
    """For backgrounds/fills: solidFill format"""
    return {"solidFill": {"color": {"rgbColor": c}}}

def opaque(c):
    """For text foreground color: opaqueColor format"""
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

# ── slide content ─────────────────────────────────────────────────────────────
slides_data = [
    {"type": "title",
     "title": "개인정보 유출에 따른\n손해배상 책임",
     "subtitle": "법과 판례, 그리고 실무상 쟁점\n\n류승균  |  중앙대학교 특강"},

    {"type": "section", "title": "강의 순서",
     "bullets": [
         "① 들어가면서 — 배경과 강의 범위",
         "② 일반 손해배상 vs 개인정보 손해배상",
         "③ 현행법상 개인정보 손해배상 제도",
         "    • 고의·과실 입증책임 전환",
         "    • 법정손해배상",
         "    • 징벌적 손해배상",
         "④ 법정손해배상 개정안 (2026년)",
         "⑤ 최근 논의 — 집단소송 · 동의의결 · 과징금 피해구제",
         "⑥ 나가면서",
     ]},

    {"type": "content", "title": "들어가면서",
     "bullets": [
         "최근 SKT·쿠팡 등 대규모 개인정보 유출 → 기업 법적 리스크 급증",
         "2026년 2월 개인정보 보호법 개정안 통과",
         "  개인정보보호위원회, 손해배상 제도 추가 개정 추진 중",
         "",
         "개인정보 유출 시 법적 책임 두 가지",
         "  (i)  행정상 제재 — 개보위 시정명령·과징금",
         "  (ii) 손해배상 — 피해자의 민사소송  ← 오늘의 주제",
         "",
         "목표: 법정 경험 없는 기업 담당자도 이해할 수 있도록",
     ]},

    {"type": "content", "title": "일반 손해배상 vs 개인정보 손해배상",
     "bullets": [
         "민법 제750조 — 일반 손해배상 4대 요건 (원고가 입증)",
         "  ① 고의 또는 과실   ② 위법행위",
         "  ③ 손해 (손해액)    ④ 인과관계",
         "",
         "개인정보 유출 사건의 특수성",
         "  • 원고: 개인  vs  피고: 대규모 기업",
         "  • 입증 자료는 대부분 피고 측에 집중",
         "  • 손해액 산정 어려움 (대부분 위자료)",
         "",
         "→ 개인정보보호법 특칙 3종",
         "    입증책임 전환 · 법정손해배상 · 징벌적 손해배상",
     ]},

    {"type": "content", "title": "현행법 — 개인정보 손해배상 개괄",
     "bullets": [
         "근거: 개인정보보호법 제39조 제1항",
         "위법성 기준: 개인정보보호법 위반 여부",
         "  (옥션 사건 — 법상 보호조치 준수 시 위법하지 않음)",
         "",
         "손해 발생 필요",
         "  → 유출 발생만으로 손해가 자동 성립하는 것은 아님",
         "  → 대법원 GS칼텍스 사건: 저장매체 즉시 폐기·압수",
         "     → 위자료 배상할 만한 정신적 손해 발생 어렵다 판단",
         "",
         "기타 요건: 인과관계, 고의·과실 (아래에서 별도 검토)",
     ]},

    {"type": "content", "title": "정신적 손해 발생 여부 — 대법원 판단 기준 (7가지)",
     "bullets": [
         "① 유출된 개인정보의 종류와 성격",
         "② 정보주체 식별 가능성 발생 여부",
         "③ 제3자 열람 여부 또는 열람 가능성",
         "④ 유출 정보의 확산 범위",
         "⑤ 추가적인 법익침해 가능성",
         "⑥ 개인정보 관리 실태 및 유출 경위",
         "⑦ 피해 확산 방지를 위한 사후 조치",
         "",
         "→ 7가지 사정을 종합하여 구체적 사건별 개별 판단",
     ]},

    {"type": "content", "title": "고의·과실 입증책임 전환",
     "bullets": [
         "과실 = 주의의무 위반 ≒ 안전조치 의무 위반 (개인정보보호법 제29조)",
         "",
         "일반 원칙: 피해자(원고)가 과실 입증",
         "  → 유출 사건에서 매우 어려움 (증거는 피고 측에 집중)",
         "",
         "개인정보보호법 특칙",
         "  → 입증책임을 개인정보처리자(피고)에게 전환",
         "  → 처리자가 무과실을 입증하지 못하면 배상 의무",
         "",
         "실무적 의미",
         "  기업은 안전조치 이행 증거를 사전에 체계적으로 확보해야 함",
     ]},

    {"type": "content", "title": "법정손해배상",
     "bullets": [
         "개념: 손해배상 요건·효과를 법률로 미리 정한 제도",
         "  (미국 영향, 카드3사 유출 사건 계기로 2015년 도입)",
         "",
         "해석 논쟁",
         "  [전자] 손해액만 법정 → 손해 발생은 여전히 입증 필요",
         "  [후자] 손해까지 법정 → 유출 사실만 입증하면 충분",
         "",
         "최근 대법원 판결",
         "  → 후자에 가까운 입장 (손해 요건 제외)",
         "  → 단, 실제 손해가 없으면 면책 가능",
         "",
         "개인당 배상액: 통상 10~30만 원 (위자료 중심)",
     ]},

    {"type": "content", "title": "징벌적 손해배상",
     "bullets": [
         "연혁: 2016년 3배 도입 → 2023년 5배로 상향",
         "",
         "추가 요건 (일반 손해배상과 비교)",
         "  • 고의 또는 중대한 과실 (경과실 제외)",
         "  • 개인정보 유출 등 특히 심각한 침해",
         "",
         "실효성 문제",
         "  • 도입 이후 법원 선고 사례 사실상 없음",
         "  • 개인정보 유출은 대부분 과실에 의함",
         "    → 고의·중과실 요건 충족 어려움",
         "",
         "배상액 산정 고려: 인식 정도, 피해 규모, 개인정보 회수 노력 등",
     ]},

    {"type": "content", "title": "법정손해배상 개정안 (2026년)",
     "bullets": [
         "발의: 박범계 의원 대표발의 (2026. 2. 12.)",
         "개정이유: 현행 요건 엄격 → 실효적 피해구제 어려움",
         "",
         "핵심 변경",
         "  • '고의 또는 과실로 인하여' 삭제 (제39조의2 제1항)",
         "  • 유출 발생 시 처리자의 배상 책임 원칙 명문화",
         "  • 면책 사유 명문화: 안전성 확보 조치를 다한 경우 등",
         "    (책임 없는 사유 = 고의·과실 없는 경우 → 과실책임 유지)",
         "",
         "인과관계 요부?  '인하여' 삭제 → 요구되지 않는 것으로 해석",
         "효과: 처리자 법적 안정성 제고  /  정보주체 입증 부담 경감",
     ]},

    {"type": "content", "title": "최근 논의 ① — 집단소송 도입",
     "bullets": [
         "개인정보 유출 피해의 특징: 소액·다수",
         "  → 개별 배상액 10~30만 원  vs  피해자 수천만 명",
         "",
         "현행 문제",
         "  → 개인이 소송 제기할 유인 없음 (배보다 배꼽)",
         "  → 실체적 권리는 갖춰졌으나 절차적 개선 부재",
         "",
         "집단소송 (Class Action)",
         "  • 미국 발달 / 우리나라 증권관련 집단소송법 선례",
         "  • 유럽 소비자집단소송지침으로 대륙 각국도 도입 확산",
         "  • 개인정보 분야 도입 필요성 논의 진행 중",
     ]},

    {"type": "content", "title": "최근 논의 ② — 동의의결 도입",
     "bullets": [
         "개념: 규제기관-피심인 합의로",
         "  위법행위 중지·피해구제·예방 등을 포함하여 사건 종결",
         "  (미국 독점금지법 consent order 모델; 2011년 공정거래법 도입)",
         "",
         "장점",
         "  • 사건별 필요한 조치를 탄력적으로 설계 가능",
         "  • 현행 시정명령(소극적 시정)과 달리 예방 조치 포함",
         "  • 과징금(국고 귀속)과 달리 피해자 직접 구제 가능",
         "",
         "개인정보보호법에 동의의결 제도 도입 논의 중",
     ]},

    {"type": "content", "title": "최근 논의 ③ — 과징금 수입으로 피해 구제",
     "bullets": [
         "현행: 개인정보 유출 과징금 → 전액 국고 귀속",
         "  → 피해자 구제로 직접 연결되지 않음",
         "",
         "개선 방향: 법률 특례로 과징금을 기금에 귀속 → 피해 구제 활용",
         "",
         "타 법률 입법례",
         "  기금 귀속: 신에너지법, 식품위생법 등",
         "  목적 특정: 저작권법, 청소년보호법 등",
         "",
         "논거",
         "  개인정보 유출 과징금은 권리 침해 피해자 존재를 전제",
         "  → 과징금을 피해자를 위해 사용하는 것이 타당",
     ]},

    {"type": "content", "title": "나가면서",
     "bullets": [
         "손해배상의 두 기능",
         "  • 전보: 피해자 손해 회복",
         "  • 예방: 잠재적 침해자의 행동 억제",
         "    (비재산적 손해에서 예방 기능이 특히 중요)",
         "",
         "현행법 평가",
         "  → 실체적 특칙은 갖춰졌으나",
         "     정보주체 보호와 예방 기능이 충분히 작동하지 않음",
         "",
         "요구되는 제도 개선 세 가지",
         "  ① 법정손해배상 제도 개선",
         "  ② 집단적 손해배상 제도 도입",
         "  ③ 동의의결 및 피해구제 기금 제도 도입",
     ]},
]

N = len(slides_data)  # 15 slides

# ── request builders ──────────────────────────────────────────────────────────
def make_textbox(page_id, obj_id, text, x, y, w, h,
                 font_size=13, bold=False, color=None,
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
            "shapeProperties": {
                "shapeBackgroundFill": solid(fill_color),
            },
            "fields": "shapeBackgroundFill",
        }},
    ]

def bg_req(page_id, color):
    return {"updatePageProperties": {
        "objectId": page_id,
        "pageProperties": {"pageBackgroundFill": solid(color)},
        "fields": "pageBackgroundFill",
    }}

def build_slide(slide_id, sd, num):
    r = []
    stype = sd["type"]

    if stype == "title":
        r.append(bg_req(slide_id, NAVY))
        r.extend(make_rect(slide_id, uid(), 0, 0, 720, 8, ACCENT))
        r.extend(make_textbox(slide_id, uid(), sd["title"],
                               50, 90, 620, 160,
                               font_size=34, bold=True, color=WHITE,
                               line_spacing=125, align="CENTER"))
        r.extend(make_rect(slide_id, uid(), 200, 258, 320, 2, ACCENT))
        r.extend(make_textbox(slide_id, uid(), sd["subtitle"],
                               50, 268, 620, 100,
                               font_size=14, bold=False, color=LGREY,
                               line_spacing=145, align="CENTER"))

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
                               font_size=15, bold=False, color=WHITE,
                               line_spacing=158))

    else:  # content
        r.append(bg_req(slide_id, WHITE))
        r.extend(make_rect(slide_id, uid(), 0, 0, 720, 54, NAVY))
        r.extend(make_rect(slide_id, uid(), 0, 0, 5, 54, ACCENT))
        r.extend(make_textbox(slide_id, uid(), sd["title"],
                               14, 8, 690, 40,
                               font_size=18, bold=True, color=WHITE))
        body = "\n".join(sd.get("bullets", []))
        r.extend(make_textbox(slide_id, uid(), body,
                               24, 62, 670, 330,
                               font_size=13, bold=False, color=NAVY,
                               line_spacing=150))
        r.extend(make_textbox(slide_id, uid(), str(num),
                               686, 390, 28, 14,
                               font_size=8, bold=False, color=DGREY))
    return r

# ── main ──────────────────────────────────────────────────────────────────────
def main():
    print("Creating presentation…")
    pres = api_post(SLIDES_API, {"title": "개인정보 유출에 따른 손해배상 책임 — 중앙대 특강"})
    pres_id = pres["presentationId"]
    print(f"  ID: {pres_id}")

    first_id = pres["slides"][0]["objectId"]
    # Remove default placeholder objects
    existing = [el["objectId"] for el in pres["slides"][0].get("pageElements", [])]
    if existing:
        batch(pres_id, [{"deleteObject": {"objectId": oid}} for oid in existing])

    # Duplicate first slide N-1 times to get N total slides
    dup_reqs = [{"duplicateObject": {"objectId": first_id}} for _ in range(N - 1)]
    result = api_post(f"{SLIDES_API}/{pres_id}:batchUpdate", {"requests": dup_reqs})

    # Fetch updated presentation to get all slide IDs in order
    pres_full = api_get(f"{SLIDES_API}/{pres_id}")
    all_ids = [s["objectId"] for s in pres_full["slides"]]
    print(f"  Total slides: {len(all_ids)}")

    # Delete placeholder elements on duplicated slides (they inherit from first)
    del_reqs = []
    for i, slide in enumerate(pres_full["slides"]):
        if i == 0:
            continue
        for el in slide.get("pageElements", []):
            del_reqs.append({"deleteObject": {"objectId": el["objectId"]}})
    if del_reqs:
        batch(pres_id, del_reqs)

    # Build content
    all_reqs = []
    for idx, (sid, sd) in enumerate(zip(all_ids, slides_data)):
        all_reqs.extend(build_slide(sid, sd, idx))

    batch(pres_id, all_reqs)

    url = f"https://docs.google.com/presentation/d/{pres_id}/edit"
    print(f"\n Done:\n  {url}\n")

if __name__ == "__main__":
    main()
