# 5.9.0-beta.5 — Sync Correctness & Lightweight Reconciliation

本版本以 5.9.0-beta.4 为基线，只收口阅读同步链路；不新增翻译、扩展中心或下载功能。Schema 继续保持 136，beta.4 的 position-state 标量化与启动 StoreRepair 保留。

## 1. 开书同步改为非阻塞轻量对账

打开书籍后立即恢复 Kindle 本地页面，云端位置在后台确认。6 秒只限制“正在后台确认云端位置…”提示，不再锁输入，也不再代表本机获胜。

开书瞬间冻结 `open_local_snapshot`（`chapter_uid + co + local_read_at + local_seq`）。已有精确本地快照时，自动路径先做一次 raw remote metadata fetch，再决定是否需要 source mapping / XPointer；只有 remote 确认更新时才进入重型定位。已精确对齐的同书结果可在 60 秒内复用，旧缓存绝不能授权本机写云端。

## 2. latest-wins：用户操作不再等于 local wins

beta.4 的 `automatic_check_after_user_interaction` / late-remote local-wins 语义已移除。

统一 resolver 使用：

- local 与 remote 相对上一次可信 verified anchor 的变化关系；
- 双方都变化或无可靠 anchor 时，再比较真实阅读事件时间；
- 时间差处于 120 秒 clock-skew grace 且位置不同、又无法由 anchor 判断时，进入 `conflict`，不猜测赢家。

普通翻页只影响“现在是否适合自动跳转”，不改变开书前 freshness。目录/搜索/进度条等明显大跨度 reposition 会阻止晚到 remote 突然打断阅读，但同样不会授权本机覆盖 remote。

## 3. progress write fence

自动进度写入增加持久安全栅栏。以下状态默认禁止本机进度写回微信读书：

- remote fetch 尚未完成或失败；
- remote newer / remote newer pending；
- conflict；
- remote exact mapping / verification unresolved。

栅栏覆盖周期、结束阅读、后台 retry 等自动写入入口。只有 resolver 明确确认 `LOCAL_NEWER`、双方重新 `ALIGNED`，或用户显式执行手动本机上传时才允许写入。

离线 Kindle 恢复网络后同样必须先读取 current remote，再决定是否上传本机 pending progress。

## 4. canonical progress 与 raw percent 分离

微信返回的 `raw_percent` 只保留为诊断值。只要存在可信 `chapter_uid + co`，canonical progress 必须由精确坐标映射得到。

`raw_percent` 不再参与：

- latest-wins；
- CloudAnchor canonical progress；
- verified anchor；
- reading-time position guard；
- finished / 100% 判断。

Finished 继续要求独立的末章 + terminal-coordinate 条件，服务器单独返回 100% 不具权威性。

## 5. exact-co：text anchor / XPointer 优先

remote newer 时的定位顺序收敛为：

1. 已验证 `chapter_uid + co -> XPointer` 缓存；
2. 初始 direct / approximate jump；
3. `chapter_uid + co` exact verify；
4. 未命中时，从 remote co 周围提取短正文 anchor，在对应本地章节 `findAllText()` 并恢复 XPointer；
5. 再次 exact verify；
6. 最多一次 bounded percent fallback；
7. 仍失败则 rollback，并保持 write fence。

不再使用多轮 percent correction 作为迭代求解器。

## 6. 阅读时间降级为 best-effort

阅读进度仍按强可靠链路处理；阅读时间改为统计型 best-effort：

- 正常发送一次；
- busy / 临时失败后，运行期空闲时最多再尝试一次；
- 第二次仍失败直接 drop；
- 不跨重启持久化 reading-time debt；
- 不再把阅读时间失败显示为主页长期同步失败。

beta.5 首次启动会清理 beta.4 遗留的 reading-time pending/retry/failure 状态，但不会清理进度 pending、verified anchor 或批注 pending。

## 7. 保持不变

- Schema 136。
- beta.4 position-state stack overflow 热修和启动自愈。
- `chapter_uid + co` 仍是最终进度确认依据。
- PR #120 翻译、Extension Center、下载系统、#117/#118、低内存保护等不在本版改动范围。
