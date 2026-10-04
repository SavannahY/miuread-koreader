# 5.9.0-beta.19

本版集中修复两件已经由 beta.18 真机日志明确分离的问题：本地→云端的 `source_anchor_not_found`，以及云端→本地已经通过正文唯一锚点精准落地却仍向用户暴露内部 co 验证失败。

本地→云端不再只依赖一条 `forward_24`。`PrecisePosition.capture()` 会围绕同一 XPointer 生成 `forward/backward 24、16、12` 六类 immutable anchor，`SourcePosition` 在同一微信 `coord_html` 上逐个做 exact source mapping。每个候选仍需唯一文本命中；若两个成功候选导出不同 native `wr_data_co`，直接返回 `anchor_coordinate_conflict`，不按距离、百分比或相似度猜测。当前 TOC 标题可提供 exact-title 章节候选，仍必须经过正文锚点验证。

为处理 EPUB 与微信源码中纯格式字符差异，新增 progress-source 专用 `PosMap.locateSource()`：只忽略普通空白之外的 NBSP、零宽字符、soft-hyphen、BOM/word-joiner 和 wr-star。它不改变 annotation 的 `PosMap.locate()`，也不做编辑距离、大小写/标点模糊。最终上传坐标仍由原始 `coord_html` 经 `WRCo.fromMap()` 生成真正 native `wr_data_co`。

beta.18 的 `fresh_context=true` 继续保留：缓存源无法定位时重新获取目标章节 Web Reader context/source，再跑完整多锚点流程。仍失败则 fail closed。

云端→本地保持现有 `chapter rescue -> text_anchor_xpointer -> exact verify` 主链。只要 `text_anchor_xpointer` 已唯一命中正确章节，就保留这个正文落点，不再因为反向 local->wr_data_co 暂时失败而继续 percent correction，也不向用户显示“精确章节内位置暂未确认”。后台仍保留 `remote_exact_unresolved` write fence，因此“用户看到定位成功”不会被当成“本地坐标已可安全写云端”。真正没有正文唯一命中、只到章节附近时仍给出简洁提示。

ReadReport v30、fresh-GET-before-POST、ghost-write guard、beta.17 progress epoch/冲突生命周期与上传后的 exact cloud readback 均不改。Schema 保持 136。
