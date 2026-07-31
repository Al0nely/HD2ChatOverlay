import os
import sys
import json
import urllib.request
import urllib.parse
import urllib.error
import subprocess

def get_git_credential():
    try:
        p = subprocess.Popen(['git', 'credential', 'fill'], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        out, err = p.communicate(input="url=https://github.com/Al0nely/HD2ChatOverlay.git\n")
        for line in out.splitlines():
            if line.startswith("password="):
                return line.split("password=", 1)[1].strip()
    except Exception as e:
        print(f"[Error] 读取 git 凭据异常: {e}")
    return None

def main():
    token = get_git_credential()
    if not token:
        print("[Error] 无法获取 GitHub API Token，请确认 git 凭据已被记住。")
        sys.exit(1)

    repo = "Al0nely/HD2ChatOverlay"
    tag = "v1.4.1"
    release_name = "HD2 Chat Overlay v1.4.1 - 悬浮框文字对齐与偶发响应迟钝 Bug 修复"

    body = """# HD2 Chat Overlay v1.4.1 正式发布

### 🐛 Bug 修复与排版优化
- **悬浮框文字垂直居中与防截断算法**：动态适配字体尺寸，文字中轴与前缀标签中轴完美平齐，留出充足的底部下沉空间，彻底解决 `_` 下划线被边缘遮挡或文字偏高问题。
- **悬浮框偶发响应迟钝修复**：优化 ShellHook 监听逻辑，自动识别排除本程序多窗口与 IME 输入法事件，彻底杜绝悬浮窗被误关闭或 Enter 按键响应不及时。
- **翻译等待提示优化**：请求翻译时的悬浮框前缀由 `💬 [译中]` 优化为 `⏳ [译]`，避免右括号 `]` 截断并提供清晰等待反馈。
- **稳定性增强**：修复 Win32 属性调用顺序及多处交互边界细节。

---

### 发布附件下载
- `HD2ChatOverlay.exe`：独立编译单文件可执行程序 (解压或直接双击运行即可)
- `HD2ChatOverlay-v1.4.1.zip`：包含 README、CHANGELOG 及完整源码资产的 Release 压缩包
"""

    headers = {
        "Authorization": f"token {token}",
        "Accept": "application/vnd.github+json",
        "User-Agent": "HD2ChatOverlay-Release-Tool"
    }

    # 1. 检查是否存在已有 Release
    get_url = f"https://api.github.com/repos/{repo}/releases/tags/{tag}"
    req = urllib.request.Request(get_url, headers=headers)
    release_id = None
    upload_url = None

    try:
        with urllib.request.urlopen(req) as resp:
            data = json.loads(resp.read().decode('utf-8'))
            release_id = data.get("id")
            upload_url = data.get("upload_url")
            print(f"[Info] 找到已有 Release v1.4.0: ID {release_id}")
    except urllib.error.HTTPError as e:
        if e.code == 404:
            print(f"[Info] Release {tag} 不存在，准备创建...")
        else:
            print(f"[Error] 获取 Release 失败: {e}")
            sys.exit(1)

    # 2. 如果不存在，创建 Release
    if not release_id:
        create_url = f"https://api.github.com/repos/{repo}/releases"
        payload = {
            "tag_name": tag,
            "target_commitish": "main",
            "name": release_name,
            "body": body,
            "draft": False,
            "prerelease": False
        }
        req = urllib.request.Request(create_url, data=json.dumps(payload).encode('utf-8'), headers=headers, method="POST")
        try:
            with urllib.request.urlopen(req) as resp:
                data = json.loads(resp.read().decode('utf-8'))
                release_id = data.get("id")
                upload_url = data.get("upload_url")
                print(f"[Success] 成功创建 Release v1.4.0: ID {release_id}")
        except urllib.error.HTTPError as e:
            print(f"[Error] 创建 Release 失败: {e.code} {e.read().decode('utf-8')}")
            sys.exit(1)

    if not upload_url:
        print("[Error] 缺少 upload_url")
        sys.exit(1)

    upload_url_base = upload_url.split("{")[0]

    # 3. 上传附件
    assets = [
        ("HD2ChatOverlay.exe", "HD2ChatOverlay.exe", "application/octet-stream"),
        ("release/HD2ChatOverlay-v1.4.1.zip", "HD2ChatOverlay-v1.4.1.zip", "application/zip")
    ]

    for local_file, asset_name, content_type in assets:
        if not os.path.exists(local_file):
            print(f"[Warning] 文件不存在，跳过上传: {local_file}")
            continue

        print(f"\n[Upload] 正在上传 {asset_name} ({os.path.getsize(local_file)} 字节)...")

        # 检查是否已有同名附件，如有则先删除
        list_assets_url = f"https://api.github.com/repos/{repo}/releases/{release_id}/assets"
        req_list = urllib.request.Request(list_assets_url, headers=headers)
        try:
            with urllib.request.urlopen(req_list) as resp:
                existing_assets = json.loads(resp.read().decode('utf-8'))
                for ex in existing_assets:
                    if ex.get("name") == asset_name:
                        asset_id = ex.get("id")
                        print(f"[Delete] 删除已存在的旧附件 {asset_name} (ID: {asset_id})...")
                        del_req = urllib.request.Request(f"https://api.github.com/repos/{repo}/releases/assets/{asset_id}", headers=headers, method="DELETE")
                        urllib.request.urlopen(del_req)
        except Exception as e:
            print(f"[Warning] 检查旧附件时发生异常: {e}")

        upload_asset_url = f"{upload_url_base}?name={urllib.parse.quote(asset_name)}"
        with open(local_file, "rb") as f:
            file_data = f.read()

        up_headers = headers.copy()
        up_headers["Content-Type"] = content_type
        up_headers["Content-Length"] = str(len(file_data))

        req_upload = urllib.request.Request(upload_asset_url, data=file_data, headers=up_headers, method="POST")
        try:
            with urllib.request.urlopen(req_upload) as resp:
                up_resp = json.loads(resp.read().decode('utf-8'))
                print(f"[Success] {asset_name} 上传成功！")
                print(f"         下载地址: {up_resp.get('browser_download_url')}")
        except urllib.error.HTTPError as e:
            print(f"[Error] 上传 {asset_name} 失败: {e.code} {e.read().decode('utf-8')}")

    print("\nGitHub Release v1.4.0 发布与附件上传完毕！")
    print(f"Release 发布地址: https://github.com/{repo}/releases/tag/{tag}")

if __name__ == "__main__":
    main()
