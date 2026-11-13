# Android / OHOS rc.1 补丁集合（E0 候选）

基于合入上游 main efa70c15 后的 139 个公共补丁（上游 `series` 139 条，本 fork 已删除 `series`，改用 `pins.json` 的 `targetSets`）。两个 target 都以 `pins.json` 里 `targetSets` 的声明顺序为应用顺序（即上游 series 顺序；上游文件名序不等于应用顺序，按文件名排序会造成哈希链断裂），OHOS 先走同一 139 公共链，再 19 个专用层。schema2 要求显式 target、所有 diff 恰好登记；无默认目标。

本轮随上游新增 3 个公共补丁，按上游 series 位置插入两个 target：`client-hmr-closed-response.diff`（索引 10）、`fs-publication-short-names.diff`（索引 108）、`webserver-resource-abort.diff`（索引 138）。三者的 pin 由 pristine 0.2.2-rc.1 上真实应用该链逐段复算，6 个哈希与上游 `pins.json` 的同名条目完全一致。本轮未重锚任何专用 overlay：19 个专用层在上游修订后仍全部可应用，无冗余新增（上游这 3 个补丁都不覆盖任何现有 overlay 的行为）。

历史：更早一轮上游修订了 3 个公共 diff（`plugin-manager-cancel-tree-confirmation.diff`、`zzzzzz-session-deletion.diff`、`zzzzzzz-file-reference-owner-dispose.diff`），连带 15 条 pin 位移，一律取上游值。原 21 个专用层中的 `zzzzzzz-ohos-fs-exclusive.diff` 与 `ohos-discovery-response-cleanup.diff` 已移除：上游公共补丁 `fs-create-link-denial.diff`、`piai-discovery-response-cancel.diff` 已在所有平台（不只 OHOS）实现同一行为，专用层再叠一次不会改变结果。

共享 rtbuild 只增加显式选择、完整 chain 预检和目标报告；build-runtime.sh 传 android。本轮已在 pristine 0.2.2-rc.1 前缀（npmmirror + `runtime/locks/dsh-0.2.2-rc.1` 锁安装，589 包）上实测：android 139 补丁 / 100 个文件、ohos 158 补丁 / 112 个文件，两目标均 exit 0、补齐链断数 0、二次运行全部 `already patched`；完整 Android 归档门尚待执行，不能把前缀结论称整个 APK/runtime 一致。

rc.4 旧集合不再可执行：其 19 个专用 diff 已为 rc.1 适配，旧 pin 历史存在不代表该旧版可应用（`zzzzzz-session-deletion.diff` 的 rc.4 pin 已随上游修订一并删除）。鸿蒙分支 37aa836e 仍 rc.4，本候选不修改该远端；其后续若升级必须整体跟随本版锁、集合和组成，不能只复制 pins。

具体移植及未采纳配套见交付报告；当前为未冻结中间候选。
