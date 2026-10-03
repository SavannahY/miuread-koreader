# 5.9.0-beta.14

本版以 **5.9.0-beta.12** 为代码基线，目标是收敛阅读进度同步，而不是继续扩展 beta.13 的新定位架构。beta.13 的跳转前 exact preflight 与主动 idle exact-cache 被撤销；云端较新时恢复 beta.7/9/12 已在真机验证有效的“近似落点 → 精确验证 → text-anchor rescue → 再验证”流程。

远端落点失败现在区分 hard mismatch 与 soft mismatch：如果实际落入错误章节，继续 rollback 保护本地阅读位置；如果已经进入云端目标章节、只是章节内 `wr_data_co` 无法达到 strict exact，则保留当前章节位置，不再自动跳回，同时维持 `remote_exact_unresolved` fence，绝不会把近似坐标当成精确值写回云端。OpenSync 也会识别用户在等待云端结果期间发生的真实翻页/跳转，迟到的云端结果只保留 pending，不再突然抢位置。

退出阅读时，KOReader 本地 `local_display_progress` 与 XPointer 会先独立持久化，再尝试微信 exact `chapterUid + wr_data_co`。因此 `source_anchor_not_found` 只会影响本次云端精确上传，不再让主页进度一起失效。主页、书架与 RecentHero 引入 `progress_known` 语义：未知值保持 unknown 并显示“—”，只有明确的 0 才显示 0%。

exact cache 改为纯被动：只有既有同步流程已经获得原生 `wr_data_co` 时才顺手保存，退出时也只有 XPointer 完全一致才复用；不再在打开书、翻页、目录或 idle 时额外运行精确 resolver。保留 beta.12 的 source cache 强制刷新、`FFIUtil.isSubProcessDone` writer completion、pending/verify recovery、严格 exact 校验与 fail-closed 云端写入。Schema 仍为 136。
