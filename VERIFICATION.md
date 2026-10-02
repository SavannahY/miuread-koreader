# 5.8.0-beta.25 verification

## beta.25 完成标准

- 版本元数据必须统一为 `5.8.0-beta.25`，Schema 继续保持 135。
- 主页同步总状态只允许显示“已同步 / 同步中 N / 同步失败 N / 同步检查中 / 未登录”，不得把内部 pending/confirmation 状态作为新的用户状态。
- “同步失败 N”必须对应真实可枚举工作；阅读进度、SAFE 阅读时间和批注均需有可点击处理入口，“全部重新同步”必须调用统一重试管线。
- 阅读时间只有 `pending_report_safe=true` 且秒数大于 0 时才进入可重试池；请求可能已发出后必须清除 SAFE replay，禁止重复计时。
- 进度恢复必须先验证云端，再只对明确未提交/明确不一致的精确快照执行写入。
- 当本地和云端同时存在 `chapter_uid + co` 时，最终成功判定不得由 percent 近似覆盖；源码中不得存在 `mapped_percent_equivalent` 或 `equivalent_percent_tolerance`。
- beta.24 chapter-UID rescue 可继续用于导航，但 rescue 本身不得标记 verified；最终仍需精确坐标验证。
- beta.24 的性能、下载连接复用、reader context 复用、Store、扩展中心、书架与评论回归必须继续通过。

## 自动验证

```bash
python3 tools/verify_beta25.py
```

当前构建结果：`checks=319 failures=0`。该 verifier 同时运行 136 个 shipped Lua 文件的语法检查和可移植动态回归测试。

补充：`tools/test_reader_context.lua` 需要 KOReader/LuaJIT 提供的 `bit` 模块；当前构建容器没有该模块，因此该专项测试无法在本容器启动。失败发生在模块加载阶段（`module 'bit' not found`），不是测试断言失败。

Release ZIP 必须只有一个 `miuread.koplugin/` 根目录；源码 ZIP 不包含 `.git`。

---

# 5.8.0-beta.22 verification

## 完成标准

- PR #73 的 WeRead TCP/TLS 连接复用正式纳入 beta.22，`Config.HTTP_KEEPALIVE=true` 为默认开关，设置为 `false` 时必须完整回退到原有一请求一连接路径。
- 连接复用必须是逐请求显式 opt-in：只有下载链路传入 `keepalive=true`；登录、书架、阅读进度、阅读时长、批注、评论点赞及其他普通 HTTP 调用不得自动进入连接池。
- 仅 WeRead 域名且非流式落盘请求允许进入连接池；流式图片/大文件继续使用原有独立连接。
- 响应只有在 Content-Length、chunked、204 或 304 等可明确界定响应体边界时才允许回池；`Connection: close`、HTTP/1.0 未声明 keep-alive、流错误或异常交换必须关闭连接。
- 空闲连接超过 25 秒必须失效；单连接达到 64 次使用上限后不得继续回池；取用前必须通过 `socket.select` 检测陈旧连接。
- 复用连接提前失效时，仅 GET / HEAD 可在没有收到响应字节的前提下透明重建一次；POST 不得在连接池层自动重放，继续交给原有调用方 retry。
- 下载任务无论正常完成、取消还是异常退出，都必须执行 `close_idle_connections()`；限流冷却和网络恢复探测前同样必须清理连接池。
- 下载汇总日志必须继续提供 `elapsed / network / pacing / ratelimit / throttle / requests / connections / reused / bytes`，便于真机 A/B 与后续故障定位。
- 版本必须为 `5.8.0-beta.22`，Schema 继续保持 135；不因为网络优化增加设置迁移。
- beta.21 在线评论点赞、beta.20 Issue #105 分组恢复与 100 本提醒、beta.19 阅读时长/SAFE pending/精确进度/后台稳定性等回归保护必须全部继续通过。

## 自动验证

- `python3 tools/verify_beta22.py`
- `texlua tools/test_http_keepalive.lua`
- `texlua tools/test_online_comment_likes.lua`
- `texlua tools/test_shelf_group_recovery.lua`
- `texlua tools/test_readtime_recovery.lua`
- `texlua tools/test_store_repair.lua`
- `texlua tools/test_store_shared.lua`
- `texlua tools/test_extension_catalog.lua`
- `texlua tools/test_extension_download.lua`
- `texlua tools/test_extension_install.lua`
- `texlua tools/test_digest_stream.lua`

Release ZIP 必须只有一个 `miuread.koplugin/` 根目录，插件版本必须为 `5.8.0-beta.22`，Schema 必须为 135。
