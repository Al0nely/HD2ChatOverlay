# 贡献指南

## Git 提交规范

本项目采用 [Conventional Commits](https://www.conventionalcommits.org/zh-hans/) 规范。

### 提交格式

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Type 类型

| 类型 | 说明 | 示例 |
|------|------|------|
| feat | 新功能 | `feat(tray): add test mode toggle` |
| fix | 修复 bug | `fix(gui): prevent window flicker on show` |
| perf | 性能优化 | `perf(injection): dynamic chunk sizing` |
| refactor | 代码重构 | `refactor: split into lib modules` |
| docs | 文档更新 | `docs: update README shortcuts` |
| chore | 构建/工具/杂项 | `chore: initial commit` |
| test | 测试相关 | `test: add notepad simulation script` |
| style | 代码格式(不影响功能) | `style: fix indentation` |

### Scope 范围(可选)

- `tray`: 托盘菜单
- `gui`: 悬浮窗/配置窗口
- `config`: 配置系统
- `injection`: 文本注入
- `utils`: 工具函数
- `main`: 主入口

### Subject 主题

- 使用祈使句，现在时态："add" 不是 "added" 或 "adds"
- 首字母小写
- 结尾不加句号

### Body 正文(可选)

- 详细说明变更内容和原因
- 与主题空一行

### Footer 页脚(可选)

- 关闭 Issue: `Closes #123`
-  Breaking Change: `BREAKING CHANGE: ...`

### 示例

```
feat(config): add font name selection to GUI

- Add dropdown with SimHei, Microsoft YaHei UI, Segoe UI, NSimSun, Consolas
- Persist selection to INI [UI] section
- Rebuild chat GUI on save to apply new font

Closes #5
```

## 代码风格

- AHK v2 语法，4 空格缩进
- 全局变量前缀 `g_`，静态类变量直接命名
- 函数名 PascalCase，局部变量 camelCase
- 关键 Win32 调用必须 Try-Catch 包裹
- 注释使用中文，关键算法添加英文注释

## 测试要求

- 新功能必须手动测试通过
- 无游戏环境时使用 `test/TestWithNotepad.ahk` 模拟
- 提交前确保 `AutoHotkey64.exe /ErrorStdOut hd2_chat.ahk` 无语法错误
