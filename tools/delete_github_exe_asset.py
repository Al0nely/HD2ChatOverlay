import sys
import json
import urllib.request
import subprocess

def get_git_credential():
    try:
        p = subprocess.Popen(['git', 'credential', 'fill'], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        out, err = p.communicate(input="url=https://github.com/Al0nely/HD2ChatOverlay.git\n")
        for line in out.splitlines():
            if line.startswith("password="):
                return line.split("password=", 1)[1].strip()
    except Exception as e:
        print(f"[Error] Reading git credential failed: {e}")
    return None

def main():
    token = get_git_credential()
    if not token:
        print("[Error] No GitHub API token found.")
        sys.exit(1)

    repo = "Al0nely/HD2ChatOverlay"
    tag = "v1.4.0"

    headers = {
        "Authorization": f"token {token}",
        "Accept": "application/vnd.github+json",
        "User-Agent": "HD2ChatOverlay-Delete-Tool"
    }

    # 1. 获取 Release ID
    get_url = f"https://api.github.com/repos/{repo}/releases/tags/{tag}"
    req = urllib.request.Request(get_url, headers=headers)
    try:
        with urllib.request.urlopen(req) as resp:
            data = json.loads(resp.read().decode('utf-8'))
            release_id = data.get("id")
    except Exception as e:
        print(f"[Error] Failed to fetch release {tag}: {e}")
        sys.exit(1)

    # 2. 列出并删除 HD2ChatOverlay.exe 附件
    list_assets_url = f"https://api.github.com/repos/{repo}/releases/{release_id}/assets"
    req_list = urllib.request.Request(list_assets_url, headers=headers)
    deleted = False
    try:
        with urllib.request.urlopen(req_list) as resp:
            assets = json.loads(resp.read().decode('utf-8'))
            for asset in assets:
                if asset.get("name") == "HD2ChatOverlay.exe":
                    asset_id = asset.get("id")
                    print(f"[Delete] Removing HD2ChatOverlay.exe (Asset ID: {asset_id})...")
                    del_url = f"https://api.github.com/repos/{repo}/releases/assets/{asset_id}"
                    del_req = urllib.request.Request(del_url, headers=headers, method="DELETE")
                    urllib.request.urlopen(del_req)
                    print("[Success] HD2ChatOverlay.exe removed successfully from GitHub release.")
                    deleted = True
    except Exception as e:
        print(f"[Error] Exception during asset deletion: {e}")

    if not deleted:
        print("[Info] HD2ChatOverlay.exe was not found in release assets.")

if __name__ == "__main__":
    main()
