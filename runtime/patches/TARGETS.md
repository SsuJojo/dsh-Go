# Android / OHOS rc.1 补丁集合（E0 候选）

基于锁定上游 main 288234ae 的 136 个公共补丁。两个 target 都以 `pins.json` 里 `targetSets` 的声明顺序为应用顺序（即上游 series 顺序；上游从本轮起文件名序不再等于应用顺序，按文件名排序会造成 9 处哈希链断裂），OHOS 先同一 136 公共链，再 19 个专用层。schema2 要求显式 target、所有 diff 恰好登记；无默认目标。

上游本轮修订了 3 个公共 diff（`plugin-manager-cancel-tree-confirmation.diff`、`zzzzzz-session-deletion.diff`、`zzzzzzz-file-reference-owner-dispose.diff`），连带 15 条 pin 位移，一律取上游值。原 21 个专用层中的 `zzzzzzz-ohos-fs-exclusive.diff` 与 `ohos-discovery-response-cleanup.diff` 已随本轮移除：上游公共补丁 `fs-create-link-denial.diff`、`piai-discovery-response-cancel.diff` 已在所有平台（不只 OHOS）实现同一行为，专用层再叠一次不会改变结果。

共享 rtbuild 只增加显式选择、完整 chain 预检和目标报告；build-runtime.sh 传 android。本轮已在 pristine 0.2.2-rc.1 前缀上实测：android 136 补丁 / 99 个文件、ohos 155 补丁 / 111 个文件，两目标均 exit 0 且二次运行幂等；完整 Android 归档门尚待执行，不能把前缀结论称整个 APK/runtime 一致。

rc.4 旧集合不再可执行：其 19 个专用 diff 已为 rc.1 适配，旧 pin 历史存在不代表该旧版可应用（`zzzzzz-session-deletion.diff` 的 rc.4 pin 已随上游修订一并删除）。鸿蒙分支 37aa836e 仍 rc.4，本候选不修改该远端；其后续若升级必须整体跟随本版锁、集合和组成，不能只复制 pins。

具体移植及未采纳配套见交付报告；当前为未冻结中间候选。
