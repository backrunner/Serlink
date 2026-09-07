# Serlink 性能审查

审查日期：2026-09-07。代码基线：`f534e73`。

已完成一轮优化，覆盖终端搜索、传输进度、同步、数据库索引和 SFTP。
以下是同一台机器、同一诊断探针下的前后对比；后面的审查章节保留修改前的证据与后续候选。

## 本轮实现与复测

| 指标 | 修改前 | 修改后 |
| --- | ---: | ---: |
| 10,000 个匹配的搜索刷新中位数 | 103.309 ms | 5.852 ms |
| 每次搜索刷新通知数（10,000 个匹配） | 20,002 | 1 |
| 8 次搜索并清除后残留 anchor | 160,000 | 0 |
| 20 次分散传输保存引起的完整主机列表重载 | 20 | 0 |
| 上述保存与主机刷新场景总耗时 | 2,054.939 ms | 4.753 ms |
| 100 条记录中改 1 条，记录对象上传数 | 100 | 1 |
| 同步独立对象请求并发上限 | 1 | 4 |
| 主机类型查询访问路径 | SCAN | SEARCH，使用 `(type, id)` 索引 |

具体行为：

- 搜索高亮拥有并释放其 anchor；批量移除高亮与变更通知。输出触发的搜索刷新限为每 100 ms 一次，隐藏工作区暂缓扫描，重新显示后刷新。
- 主机和片段列表按记录类型订阅；连续传输进度最多每 100 ms 更新一次，进度检查点每 1 秒保存一次；状态变化及时保存。恢复未发生变化的历史记录不再重写。
- 传输记录引起的自动同步按 2 秒固定窗口合并，持续传输不会无限推迟同步；普通主机编辑和显式同步保持及时响应。
- 同一轮 pull 内复用已读取对象，读取与上传最多 4 个并发；上传仅跳过本轮已验证且内容完全相同的远端对象。条件提交、撤销检查和失败清理保持原有边界。
- 每轮仍读取和验证全部远端记录，100 条记录场景的读取数仍为 100。这样仍能检测对象缺失和损坏；跨轮增量下载缓存留待单独设计，不能把本轮优化描述为零读取的无变化同步。
- 本地 Drift schema 从 v6 升到 v7，新增 `encrypted_records_type_id`。远端 Vault/sync 版本没有变化。
- SFTP 下载每累计 256 KiB 等待一次 flush，结束时 flush 最后一批，并单独观察 sink 异步错误；目录缓存最多保留 16 个目录、50,000 个条目，按最近使用顺序与 TTL 淘汰。

回归覆盖搜索 anchor 释放与通知次数、传输节流与状态保存、无关记录过滤、自动同步窗口、缓存容量与过期、v6 迁移保留密文、同步并发与单条上传、损坏/缺失对象以及并发上传失败清理。
本地 AsyncSSH 集成验证包含 1 MiB + 37 字节文件的准确下载、暂停恢复、目录传输和文件属性；测试使用 loopback 和临时目录。

最终验证：全量运行通过 778 项，另有 3 个文件因 Flutter 测试子进程的本地 WebSocket 启动连接错误未加载；这 3 个文件串行重跑后 6 项全部通过，累计覆盖 784 项通过。
1 项可选原生 OpenSSH PTY 测试因未启动独立 sshd 而跳过。`flutter analyze --no-pub` 无问题，四组性能探针通过。
SFTP 集成还验证了本地文件打开失败能作为传输错误正常返回，不产生未处理的异步异常。

这些数据依旧来自 debug/JIT 测试，不能替代 release/profile 真机帧率和真实服务器吞吐量测量。

## 验证范围和方法

- 静态检查启动、Drift 数据库、Vault 加解密、终端输入输出与搜索、工作区列表、SFTP、传输队列和同步。
- 在 Apple M4、Flutter 3.44.4、Dart 3.12.2 上运行四组诊断探针。
- 探针使用合成数据、内存数据库和自动删除的临时同步目录；不会读取真实 Vault 或连接真实服务器。
- 耗时来自 `flutter test` 的默认 debug/JIT 环境，没有完整窗口渲染，不能直接当作 release 帧耗时或真实网络吞吐量。
- 测量加密记录时使用测试 KDF 以缩短准备时间；没有测量生产参数下的口令解锁耗时。

复现命令：

```sh
flutter test tool/performance_audit_test.dart --reporter expanded --concurrency=1
flutter analyze --no-pub tool/performance_audit_test.dart
```

探针输出 JSON 指标，没有固定耗时阈值，不会把当前问题的计数写成必须保持的测试断言。

## 修改前的优先级与证据

