# 补丁清单

记录本分支相对上游的每一个改动。升级 rebase 时按这份清单核对。

格式：

```
## 1. <标题>
- 提交: <sha>
- 文件: <path>
- 目的:
- 风险:
- 上游实现变化时的检查点:
```

---

（暂无）

## 待评估

### DMI / cpuinfo 覆盖挂载

- 状态：**未实施**，需先确认 `cli-node` 是否读取这两个路径
- 位置：`src/lib/vm/vm-runtime.mjs` 的 `computerDockerArgs()`
- 做法：新增两个 bind mount
  - `<persona>/system/dmi/id:/sys/class/dmi/id:ro`
  - `<persona>/system/cpuinfo:/proc/cpuinfo:ro`
- 前置验证：`docker exec <槽> strace -f -e trace=openat <cli-node>` 观察是否打开这两个路径
- 不可行项：`uname -r` 无法改（共享宿主内核）
