# Voyage 个人修改记录

维护者：SavannahY。修改日期：2026-10-04 至 2026-10-05。

基线：`miumiupy98-art/miuread-koreader` 的 `v5.9.0`，提交 `2c0ad01`。移植前逐项确认了被修改文件与使用的 v5.9.0 安装包一致。

## 改动与文件

| 问题或需求 | 修改 | 主要文件 |
| --- | --- | --- |
| 扫码登录入口等待或卡住 | 后台获取 UID、超时、取消和登录窗口关闭修复 | `miuread/auth.lua` |
| 外部服务限流阻塞微信读书 | 按服务隔离冷却状态，兼容历史状态 | `miuread/http.lua` |
| 主动刷新书架被触摸打断 | 主动任务优先，保留休眠等生命周期限制 | `main.lua` |
| 摘要一直显示同步检查中 | 摘要完成后重新生成快照并刷新界面 | `main.lua` |
| 大量划线渲染缓慢 | 起点二分定位和单调推进；输出等价测试 | `miuread/annotations.lua` |
| 全量想法导致长下载和内存压力 | 新增正文＋划线模式，不下载想法正文 | `main.lua`、`miuread/downloader.lua`、`miuread/annotations.lua` |
| 按需模式丢失或混用缓存 | 独立任务键、缓存键，修复与后续章节保留模式，避免混用预读文件 | `main.lua`、`miuread/downloader.lua`、`miuread/book_integrity.lua` |
| 想法点开再获取 | 链接带模式标识，每次单一划线、最多 5 条 | `miuread/thoughts.lua`、`miuread/on_demand_thoughts.lua` |
| 第二批错误为空 | `maxIdx` 推进，`synckey=0`，验证分页游标 | `miuread/on_demand_thoughts.lua` |
| 网页接口过期影响弹窗 | 按需模式直接使用已验证可用的 Skill Gateway | `miuread/on_demand_thoughts.lua`、`miuread/api.lua` |
| 取消后窗口重开、旧结果影响新窗口 | 生命周期、账号与请求代次检查，丢弃过期结果 | `miuread/on_demand_thoughts.lua` |
| 弹窗外部点击未取消任务 | 使用真实 `tap_close_callback` 契约 | `miuread/on_demand_thoughts.lua` |
| 响应过大 | 接收层限制响应大小，解析层限制单批内容 | `miuread/http.lua`、`miuread/on_demand_thoughts.lua` |
| 名字和正文难以区分 | 独立原生评论弹窗，字号、字体、颜色分层和批次按钮 | `miuread/on_demand_popup.lua` |
| 用户名含表情时显示问题 | 显示层 UTF-8 校验、表情文字替代，不改变缓存原文 | `miuread/thought_display_text.lua` |

`on_demand_popup.lua` 是从上游 `thought_native_popup.lua` 派生的独立显示组件，继续使用上游字体回退和评论排版机制。它没有替换原完整想法版的弹窗。

## 仍需验证或未包含的工作

- 最新排版补丁已安装，仍待实机确认表情名字、翻页和批次按钮。
- 阅读时间沿用上游机制；实际手机统计计入未核实。
- 未新增全书后台预下载或并行下载。
- 未降低或绕开服务限流。
- 未新增 Android / Google Play / 原生微信读书安装方案。
- 未新增本地 EPUB 阅读时间计入微信读书的功能。

## 复现与测试

运行 `python3 tools/voyage/run_tests.py --lua lua5.1`。测试夹具中的旧渲染实现来自上游 v5.9.0，用于检查划线优化的输出等价性；其许可证和版权归属继续随项目保留。

测试与仓库中的修改仅包含源码和合成数据。不包含测试账号、Cookie、API key、Kindle 书籍、个人设置或原始设备日志。