| 优先级 | 问题 | 证据 | 建议 |
| --- | --- | --- | --- |
| P1 | 终端搜索留下定位对象，刷新开销随匹配数快速增长 | 10,000 个匹配时刷新中位数 103.309 ms；8 次搜索并清除后残留 160,000 个 anchor | 修复 anchor 生命周期；批量清除/更新高亮；合并刷新，随后考虑增量搜索和仅绘制可见匹配 |
| P1 | 传输进度保存连带重载无关数据，并请求同步 | 1,000 台主机下，20 次分散保存触发 20 次完整列表重载 | 按记录类型订阅；分别限制 UI 刷新和持久化频率；为同步合并连续进度变更 |
| P1 | 同步串行读全量，单条变化仍写全量 | 100 条无变化时读取 100 个记录对象；改 1 条后读取 100 个、写入 100 个 | 依据已认证 manifest 的版本信息复用已验证对象；增量上传；对独立对象使用有限并发 |
| P2 | 加密记录按类型查询没有对应索引 | SQLite 执行计划是全索引扫描；候选 `(type, id)` 索引将其变为索引查找 | 数据量基准确认收益后，按本地 Drift 迁移流程增加索引 |
| P2 | SFTP 每个下载块都等待 sink flush；目录缓存未限制容量 | 代码检查确认，尚未测量真实服务器吞吐量或缓存内存 | 测量批量写入与有界背压；目录缓存增加容量限制和过期淘汰 |

## 1. 终端搜索

相关代码：

- `lib/features/terminal/application/terminal_buffer_search_controller.dart`：`search`、`_clearHighlights`。
- `lib/features/workspace/presentation/workspace_screen/terminal_pane.dart`：`_refreshSearchAfterTerminalChange`。
- `third_party/xterm/lib/src/ui/controller.dart`：`TerminalController.highlight`、`TerminalHighlight`。
- `third_party/xterm/lib/src/core/buffer/line.dart`：`createAnchor`、`CellAnchor.dispose`。

搜索开启且查询非空时，终端每次通知变更都会同步重新搜索整个缓冲区。
每个匹配创建两个 anchor 和一个高亮；添加和移除每个高亮都会通知监听者。
移除高亮调用 List 的 `remove`，按当前正序逐个清除时反复移动列表后续元素，形成二次复杂度。
这些通知可以合并成较少的绘制帧，但监听回调和列表操作的成本仍然存在。

更直接的问题是：`highlight.dispose()` 只移除高亮，没有释放它的 `p1`、`p2`。
缓冲区行仍然持有这些 anchor。只要相应缓冲区行仍在，反复刷新就会不断积累无用对象；关闭搜索也不会释放已残留的对象。

探针每行恰有一个匹配，预热 3 次，再测量 5 次刷新，最后清除搜索：

| 匹配行数 | 刷新中位数 | 每次刷新通知数 | 最后清除后残留 anchor |
| ---: | ---: | ---: | ---: |
| 1,000 | 1.760 ms | 2,002 | 16,000 |
| 5,000 | 27.305 ms | 10,002 | 80,000 |
| 10,000 | 103.309 ms | 20,002 | 160,000 |

实现顺序建议：先明确高亮对 anchor 的所有权并释放它们，再提供高亮批量替换/清理能力。
随后合并输出触发的搜索刷新、避免不可见面板做即时搜索，并评估按变化行增量搜索。
输入查询可以短暂防抖，持续输出应采用有最大等待时间的节流，避免一直不刷新。
搜索正确性需覆盖滚动、重排、替换查询、清空查询、切换缓冲区和关闭面板。

## 2. 传输进度放大刷新范围

相关代码：

- `lib/features/sftp/data/dartssh2_sftp_connection.dart`：上传进度回调、下载 `writeChunk`。
- `lib/features/transfers/application/transfer_queue_controller.dart`：`_handleProgress`、`_replaceTask`、`_persistTask`。
- `lib/features/transfers/data/encrypted_transfer_task_repository.dart`：`save`。
- `lib/features/sync/application/auto_sync_controller.dart`：`NotifyingVaultRecordRepository`、`_shouldNotifyRecordChange`。
- `lib/features/hosts/application/host_store.dart`：`hostSummariesProvider`。
- `lib/app/app_dependencies.dart`：`snippetsProvider`、`AutoSyncController.build`。

当前链路：SFTP 进度 → 更新整个任务列表 → 加密保存 → 全局记录变更事件。
主机和片段列表没有按记录类型过滤事件，可能重新读取并解密全部对应记录。
自动同步对本地记录变化请求 `Duration.zero` 的同步；如果已有同步运行，则请求后续再跑一轮。
`transfer_task` 目前属于可同步记录，会进入这一链路。

队列已有“磁盘/加密忙时只保留最新进度”的合并逻辑，但它不是按时间限制保存频率。
因此不能认为每个网络数据块必定落一次盘，也不能认为进度保存已充分限频。

