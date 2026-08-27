param([string]$ProcessName = "helldivers2")

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class Win32Token {
    [DllImport("advapi32.dll", SetLastError = true)]
    public static extern bool OpenProcessToken(IntPtr ProcessHandle, uint DesiredAccess, out IntPtr TokenHandle);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr OpenProcess(uint processAccess, bool bInheritHandle, int processId);

    [DllImport("advapi32.dll", SetLastError = true)]
    public static extern bool GetTokenInformation(IntPtr TokenHandle, int TokenInformationClass, IntPtr TokenInformation, uint TokenInformationLength, out uint ReturnLength);

    [DllImport("advapi32.dll", SetLastError = true)]
    public static extern IntPtr GetSidSubAuthorityCount(IntPtr pSid);

    [DllImport("advapi32.dll", SetLastError = true)]
    public static extern IntPtr GetSidSubAuthority(IntPtr pSid, uint nSubAuthority);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool CloseHandle(IntPtr hObject);

    public static string GetIntegrityAndElevation(int pid) {
        IntPtr hProc = OpenProcess(0x1000, false, pid);
        if (hProc == IntPtr.Zero) return "Failed to open process (Access Denied / Driver Protected)";

        IntPtr hToken;
        if (!OpenProcessToken(hProc, 0x0008, out hToken)) {
            CloseHandle(hProc);
            return "Failed to open process token";
        }

        string result = "";
        IntPtr buf = Marshal.AllocHGlobal(128);
        uint retLen;

        if (GetTokenInformation(hToken, 20, buf, 128, out retLen)) {
            int elevated = Marshal.ReadInt32(buf);
            result += (elevated != 0) ? "[Elevated: YES / Admin] " : "[Elevated: NO / Standard] ";
        }

        if (GetTokenInformation(hToken, 25, buf, 128, out retLen)) {
            IntPtr pSid = Marshal.ReadIntPtr(buf);
            if (pSid != IntPtr.Zero) {
                IntPtr pCount = GetSidSubAuthorityCount(pSid);
                byte count = Marshal.ReadByte(pCount);
                if (count > 0) {
                    IntPtr pRid = GetSidSubAuthority(pSid, (uint)(count - 1));
                    uint rid = (uint)Marshal.ReadInt32(pRid);
                    if (rid < 0x2000) result += "IL: Low";
                    else if (rid < 0x3000) result += "IL: Medium (Standard User)";
                    else if (rid < 0x4000) result += "IL: High (Elevated Admin)";
                    else result += "IL: System";
                }
            }
        }

        Marshal.FreeHGlobal(buf);
        CloseHandle(hToken);
        CloseHandle(hProc);
        return result;
    }
}
"@

$procs = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
if (!$procs) {
    Write-Host "[-] Process '$ProcessName' is not running." -ForegroundColor Yellow
    Write-Host "[*] Checking sample running processes:"
    $sample = @("explorer", "notepad", "steam")
    foreach ($s in $sample) {
        $p = Get-Process -Name $s -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($p) {
            $info = [Win32Token]::GetIntegrityAndElevation($p.Id)
            Write-Host "  • Process: $($p.ProcessName) (PID: $($p.Id)) -> $info"
        }
    }
} else {
    foreach ($p in $procs) {
        $info = [Win32Token]::GetIntegrityAndElevation($p.Id)
        Write-Host "[+] Found Target Process: $($p.ProcessName) (PID: $($p.Id))" -ForegroundColor Green
        Write-Host "    -> Status: $info" -ForegroundColor Cyan
    }
}
