# 5.9.0-beta.9

本版只做主页同步入口一致性和诊断增强。主页短按“同步”会先强制刷新同步状态，再进入与“同步状态 → 全部重新同步”相同的 recovery pipeline；新增 `SyncAction` source/结果日志，便于直接比较短按与二级菜单行为。进度提交/确认、安全重传、worker、resolver、reading-time daemon 等同步核心算法不改，Schema 仍为 136。
