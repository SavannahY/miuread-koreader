# 5.9.0-beta.12

本版以 beta.11 为稳定基线，只修复两个真机日志已经确认的同步边缘问题。精确位置 resolver 在本地 exact/legacy source cache 无法匹配当前 anchor 后，network recovery 现在会显式绕过这份失败缓存并真正重新获取微信读书章节 `coord_html`；成功后更新 exact cache，失败则继续保持 rollback/fence 的 fail-closed 安全策略。

reading-time writer 抢占仍保持单 writer 互斥，不采用 immediate detach。beta.12 在原有 `kill(pid, 0)` 之外增加 KOReader `FFIUtil.isSubProcessDone(pid, false)` 子进程完成确认，避免已退出但尚未按旧方式判死的 worker 被误报为 `time_writer_preempt_timeout`。

主页短按/二级菜单统一 progress recovery、wake online-ready gate、pending_send / submitted_unverified、progress submit/verify、local/remote resolver、translation 和 Release 流程均保持 beta.11。Schema 仍为 136。
