# 5.9.0-beta.2 — Cloud Mirror Stabilization

本版本不增加新的业务功能，专门稳定 5.9.0-beta.1 的自动 latest-wins 与发布链路。Schema 继续保持 136。

## 阅读位置 freshness 修正

- 本地页面被打开、读取或恢复只会产生技术性 `captured_at`，不再因此被当成新的阅读事件。
- latest-wins 只使用明确的 `updated_at`、progress sequence、verified anchor 与云端真实更新时间判断新旧。
- 第一次读取一本旧 EPUB 不会因为“刚刚打开”而压过真正更新的微信云端位置。
- 书架 resolved progress 与开书 position resolution 使用同一套 freshness 规则。

## 晚到/乱序云端响应保护

- 新增 `prefer_nonstale_remote()`。
- 如果当前 session 已保存一个更新的云端状态，而随后收到的另一个响应拥有明确更旧的服务器时间，且位置不同，则忽略这条旧响应。
- 只有“能够证明更旧”的响应才被拒绝；没有服务器时间戳的响应不会被主观判成 stale。
- 该保护用于防止并发恢复、网络抖动或慢请求在后返回时把阅读位置倒退。

## Release/CI 加固

- CHANGELOG 统一为 `# Changelog` + `## <version>`。
- Release workflow 如果发现 `# 5.9.0-beta.x` 这种错误一级版本标题，会直接给出改为 `##` 的明确提示。
- GitHub Actions 发布前除全库 Lua syntax 外，还会执行 `test_position_resolution.lua`、`test_cloud_freshness_contract.lua` 和 `verify_590_beta2.py`。
- 防止“源码版本正确，但 Release 因 CHANGELOG 结构错误才在最后阶段失败”的情况再次发生。

## 保留 beta.1 行为

- 打开书自动 latest-wins，不再要求用户选择本机/云端。
- 打开时显示“正在同步最新阅读位置…”，2.5 秒软超时后可先使用本机。
- 用户已经开始阅读后，晚到云端不能突然跳页。
- 云端位置必须有可验证 `chapter_uid + co`；跳转后 exact verification 失败会回滚本机。
- 自动云端跳转成功后保留 8 秒撤回。
- 微信书架默认 cloudOrder；finished 与 position 分离。
- percent 继续只用于导航，不作为 exact success 判据。

## 本版本不包含

- #79 双语翻译。
- #113 个性化推荐。

这两项继续与 5.9 的核心同步稳定化隔离。
