// ui/config/config.js - 配置窗口逻辑与 AHK 通信

(function() {
    'use strict';

    // -------------------------------------------------------------
    // AHK 通信桥
    // -------------------------------------------------------------

    const bridge = {
        send: function(type, payload) {
            const msg = JSON.stringify({ type: type, payload: payload });
            fetch('/api/send', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: msg
            }).catch(function(err) {
                console.error('[Bridge] 发送失败:', err);
            });
        },

        poll: function() {
            fetch('/api/poll', { method: 'GET' })
                .then(function(res) {
                    if (res.status === 204) return null;
                    return res.text();
                })
                .then(function(text) {
                    if (!text) return;
                    try {
                        const parsed = JSON.parse(text);
                        if (Array.isArray(parsed)) {
                            parsed.forEach(handleMessage);
                        } else if (parsed) {
                            handleMessage(parsed);
                        }
                    } catch (e) {
                        console.error('[Bridge] 解析失败:', e, text);
                    }
                })
                .catch(function() {});
        }
    };

    // -------------------------------------------------------------
    // 配置字段映射
    // -------------------------------------------------------------

    const fields = {
        offsetX: { el: document.getElementById('offsetX'), key: 'OffsetX', default: 840 },
        offsetY: { el: document.getElementById('offsetY'), key: 'OffsetY', default: 638 },
        chunkSize: { el: document.getElementById('chunkSize'), key: 'ChunkSize', default: 8 },
        chunkDelay: { el: document.getElementById('chunkDelay'), key: 'ChunkDelay', default: 5 },
        fontName: { el: document.getElementById('fontName'), key: 'FontName', default: 'SimHei' },
        fontSize: { el: document.getElementById('fontSize'), key: 'FontSize', default: 18 },
        engine: { el: document.getElementById('engine'), key: 'UseWebView2', default: 'webview2' },
        enableDebugLog: { el: document.getElementById('enableDebugLog'), key: 'EnableDebugLog', default: false },
        globalTestMode: { el: document.getElementById('globalTestMode'), key: 'GlobalTestMode', default: false }
    };

    let currentConfig = {};
    let pollTimer = null;

    // -------------------------------------------------------------
    // 初始化
    // -------------------------------------------------------------

    function init() {
        // 从 AHK 拉取当前配置
        bridge.send('getConfig', {});

        // 绑定加减按钮
        document.querySelectorAll('.btn-adjust').forEach(function(btn) {
            btn.addEventListener('click', function() {
                const targetId = this.getAttribute('data-target');
                const delta = parseInt(this.getAttribute('data-delta'), 10);
                const input = document.getElementById(targetId);
                if (input) {
                    let val = parseInt(input.value, 10) || 0;
                    val += delta;
                    const min = parseInt(input.min, 10) || 0;
                    const max = parseInt(input.max, 10) || 9999;
                    val = Math.max(min, Math.min(max, val));
                    input.value = val;
                    input.dispatchEvent(new Event('input', { bubbles: true }));
                }
            });
        });

        // 绑定实时预览
        Object.keys(fields).forEach(function(key) {
            const field = fields[key];
            if (!field.el) return;

            const eventType = field.el.type === 'checkbox' ? 'change' : 'input';
            field.el.addEventListener(eventType, function() {
                sendPreview();
            });
        });

        // 绑定按钮
        document.getElementById('btn-save').addEventListener('click', saveConfig);
        document.getElementById('btn-cancel').addEventListener('click', cancelConfig);
        document.getElementById('btn-reset').addEventListener('click', resetConfig);

        // 启动轮询
        pollTimer = setInterval(bridge.poll, 50);

        // 发送 ready
        bridge.send('ready', { page: 'config' });

        console.log('[Config] 初始化完成');
    }

    // -------------------------------------------------------------
    // 消息处理
    // -------------------------------------------------------------

    function handleMessage(msg) {
        switch (msg.type) {
            case 'config':
                loadConfig(msg.payload);
                break;
            case 'configSaved':
                showToast('配置已保存');
                break;
        }
    }

    function loadConfig(config) {
        currentConfig = config || {};
        Object.keys(fields).forEach(function(key) {
            const field = fields[key];
            if (!field.el) return;

            let value = currentConfig[field.key] !== undefined ? currentConfig[field.key] : field.default;

            if (field.key === 'UseWebView2') {
                if (value === 1 || value === '1' || value === true || value === 'webview2') {
                    value = 'webview2';
                } else {
                    value = 'native';
                }
            }

            if (field.el.type === 'checkbox') {
                field.el.checked = !!value;
            } else if (field.el.tagName === 'SELECT') {
                field.el.value = value;
            } else {
                field.el.value = value;
            }
        });
    }

    // -------------------------------------------------------------
    // 预览与保存
    // -------------------------------------------------------------

    function collectConfig() {
        const config = {};
        Object.keys(fields).forEach(function(key) {
            const field = fields[key];
            if (!field.el) return;

            if (field.el.type === 'checkbox') {
                config[field.key] = field.el.checked ? 1 : 0;
            } else if (field.el.type === 'number') {
                config[field.key] = parseInt(field.el.value, 10) || field.default;
            } else if (field.el.tagName === 'SELECT' && key === 'engine') {
                config[field.key] = field.el.value === 'webview2' ? 1 : 0;
            } else {
                config[field.key] = field.el.value;
            }
        });
        return config;
    }

    function sendPreview() {
        const config = collectConfig();
        bridge.send('preview', config);
    }

    function saveConfig() {
        const config = collectConfig();
        bridge.send('saveConfig', config);
    }

    function cancelConfig() {
        bridge.send('cancel', {});
    }

    function resetConfig() {
        if (confirm('确定要恢复默认配置吗?')) {
            bridge.send('resetConfig', {});
        }
    }

    function showToast(text) {
        // 简单的 toast 提示
        const toast = document.createElement('div');
        toast.style.cssText = 'position:fixed;bottom:60px;right:20px;background:var(--accent);color:#000;padding:8px 16px;border-radius:4px;font-size:13px;font-weight:600;z-index:9999;animation:fadeIn 0.2s;';
        toast.textContent = text;
        document.body.appendChild(toast);
        setTimeout(function() {
            toast.style.opacity = '0';
            toast.style.transition = 'opacity 0.3s';
            setTimeout(function() { toast.remove(); }, 300);
        }, 2000);
    }

    // -------------------------------------------------------------
    // 清理
    // -------------------------------------------------------------

    window.addEventListener('beforeunload', function() {
        if (pollTimer) clearInterval(pollTimer);
    });

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }
})();
