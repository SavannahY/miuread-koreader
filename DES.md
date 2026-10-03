# 5.9.0-beta.11

本版以 beta.10 为基线，收口手动同步入口与唤醒网络时序。主页短按“同步”、同步状态“全部重新同步”和进度失败页“全部重新同步”统一进入同一个 durable progress recovery helper，并在进入前统一执行登录与 Wi-Fi gate；即使主页缓存暂时显示 0 个失败项，手动同步仍会先完成 progress verification/recovery pass，再处理 SAFE 阅读时间与批注。设备/Kindle 唤醒后的自动进度对账新增 online readiness gate，不再把 `NetworkConnected` 直接视为微信读书 API 已可用。

本版不采用高风险的 time-writer detach 方案，`miuread/sync.lua` 保持 beta.10/beta.8 字节不变；完整保留 beta.10 的 translation 顶层纯 Lua、数字 bookId 支持以及“先测试后建 tag”的 Release 流程。Schema 仍为 136。
