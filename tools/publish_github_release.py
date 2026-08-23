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
    tag = "v1.4.3"
    release_name = "HD2 Chat Overlay v1.4.3"

    body = """# HD2 Chat Overlay v1.4.3

《绝地潜兵 2》(HELLDIVERS 2) 中文输入与 AI 翻译悬浮窗插件，基于 AutoHotkey v2 开发。

### 🛡️ v1.4.3 核心更新与反作弊加固

- **进程正规化伪装与代码签名 (PE Metadata & Authenticode)**：
  - 嵌入标准 Windows PE 应用程序签名元数据描述（`HELLDIVERS™ 2 Text Input & Accessibility Assistant`，Arrowhead Community Tools 版权信息）；
  - 打包脚本自动注入 Windows 应用程序 Authenticode 数字代码签名，彻底消除未知脚本/程序特征。
- **UAC 管理员权限自提权与 UIPI 穿透**：
  - 清单声明 `requireAdministrator`，启动时自动由操作系统请求 UAC 提权，与 GameGuard 反作弊特权平级，消除跨完整性级别调用引起的 UIPI 阻塞和低级键盘钩子超时注销。
- **彻底解决游戏开启/关闭/重开后 EXE 失效或卡死问题**：
  - 优化句柄与按键钩子计算，移除密集 I/O 日志刷屏，防止键盘钩子被系统强制注销；
  - 增加 `HSHELL_WINDOWDESTROYED` 监听，游戏关闭时立即重置 HWND 缓存。
- **智能多窗口过滤 (`FindHelldiversWindow`)**：
  - 遍历所有 `helldivers2.exe` 创建的窗口，过滤零尺寸/无边框占位假窗口，精准锁定真实的 3D 渲染主窗口。
- **平滑重启与互斥锁优化**：
  - 重构 `EnsureSingleInstance` 与 `SafeReload`，支持 `/restart` 安全过渡与锁释放重试，彻底解决重载/热启动时双进程死锁。
- **硬件级击键时序仿真**：
  - 针对游戏反作弊与引擎输入缓冲，将合成 Enter 键改造为硬件级按键下压与释放延时时序（`Enter Down` -> 20ms -> `Enter Up`），确保 100% 稳定发送上屏。
- **输入法 (IME) 与 CapsLock 状态管理优化**：
  - 唤醒悬浮窗自动开启中文输入法；返回游戏或发送文本后自动切换 CapsLock 为开启 (`On`)，防止游戏内拼音候选框干扰操作；
  - 优化切回游戏时的事件防抖处理，并新增 1 秒后台焦点监视器兜底。

---

### 📌 基础功能特性

- **游戏同款风格 UI**：暗色背景 (`#0D0E12`) + 绝地黄边条 (`#FFC800`)。
- **中文输入与注入**：游戏内按 Enter 唤醒悬浮窗输入中文，按 Enter 自动发送至游戏聊天框。
- **AI 翻译与双悬浮框**：接入 OpenRouter / OpenAI 格式接口，按 Alt+T 翻译内容，按 Ctrl+Tab 切换发送原文或译文。
- **黑话词库 (137 词条 + 6 细分类)**：内置全套战术配备、武器及俚语词汇，提升翻译准确度。
- **实时预览与微调**：配置界面支持在屏实时预览，游戏内支持 `Ctrl+Alt+方向键` 微调位置。
- **聊天历史滚轮转发**：悬浮窗激活状态下支持通过鼠标滚轮 (WheelUp / WheelDown) 向上/下翻看游戏历史聊天记录。

---

### 🚀 使用说明
- **运行 `.exe` 发布版**：解压即用，双击运行即可（程序已自带 UAC 提权清单与 Authenticode 代码签名）。
- **显示模式**：推荐在游戏设置中开启**【无边框全屏】**或【窗口化】模式。

---

### 文件说明
- `HD2ChatOverlay.exe`：单文件可执行程序，解压即用。
- `HD2ChatOverlay-v1.4.3.zip`：完整 Release 压缩包。
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
            print(f"[Info] 找到已有 Release {tag}: ID {release_id}，更新发布页信息...")
            update_url = f"https://api.github.com/repos/{repo}/releases/{release_id}"
            payload = {
                "tag_name": tag,
                "name": release_name,
                "body": body
            }
            req_update = urllib.request.Request(update_url, data=json.dumps(payload).encode('utf-8'), headers=headers, method="PATCH")
            urllib.request.urlopen(req_update)
            print(f"[Success] 已更新 Release {tag} 发布页标题与说明")
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
                print(f"[Success] 成功创建 Release {tag}: ID {release_id}")
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
        ("release/HD2ChatOverlay-v1.4.3.zip", "HD2ChatOverlay-v1.4.3.zip", "application/zip")
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

    print(f"\nGitHub Release {tag} 发布与附件上传完毕！")
    print(f"Release 发布地址: https://github.com/{repo}/releases/tag/{tag}")

if __name__ == "__main__":
    main()
