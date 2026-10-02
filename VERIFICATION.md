# 5.9.0-beta.1 Verification

## 5.9 专项 verifier

运行：

`python3 tools/verify_590_beta1.py`

结果：**30 checks, 0 failures**。

覆盖：版本/Schema 136、latest-wins、首次云端权威规则、远端 fetch/update 时间分离、ReaderReady 即时 opening guard、2.5 秒本机 fallback、late-remote 用户交互保护、120 秒时钟容差、8 秒撤回、云端书架默认排序、finished 三态、position_state 双写、精确坐标 fail-closed、失败跳转 rollback、登录/网络恢复以及旧冲突选择框移除。

## Portable Lua regression tools

在当前容器的 `texlua` 环境下：

- **23 个 `tools/test_*.lua` 通过**。
- **1 个环境跳过**：`test_reader_context.lua`。stock `texlua` 缺少 KOReader/LuaJIT 的 `bit` 模块，测试在加载 `protocol.lua` 时即停止，尚未执行任何 assertion；因此不记作通过，也不记作 5.9 断言失败。
- **0 个非环境测试失败**。

其中 5.9 新增/扩展测试包括：

- `test_position_resolution.lua`
- `test_cloud_shelf_sort.lua`
- `test_open_sync_contract.lua`
- `test_finished_resolution.lua`
- `test_long_book_anchor.lua`
- `test_cloud_mirror_contract.lua`
- `test_schema136_contract.lua`

同时 beta.26 的 clipboard、progress ratio、100% terminal guard、metadata、generated relink、download safety 等 portable tests 继续通过。

## Lua syntax

`miuread.koplugin` 内 **137 个 Lua 文件全部通过 `texluac -p`，0 syntax failures**。

## beta.26 compatibility verifier

对 5.9 工作树运行旧 `tools/verify_beta26.py`：337 项中只有 **8 项失败**，均为 5.9 有意改变的旧契约：版本号、Schema 135、旧版本 metadata 断言、旧“本机/云端冲突提示/重复提示”交互，以及 beta.26 的旧章节冲突 UI。其余 beta.26 安全/稳定性不变量继续通过。

这项结果不表示 5.9 满足 beta.26 的 UI 契约，而是用于确认本次代际升级没有无关地破坏其余旧回归项。
