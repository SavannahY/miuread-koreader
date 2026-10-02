# 5.8.0-beta.26

## 本版定位

Open Issue Cleanup / Stability。基于 beta.25，不引入双语翻译或推荐等新功能。

## #111 剪贴板

修正 `Device.input.setClipboardText` 调用方式。该 API 是普通函数，评论复制和书摘复制现在只传入字符串，避免剪贴板出现 `table: 0x...` 以及后续输入法异常。beta.25 已有的评论文本正规化继续保留。

## #115 假 100% 防护

微信读书 `book.progress` / `remote_progress` 明确按 0–100 百分比转换，和本地 0–1 ratio 分离；数值 `1` 在微信字段中固定表示 1%。兼容 read-report worker 额外增加 100% 终态门禁：只有位于目录最后一个有效章节时才允许提交 100%，否则 fail closed。

下载链路继续保持 read-only：`Downloader` 不调用阅读进度提交接口，下载百分比与阅读百分比在回归测试中分离。

## #107 元数据与已生成关联

OPF identity 字段新增数字 XML entity、CDATA 解析，并避免将 title/author 当 HTML 清理。微信书架已有身份字段不被普通 OPF 覆盖；MiuRead EPUB 继续以 `OEBPS/miuread.json` 和 protected title/author 为最高优先级。

主页手动刷新会检查下载目录中没有 Store 记录的 EPUB 候选，并按单文件增量调度调用现有 `recover_miuread_file()`。只有确实含 MiuRead embedded book id 的 EPUB 才会恢复关联；普通 EPUB 不会被误认成微信书籍。

## #114 长篇跨设备定位

不采用“章节一致即可 verified”的宽松方案。percent 只做初始导航；跳错章节时继续使用 chapter UID rescue，随后必须重新获得 chapter_uid + co 并完成精确验证。多设备冲突提示增加本机/云端章节号与云端更新时间。

## #116 低内存下载

重型下载阶段每 5 秒采样一次可用内存；连续两次低于约 72 MB 才请求 checkpoint + hibernate。单次瞬时低内存不会中断任务。原有启动 96 MB / 恢复 72 MB、防网络阻塞 UI、Store 写盘优化等全部保留。

## Issue 状态建议

- #111：可标记 Fixed。
- #107：建议实机验证“刷新后无需手动打开即可恢复已生成关联”后关闭。
- #114：建议原 935 章场景复测后关闭。
- #115：已修明确风险并加终态保护，继续观察是否仍有其他根因。
- #116：请 PW5 512 MB 设备复测后关闭。
- #79 / #113：不属于本版。
