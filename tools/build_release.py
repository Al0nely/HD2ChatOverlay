import os
import subprocess
import zipfile

def build():
    root_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    ahk2exe = os.path.join(root_dir, "tools", "Ahk2Exe", "Ahk2Exe.exe")
    ahk_base = r"C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe"
    main_script = os.path.join(root_dir, "hd2_chat.ahk")
    exe_output = os.path.join(root_dir, "HD2ChatOverlay.exe")

    print(f"[Build] Compiling {main_script} -> {exe_output} ...")
    cmd = [
        ahk2exe,
        "/in", main_script,
        "/out", exe_output,
        "/base", ahk_base,
        "/silent"
    ]
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0:
        print("[Build Error]", res.stderr or res.stdout)
        return False

    print("[Build Success] HD2ChatOverlay.exe compiled successfully.")
    
    # 压包到 release 目录
    release_dir = os.path.join(root_dir, "release")
    os.makedirs(release_dir, exist_ok=True)
    zip_path = os.path.join(release_dir, "HD2ChatOverlay-v1.4.0.zip")

    print(f"[Package] Creating release archive {zip_path} ...")
    files_to_pack = [
        ("HD2ChatOverlay.exe", "HD2ChatOverlay.exe"),
        ("assets/glossary.core.json", "assets/glossary.core.json"),
        ("README.md", "README.md"),
        ("CHANGELOG.md", "CHANGELOG.md"),
    ]

    with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
        for src, arcname in files_to_pack:
            src_full = os.path.join(root_dir, src)
            if os.path.exists(src_full):
                zipf.write(src_full, arcname)
                print(f"  + Added {arcname}")

    print(f"[Package Success] Release zip ready at: {zip_path}")
    return True

if __name__ == "__main__":
    build()
