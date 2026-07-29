# lib/WebView2Bridge.ps1 - 轻量 HTTP 服务器,桥接 AHK 与 Edge App
# 监听 127.0.0.1:PORT,提供静态文件服务和 /api 端点

param(
    [int]$Port = 0,
    [string]$RootDir = "",
    [string]$MsgDir = ""
)

if ($Port -eq 0) { $Port = 9280 + (Get-Random -Maximum 100) }
if ($RootDir -eq "") { $RootDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
if ($MsgDir -eq "") { $MsgDir = Join-Path $env:TEMP "HD2ChatOverlay_Msg" }

# 确保消息目录存在
New-Item -ItemType Directory -Force -Path $MsgDir | Out-Null

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://127.0.0.1:$Port/")

try {
    $listener.Start()
    Write-Host "[Bridge] 监听 http://127.0.0.1:$Port/"
    Write-Host "[Bridge] 根目录: $RootDir"
    Write-Host "[Bridge] 消息目录: $MsgDir"

    # 写入端口文件供 AHK 读取
    $portFile = Join-Path $MsgDir "bridge.port"
    $Port | Out-File -FilePath $portFile -Encoding utf8

    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response

        $path = $request.Url.LocalPath
        $method = $request.HttpMethod

        Write-Host "[Bridge] $method $path"

        try {
            if ($path -eq "/api/send" -and $method -eq "POST") {
                # JS -> AHK: 接收消息并写入文件
                $reader = New-Object System.IO.StreamReader($request.InputStream)
                $body = $reader.ReadToEnd()
                $reader.Close()

                $msgFile = Join-Path $MsgDir "inbox_$(Get-Date -Format 'yyyyMMddHHmmssfff').json"
                $body | Out-File -FilePath $msgFile -Encoding utf8

                $response.StatusCode = 200
                $buffer = [System.Text.Encoding]::UTF8.GetBytes('{"ok":true}')
                $response.OutputStream.Write($buffer, 0, $buffer.Length)
            }
            elseif ($path -eq "/api/poll" -and $method -eq "GET") {
                # AHK -> JS: 读取待发送消息 (支持多个 outbox_*.json 队列)
                $files = Get-ChildItem -Path $MsgDir -Filter "outbox_*.json" -ErrorAction SilentlyContinue | Sort-Object Name
                if ($files -and $files.Count -gt 0) {
                    $items = @()
                    foreach ($f in $files) {
                        try {
                            $raw = Get-Content -Path $f.FullName -Raw -Encoding utf8
                            Remove-Item $f.FullName -Force -ErrorAction SilentlyContinue
                            if ($raw -and $raw.Trim()) { $items += $raw.Trim() }
                        } catch {}
                    }
                    if ($items.Count -gt 0) {
                        $jsonArray = "[" + ($items -join ",") + "]"
                        $response.StatusCode = 200
                        $buffer = [System.Text.Encoding]::UTF8.GetBytes($jsonArray)
                    } else {
                        $response.StatusCode = 204
                        $buffer = @()
                    }
                } else {
                    $outFile = Join-Path $MsgDir "outbox.json"
                    if (Test-Path $outFile) {
                        $content = Get-Content -Path $outFile -Raw -Encoding utf8
                        Remove-Item $outFile -Force -ErrorAction SilentlyContinue
                        if ($content -and $content.Trim()) {
                            $response.StatusCode = 200
                            $buffer = [System.Text.Encoding]::UTF8.GetBytes("[$($content.Trim())]")
                        } else {
                            $response.StatusCode = 204
                            $buffer = @()
                        }
                    } else {
                        $response.StatusCode = 204
                        $buffer = @()
                    }
                }
                $response.OutputStream.Write($buffer, 0, $buffer.Length)
            }
            elseif ($path -eq "/api/call" -and $method -eq "POST") {
                # JS 调用 AHK 函数
                $reader = New-Object System.IO.StreamReader($request.InputStream)
                $body = $reader.ReadToEnd()
                $reader.Close()

                $data = $body | ConvertFrom-Json
                $funcName = $data.name
                $funcArgs = $data.args

                # 写入调用请求
                $callFile = Join-Path $MsgDir "call_$(Get-Date -Format 'yyyyMMddHHmmssfff').json"
                $body | Out-File -FilePath $callFile -Encoding utf8

                $response.StatusCode = 200
                $buffer = [System.Text.Encoding]::UTF8.GetBytes('{"ok":true}')
                $response.OutputStream.Write($buffer, 0, $buffer.Length)
            }
            elseif ($path -eq "/overlay" -or $path -eq "/overlay/" -or $path -match '^/ui/overlay/?' -or $path -match '^/api/overlay') {
                # 代理到 overlay 页面
                $filePath = Join-Path $RootDir "ui/overlay/index.html"
                if (Test-Path $filePath) {
                    $content = Get-Content -Path $filePath -Raw -Encoding utf8
                    $bridgeScript = @"
<script>
window.AHK_BRIDGE_PORT = $Port;
window.AHK_MSG_DIR = '$($MsgDir -replace '\\','\\')';
</script>
"@
                    $content = $content -replace '</head>', "$bridgeScript</head>"
                    $buffer = [System.Text.Encoding]::UTF8.GetBytes($content)
                    $response.ContentType = "text/html; charset=utf-8"
                    $response.OutputStream.Write($buffer, 0, $buffer.Length)
                } else {
                    $response.StatusCode = 404
                }
            }
            elseif ($path -eq "/config" -or $path -eq "/config/" -or $path -match '^/ui/config/?') {
                # 代理到 config 页面
                $filePath = Join-Path $RootDir "ui/config/index.html"
                if (Test-Path $filePath) {
                    $content = Get-Content -Path $filePath -Raw -Encoding utf8
                    $bridgeScript = @"
<script>
window.AHK_BRIDGE_PORT = $Port;
window.AHK_MSG_DIR = '$($MsgDir -replace '\\','\\')';
</script>
"@
                    $content = $content -replace '</head>', "$bridgeScript</head>"
                    $buffer = [System.Text.Encoding]::UTF8.GetBytes($content)
                    $response.ContentType = "text/html; charset=utf-8"
                    $response.OutputStream.Write($buffer, 0, $buffer.Length)
                } else {
                    $response.StatusCode = 404
                }
            }
            else {
                # 静态文件服务 (多路径回退)
                $safePath = $path.TrimStart('/') -replace '\.\.', ''
                $filePath = Join-Path $RootDir $safePath

                if (-not (Test-Path $filePath -PathType Leaf)) {
                    $overlayPath = Join-Path $RootDir "ui/overlay/$safePath"
                    $configPath = Join-Path $RootDir "ui/config/$safePath"
                    if (Test-Path $overlayPath -PathType Leaf) {
                        $filePath = $overlayPath
                    } elseif (Test-Path $configPath -PathType Leaf) {
                        $filePath = $configPath
                    }
                }

                if (Test-Path $filePath -PathType Leaf) {
                    $ext = [System.IO.Path]::GetExtension($filePath).ToLower()
                    $mimeTypes = @{
                        '.html' = 'text/html; charset=utf-8'
                        '.css'  = 'text/css; charset=utf-8'
                        '.js'   = 'application/javascript; charset=utf-8'
                        '.json' = 'application/json; charset=utf-8'
                        '.png'  = 'image/png'
                        '.jpg'  = 'image/jpeg'
                        '.svg'  = 'image/svg+xml'
                    }
                    if ($mimeTypes.ContainsKey($ext)) {
                        $response.ContentType = $mimeTypes[$ext]
                    } else {
                        $response.ContentType = 'application/octet-stream'
                    }
                    $bytes = [System.IO.File]::ReadAllBytes($filePath)
                    $response.OutputStream.Write($bytes, 0, $bytes.Length)
                } else {
                    $response.StatusCode = 404
                }
            }
        } catch {
            Write-Host "[Bridge] 错误: $_"
            $response.StatusCode = 500
        } finally {
            $response.Close()
        }
    }
} catch {
    Write-Host "[Bridge] 启动失败: $_"
    exit 1
} finally {
    $listener.Stop()
    $listener.Close()
}
