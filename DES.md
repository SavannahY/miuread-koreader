# 5.9.0-beta.13

本版集中修复 beta.12 真机日志暴露的阅读进度同步问题，不扩展其它功能，也不重写已经工作的上传协议。

云端位置采用流程改为“先解析、先验证、再跳转”：先生成本地候选 XPointer，再在不可见状态下把该候选反算成微信读书 `chapterUid + wr_data_co`。只有严格 exact，或由内容/已验证 XPointer 支撑且偏差受限的 `verified_near`，才执行一次可见跳转；预验证失败时保持当前页，不再出现“先跳过去—验证失败—又跳回来”的自动 rollback。

本地精确位置解析保留长 anchor 优先；长 anchor 因生成 EPUB 的批注、脚注、排版差异无法命中时，增加边界短 anchor 的唯一匹配 recovery，并记录 recovery strategy。严格 `wr_data_co` exact 容差仍保持原值，不通过简单放宽 co 阈值掩盖映射错误。

开书同步补强 late-remote 保护：后台云端结果尚未完成时，只要用户已经翻页/定位，本轮自动采用即取消。阅读过程中在页面稳定后异步缓存最近一次可信 `chapter/co + source_xpointer`；退出时若即时 resolver 失败但 XPointer 与缓存完全一致，可复用该精确位置进入现有 pending/upload/verify 流程，降低 `position_unavailable` 导致的未上传。

微信服务器原始 percent 明确保留为 protocol/raw metadata；beta.13 的新候选跳转只允许 canonical progress 参与，权威一致性仍由 `chapterUid + wr_data_co` 决定。beta.12 的强制 source refresh、reading-time 单 writer 完成确认、云端回读验证与 session-scoped fence 均保留。Schema 仍为 136。
