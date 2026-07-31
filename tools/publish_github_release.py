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
    tag = "v1.4.2"
    release_name = "HD2 Chat Overlay v1.4.2 - 初始版本"

    body = """# HD2 Chat Overlay v1.4.2

《绝地潜兵 2》(HELLDIVERS 2) 中文输入悬浮窗插件，基于 AutoHotkey v2 开发，为游戏提供原生风格的中文输入与 AI 辅助翻译体验。

### 主要功能

- **黑金风格 UI**：黑底黄边视觉设计，贴合《绝地潜兵 2》原生界面风格。
- **中文输入与注入**：支持在游戏内按 Enter 唤醒悬浮窗输入中文，按 Enter 自动发送文本到游戏聊天框。
- **AI 翻译与双悬浮框**：接入 OpenRouter / OpenAI 兼容接口，按 Alt+T 翻译输入内容（译文显示在上方淡蓝悬浮框），按 Ctrl+Tab 切换发送原文或译文。
- **HD2 游戏黑话词库**：内置 137 条常用战术配备、武器、敌人及游戏俚语词汇，提升 AI 翻译准确度。
- **配置与实时预览**：支持在配置界面微调悬浮窗位置、尺寸与字号，并实时在屏预览效果；支持 Ctrl+Alt+方向键 微调位置。

---

### 文件说明
- `HD2ChatOverlay.exe`：单文件可执行程序，解压或双击即可直接运行。
- `HD2ChatOverlay-v1.4.2.zip`：包含源码与资产文件的 Release 压缩包。
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
