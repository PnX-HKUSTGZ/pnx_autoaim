#!/usr/bin/env bash
set -euo pipefail

# 简介：
# 将本仓库中所有子模块更新到 .gitmodules 配置的分支最新提交。
# - 默认并发 4 个任务；可通过环境变量 JOBS 覆盖（例如 JOBS=8）。
# - 不使用浅克隆；如果子模块之前是浅的，Git 会自动补齐该分支需要的历史。
# - 可选：设置 COMMIT=1 自动提交子模块指针更新。
#
# 用法：
#   chmod +x ./update_submodules.sh
#   ./update_submodules.sh                # 仅更新
#   JOBS=8 ./update_submodules.sh         # 指定并发
#   COMMIT=1 ./update_submodules.sh       # 更新后自动提交指针

JOBS="${JOBS:-4}"
COMMIT="${COMMIT:-0}"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "错误：当前目录不是 Git 仓库" >&2
  exit 1
fi

echo "[1/3] 同步子模块配置 (.gitmodules -> .git/config) ..."
git submodule sync --recursive

echo "[2/3] 更新到配置分支的最新提交（递归） ..."
# 关键：--remote 会按 .gitmodules 的 branch= 拉取对应远端分支的最新提交
# 不加 --depth，避免浅克隆；如需浅克隆可自行加 --depth=1
git submodule update --init --remote --recursive --jobs="${JOBS}"

echo "[3/3] 当前子模块指针："
git submodule status || true

echo "完成：子模块已更新到配置分支的最新提交。"

if [[ "${COMMIT}" == "1" ]]; then
  echo "[commit] 提交父仓库中的子模块指针 ..."
  # 列出所有子模块路径，添加到提交
  if paths=$(git submodule--helper list 2>/dev/null | awk '{print $4}'); then
    if [[ -n "${paths}" ]]; then
      git add ${paths}
      git commit -m "chore: bump submodules to configured branches"
      echo "已提交子模块指针更新。"
    else
      echo "没有检测到子模块路径，跳过提交。"
    fi
  else
    echo "警告：git submodule--helper 不可用，跳过自动提交。"
  fi
fi
