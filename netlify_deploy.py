"""
netlify_deploy.py — vaax-infographic 파일 단위 배포 유틸리티
---------------------------------------------------------------
방식: SHA 기반 파일 단위 업로드 (ZIP 전체 교체 방식 대체)
효과: 다른 세션 파일 삭제 없음. 지정 파일만 추가·갱신.
사용법:
    python3 ~/Sites/ai-infographic/netlify_deploy.py SLUG [EXTRA_FILE ...]

예시:
    # 슬라이드 + index.html 배포
    python3 ~/Sites/ai-infographic/netlify_deploy.py 2026-05-04-my-slides-slides

    # 리포트 + index.html 배포
    python3 ~/Sites/ai-infographic/netlify_deploy.py 2026-05-04-my-report

인수:
    SLUG        파일명 (확장자 .html 제외). 이 파일 + index.html 을 배포.
    EXTRA_FILE  추가로 배포할 파일명 (선택, 복수 가능)

배포 원리:
    1. 지정 파일들의 SHA1 해시 계산
    2. Netlify에 deploy 생성 (digest 목록만 전송)
    3. Netlify가 "required" 목록으로 응답 — 캐시에 없는 파일만 요청
    4. required 파일만 PUT 업로드 → deploy 자동 완료
---------------------------------------------------------------
변경 이력:
    2026-05-04  최초 작성. ZIP 전체 교체 방식 대체.
"""

import json, os, sys, hashlib, glob, urllib.request

AUTH_TOKEN = "nfp_6vUcFn4XUKgxVm9Zmy25d9pLuCrXGTgLc63b"
SITE_NAME  = "vaax-infographic"
SITE_URL   = "https://vaax-infographic.netlify.app"

def get_ai_dir():
    candidates = sorted(glob.glob("/sessions/*/mnt/ai-infographic"))
    if candidates:
        return candidates[-1]
    # 로컬 실행 시 Mac 경로
    mac = os.path.expanduser("~/Sites/ai-infographic")
    if os.path.isdir(mac):
        return mac
    raise RuntimeError("ai-infographic 디렉터리 미발견 — 마운트 확인 필요")

def get_site_id():
    req = urllib.request.Request(
        "https://api.netlify.com/api/v1/sites",
        headers={"Authorization": f"Bearer {AUTH_TOKEN}"}
    )
    sites = json.loads(urllib.request.urlopen(req, timeout=15).read())
    vaax = next((s for s in sites if SITE_NAME in s.get("name", "")), None)
    if not vaax:
        raise RuntimeError(f"Netlify 사이트 '{SITE_NAME}' 미발견")
    return vaax["id"], vaax.get("ssl_url", SITE_URL)

def deploy_files(file_map: dict):
    """
    file_map: { "/netlify_path.html": "/local/absolute/path.html", ... }
    """
    site_id, site_url = get_site_id()

    # SHA1 계산
    file_digests = {}
    file_contents = {}
    for net_path, local_path in file_map.items():
        with open(local_path, "rb") as f:
            content = f.read()
        sha1 = hashlib.sha1(content).hexdigest()
        file_digests[net_path] = sha1
        file_contents[sha1] = (net_path, content)
        print(f"  SHA1 계산: {net_path} ({len(content)//1024}KB)")

    # Deploy 생성 (digest 목록 전송)
    body = json.dumps({"files": file_digests}).encode()
    req = urllib.request.Request(
        f"https://api.netlify.com/api/v1/sites/{site_id}/deploys",
        data=body,
        headers={"Authorization": f"Bearer {AUTH_TOKEN}", "Content-Type": "application/json"},
        method="POST"
    )
    deploy = json.loads(urllib.request.urlopen(req, timeout=30).read())
    deploy_id = deploy["id"]
    required  = deploy.get("required", [])
    print(f"[Deploy 생성] id={deploy_id}")
    print(f"[업로드 필요] {len(required)}개 / 전체 {len(file_digests)}개 (나머지는 Netlify 캐시 재사용)")

    # 필요한 파일만 업로드
    for sha1 in required:
        if sha1 not in file_contents:
            print(f"  경고: SHA1 {sha1[:8]}... 에 해당하는 로컬 파일 없음 — 스킵")
            continue
        net_path, content = file_contents[sha1]
        fname = net_path.lstrip("/")
        upload_req = urllib.request.Request(
            f"https://api.netlify.com/api/v1/deploys/{deploy_id}/files/{fname}",
            data=content,
            headers={
                "Authorization": f"Bearer {AUTH_TOKEN}",
                "Content-Type": "application/octet-stream"
            },
            method="PUT"
        )
        urllib.request.urlopen(upload_req, timeout=30)
        print(f"  업로드 완료: {fname}")

    print(f"[배포 완료]")
    for net_path in file_map:
        print(f"  {site_url}{net_path}")

    return site_url, deploy_id


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("사용법: python3 netlify_deploy.py SLUG [EXTRA_FILE ...]")
        print("예시:   python3 netlify_deploy.py 2026-05-04-my-slides-slides")
        sys.exit(1)

    slug = sys.argv[1]
    extra = sys.argv[2:]

    ai_dir = get_ai_dir()
    print(f"[AI_DIR] {ai_dir}")

    # 기본 배포 대상: 슬라이드/리포트 파일 + index.html
    targets = [f"{slug}.html", "index.html"] + extra
    file_map = {}
    for fname in targets:
        local_path = os.path.join(ai_dir, fname)
        if not os.path.exists(local_path):
            print(f"경고: {local_path} 미존재 — 스킵")
            continue
        file_map[f"/{fname}"] = local_path

    if not file_map:
        print("배포할 파일 없음")
        sys.exit(1)

    deploy_files(file_map)