探针准备 1,000 台主机，通过真实加密传输仓库和真实通知仓库保存同一任务 20 次，
每次等待 provider 刷新完成：完整主机列表重载 20 次，总耗时 2,054.939 ms。
这是刻意分散事件后对刷新范围的验证，不代表所有真实进度事件都会重载，也不包含实际 SQLite 写盘。

建议先隔离主机/片段的变更订阅，再将传输 UI 更新控制在适合人眼观察的频率，
持久化使用更低频的检查点，并在完成、失败、取消、暂停等状态边界及时保存。
同步可以合并连续进度变化，同时保留任务最终状态的跨设备语义。
不应为了减少同步流量直接删除现有传输历史同步功能。

## 3. 同步请求数量

相关代码：`lib/features/sync/application/sync_run_service.dart` 中
`_pullEncryptedSnapshot`、`_pushEncryptedSnapshot`、`_remoteSnapshotMatchesLocal`。

拉取逐条等待远端对象，然后才比较本地版本；上传逐条写入所有可同步记录。
代码已有“完全一致时跳过 push”的判断，但它发生在全量 pull 之后。

使用真实同步服务、真实加密主机仓库，以及带计数器的本地目录 provider 测得：

| 场景 | 主机数 | 记录对象读取 | 记录对象写入 |
| --- | ---: | ---: | ---: |
| 完全无变化，再同步 | 100 | 100 | 0 |
| 修改一台主机，再同步 | 100 | 100 | 100 |

这些计数只包含 `records/` 对象，不包含 manifest、header、reset marker 等额外操作。
本地计数验证服务调用模式；不能把它直接等同于 CloudKit 或 WebDAV 的真实请求耗时。
作为延迟模型，100 个串行请求、每个固定等待 50 ms，仅这一段等待就约 5 秒，尚未计入其他工作。

优化时优先复用已验证的相同版本对象、只上传发生变化的不可变记录对象，并对互不依赖的对象使用有限并发。
manifest 条件提交必须放在所有必要对象写入完成之后；设备撤销、tombstone、冲突合并和失败清理仍需保持原有语义。
跳过对象读取还需要考虑远端缺失/损坏的检测与修复，不能只比较明文元数据后无条件跳过。

## 4. 数据库和 SFTP 的后续优化候选

`DriftVaultRecordRepository.list(type: ...)` 使用 `WHERE type = ? ORDER BY type, id`。
`encrypted_records` 当前只有主键索引。探针执行计划：

```text
当前：SCAN encrypted_records USING INDEX sqlite_autoindex_encrypted_records_1
临时添加 (type, id) 索引后：SEARCH encrypted_records USING INDEX audit_type_id (type=?)
```

这个变化验证了访问路径，没有量化真实磁盘上的耗时收益。
大量传输历史和少量主机混存时尤其值得测量；索引也会增加写入成本。
如实施，遵守 `docs/development_schema_versioning.md` 的本地迁移规则，兼容的查询优化不需要提升远端 Vault/sync schema。

SFTP 下载每块 `sink.add` 后都 `await sink.flush()`，并暂停订阅等待写入完成。
它已有背压，但也缩小了写入合并空间。应比较适度批量写入或流式消费，同时保留内存上界、取消和错误处理。
这里的 `IOSink.flush()` 不能等同于每块都执行磁盘 fsync。

目录缓存有 5 秒 TTL，但 TTL 只决定命中与否，缓存 Map 没有容量限制或主动过期淘汰。
同一面板连续浏览大量大目录时可能保留很多已过期的 entry 列表；适合加入 LRU/容量限制。

## 已有的性能措施与验证空白

- 启动先 `runApp`，窗口激活安排在首帧之后。
- SQLite 使用 `NativeDatabase.createInBackground`；迁移预检和 quick check 也已放到 isolate。
- 当前 cryptography 2.9.0 的原生 Argon2 实现会使用 isolate；不能因为业务层没有 `compute` 就认定口令 KDF 阻塞 UI。应保持现有安全参数，先测量真实解锁流程。
- 终端输出已有事件循环级合并，resize 有 80 ms 防抖；持续大流量下仍需验证单次解析工作量与帧预算。
- 工作区隐藏区域使用 `Offstage` 和 `TickerMode`，但它们不会自动停止终端流监听和搜索计算。
- 主机/传输/SFTP 列表已有按需构建，SFTP 已有目录缓存，传输队列默认并发数为 2。

目前没有测量 release/profile 的冷启动、帧耗时、GPU、实际 RSS 或真实 SFTP/WebDAV/CloudKit 吞吐量，
因此不能据此给“总体流畅”或“总体慢”的结论。
后续应围绕持续日志输出与搜索、多个后台会话、后台传输同时浏览主机、高延迟同步和长期目录浏览，
采集帧耗时分位数、CPU/RSS、数据库写入次数与网络请求数，再做同场景优化前后比较。
