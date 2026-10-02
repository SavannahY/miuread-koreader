# 5.9.0-beta.4 — Position Sync Hotfix

本版本以 5.9.0-beta.3 为基线，只修复 5.9 Cloud Mirror/自动续读链路中的两个严重问题。Schema 继续保持 136；PR #120 外文翻译、Extension Center UX、#117/#118 增强修复均完整保留。

## 1. 修复 position_state stack overflow

5.9 beta.1–3 的云端位置对象可能附带运行时诊断字段 `sources`。该字段在某些路径中包含 `sources.web -> 当前 remote 对象` 的自引用。若整个 remote 对象进入 `position_state.remote_position`，Store 下一次深度 `U.merge()` 会沿循环图不断递归，最终触发 LuaJIT `stack overflow`。

本版本做三层保护：

- `position_state.local_position / remote_position / verified_anchor` 只允许保存明确白名单中的 string/number/boolean 标量坐标。
- `Store:save_session()` 在深度 merge **之前**先压缩现有 session 和 incoming patch，循环诊断图不会再进入 merge。
- 启动时检查 beta.1–3 已留下的嵌套位置快照；只有发现嵌套/循环风险时才自动压缩并落盘，正常设置不会每次启动重写。

本地位置快照仍保留同步所需的 `progress / chapter_uid / co / basis / native_offset / sequence / epoch` 等字段，不降低精确同步能力。

## 2. 修复 latest-wins 锚点误判

云端请求完成后，MiuRead 会保存 `remote_observed` 作为“刚刚看到的云端位置”。它不是本机和云端曾经共同确认过的位置。beta.1–3 在没有旧 verified anchor 时可能把这个刚观察到的 remote 当作历史 `verified_anchor`，从而得出错误结论：

> remote 与 anchor 相同 → remote 未变化；local 与 anchor 不同 → local 更新 → 错选本机。

现在：

- 开始云端请求前先冻结 pre-fetch resolution context。
- `remote_observed` 永远不能作为 verified anchor。
- 只有 `verified_chapter_uid + verified_chapter_offset`、有效 `remote_verified` 历史或已确认 aligned state 才能构成 trusted anchor。
- 第一次对账且本机没有 durable local event 时，带可靠更新时间的云端位置可以正常胜出。

这避免了“云端已经在末章/100%，本机刚打开第 1–2 章，却把本机错误上传覆盖云端”的风险。

## 3. 开书同步体验

默认 `OPEN_SYNC_SOFT_TIMEOUT_SECONDS` 从 **2.5 秒**调整为 **6 秒**。Kindle 上精确本地映射 + 微信云端读取常常需要 3–5 秒；原 2.5 秒会过早解除保护并提示云端未确认，与“先同步最新位置再允许翻页”的目标冲突。

6 秒内继续显示：

> 正在同步最新阅读位置…

若 6 秒后仍未完成，才先使用本机位置，并提示：

> 云端响应较慢，已先使用本机位置；后台继续确认

用户开始翻页后，晚到的云端结果仍不得突然跳转。

## 4. 保持不变

- Schema 136。
- `chapter_uid + co` 为最终精确验收依据，percent 仍只用于导航。
- 8 秒自动定位撤回、late-remote 用户交互保护。
- PR #120 原文 / 双语 / 仅译文、官方译文生成和 EPUB 安全替换。
- Extension Center 后台发现更新、推荐列表隐藏旧版本号、下载页首屏扩展入口和批量更新。
- #117 clipboard / 1%→100% 修复和后续终态保护。
- #118 XML/CDATA/identity 与后续 MiuRead manifest/XMP 防污染。
