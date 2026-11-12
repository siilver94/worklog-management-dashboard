"""
공개 저장소 push 전 민감정보 점검 스크립트

사용법 (저장소 루트에서):
    python3 tools/check_sensitive.py

검사 항목
  1) 이메일 주소 — example.com 이외 도메인이면 경고
  2) 따옴표 안의 한글 3글자 문자열 — 사람 이름일 가능성 (자리표시자·일반 용어는 허용 목록으로 제외)
  3) 로컬 전용 금지어 — tools/sensitive_terms.local.txt 에 한 줄에 하나씩
     (회사명, 실제 팀명, 실명 등. 이 파일은 .gitignore 되어 공개되지 않음)

경고가 1건이라도 있으면 종료 코드 1 → 0건일 때만 push.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SKIP_DIRS = {".git", "node_modules", "__pycache__"}
TEXT_EXT = {".md", ".txt", ".sql", ".powerfx", ".yaml", ".yml", ".json", ".py", ""}
LOCAL_TERMS = os.path.join(ROOT, "tools", "sensitive_terms.local.txt")

EMAIL = re.compile(r"[A-Za-z0-9._%+-]+@([A-Za-z0-9.-]+\.[A-Za-z]{2,})")
QUOTED_3 = re.compile(r"[\"']([가-힣]{3})[\"']")

# 이름처럼 보이지만 이름이 아닌 3글자 단어 (필요하면 추가)
ALLOW_3 = {
    "시작전", "진행중", "연구관리", "아니오", "업무일지", "대시보드", "프로젝트",
    "작업시간", "작업내용", "사용자", "개발자", "부문장", "팀장님", "오전반차", "오후반차",
    "기타업무", "원가절감", "기술개발", "제품개발", "설계변경", "작성자", "종료일", "시작일",
    "이번주", "진행률", "고정팀",
}
SURNAMES = set("김이박최정강조윤장임한오서신권황안송류홍전고문양손배백허유남심노하곽성차주우구민진나지엄채원천방공현함변염여추도소석선설마길연위표명기반왕금옥육인맹제모탁국어은편용")


def load_local_terms():
    if not os.path.exists(LOCAL_TERMS):
        return []
    with open(LOCAL_TERMS, encoding="utf-8") as f:
        return [ln.strip() for ln in f if ln.strip() and not ln.startswith("#")]


def iter_files():
    for d, dirs, files in os.walk(ROOT):
        dirs[:] = [x for x in dirs if x not in SKIP_DIRS]
        for name in files:
            path = os.path.join(d, name)
            if os.path.abspath(path) in (os.path.abspath(__file__), LOCAL_TERMS):
                continue
            if os.path.splitext(name)[1].lower() in TEXT_EXT:
                yield path


def main():
    terms = load_local_terms()
    hits = []
    for path in iter_files():
        rel = os.path.relpath(path, ROOT)
        try:
            lines = open(path, encoding="utf-8").read().splitlines()
        except (UnicodeDecodeError, OSError):
            continue
        for no, line in enumerate(lines, 1):
            for m in EMAIL.finditer(line):
                if m.group(1).lower() != "example.com":
                    hits.append((rel, no, "이메일", m.group(0)))
            for m in QUOTED_3.finditer(line):
                w = m.group(1)
                if w[0] in SURNAMES and w not in ALLOW_3:
                    hits.append((rel, no, "이름 의심", w))
            for term in terms:
                if term.lower() in line.lower():
                    hits.append((rel, no, "금지어", term))

    if not terms:
        print("ℹ️  tools/sensitive_terms.local.txt 가 없어 금지어 검사는 건너뜀")
    for rel, no, kind, val in hits:
        print(f"⚠️  {rel}:{no}  [{kind}] {val}")
    print(f"\n총 {len(hits)}건")
    sys.exit(1 if hits else 0)


if __name__ == "__main__":
    main()
