// ui/overlay/overlay.js - 悬浮窗输入处理与 AHK 通信

(function() {
    'use strict';

    const input = document.getElementById('chat-input');
    const container = document.getElementById('overlay-container');
    const imeHint = document.getElementById('ime-hint');

    let isComposing = false;
    let compositionText = '';
    let pollTimer = null;
    let lastPollTime = 0;
    const POLL_INTERVAL = 30; // ms

    // -------------------------------------------------------------
    // AHK 通信桥
    // -------------------------------------------------------------

    const bridge = {
        // 发送消息到 AHK
        send: function(type, payload) {
            const msg = JSON.stringify({ type: type, payload: payload });
            // 通过 HTTP POST 发送到桥接服务器
            fetch('/api/send', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: msg
            }).catch(function(err) {
                console.error('[Bridge] 发送失败:', err);
            });
        },

        // 轮询 AHK 发送的消息
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
                .catch(function(err) {
                    // 静默失败,服务器可能未就绪
                });
        }
    };

    // 处理来自 AHK 的消息
    function handleMessage(msg) {
        if (!msg) return;
        switch (msg.type) {
            case 'setText':
                input.value = msg.payload || '';
                autoResize();
                break;
            case 'focus':
                input.focus();
                break;
            case 'setFont':
                if (msg.payload && msg.payload.family) {
                    input.style.fontFamily = msg.payload.family;
                }
                if (msg.payload && msg.payload.size) {
                    input.style.fontSize = msg.payload.size + 'px';
                }
                break;
            case 'executeSubmit':
            case 'getText':
                submitText();
                break;
            case 'setPosition':
                // 位置由 AHK 直接控制窗口,前端无需处理
                break;
        }
    }

    // -------------------------------------------------------------
    // IME 组合事件处理
    // -------------------------------------------------------------

    input.addEventListener('compositionstart', function(e) {
        isComposing = true;
        compositionText = '';
        imeHint.style.display = 'block';
    });

    input.addEventListener('compositionupdate', function(e) {
        compositionText = e.data || '';
    });

    input.addEventListener('compositionend', function(e) {
        isComposing = false;
        compositionText = '';
        imeHint.style.display = 'none';
        autoResize();
    });

    // -------------------------------------------------------------
    // 输入事件与自动增高
    // -------------------------------------------------------------

    input.addEventListener('input', function() {
        autoResize();
    });

    input.addEventListener('keydown', function(e) {
        // Enter 提交 (不在组合状态时)
        if (e.key === 'Enter' && !e.shiftKey && !isComposing) {
            e.preventDefault();
            submitText();
            return;
        }

        // Shift+Enter 换行
        if (e.key === 'Enter' && e.shiftKey) {
            // 允许默认换行行为
            setTimeout(autoResize, 0);
            return;
        }

        // Esc 取消
        if (e.key === 'Escape') {
            e.preventDefault();
            bridge.send('cancel', {});
            return;
        }
    });

    // 自动调整高度
    function autoResize() {
        input.style.height = 'auto';
        const newHeight = Math.min(input.scrollHeight, 96); // 最大4行
        input.style.height = newHeight + 'px';

        // 通知 AHK 调整窗口高度 (保留固定宽度)
        const containerHeight = container.offsetHeight;
        bridge.send('resize', { height: containerHeight });
    }

    // -------------------------------------------------------------
    // 提交文本
    // -------------------------------------------------------------

    function submitText() {
        const text = input.value.trim();
        bridge.send('submit', { text: text });
        input.value = '';
        autoResize();
    }

    // -------------------------------------------------------------
    // 初始化
    // -------------------------------------------------------------

    function init() {
        // 聚焦输入框
        setTimeout(function() {
            input.focus();
        }, 100);

        // 发送 ready 消息
        bridge.send('ready', {
            dpi: window.devicePixelRatio || 1,
            userAgent: navigator.userAgent
        });

        // 启动消息轮询
        pollTimer = setInterval(function() {
            const now = Date.now();
            if (now - lastPollTime >= POLL_INTERVAL) {
                lastPollTime = now;
                bridge.poll();
            }
        }, POLL_INTERVAL);

        console.log('[Overlay] 初始化完成');
    }

    // 页面卸载时清理
    window.addEventListener('beforeunload', function() {
        if (pollTimer) {
            clearInterval(pollTimer);
        }
    });

    // DOM 就绪后初始化
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }
})();
