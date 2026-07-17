# 世界杯 EloML 云端预测

这是为 Codex Cloud 整理的独立版本。它包含：

- GitHub 项目 `ModelOriented/EloML` 的原生 `calculate_epp()` 与
  `calculate_probability()` 流程；
- 明确独立标注的 Poisson 比分扩展；
- 最新国际比赛结果缓存；
- 盘口、让球、大小球、阵容和走地数据的综合修正规则；
- 固定中文普通 Markdown 排版。

## Codex Cloud 设置

在 Codex Cloud 为本仓库创建 Environment，并把 Setup script 设置为：

```bash
bash scripts/setup-cloud.sh
```

为了核实当天赛程、赔率、让球、大小球和阵容，需要在环境设置中开启
Agent internet access。建议至少允许：

- `github.com`
- `raw.githubusercontent.com`
- 实际采用的赛事官方、体育媒体和公开赔率页面域名

如果需要临时核实多个公开来源，可以开启 unrestricted internet access，
完成后再收紧。

## 直接运行模型

在仓库根目录执行：

```bash
bash scripts/predict-match.sh \
  --team-a France \
  --team-b England \
  --match-date 2026-07-18 \
  --neutral true \
  --refresh true \
  --top 10
```

模型会输出训练窗口、样本数、严格 EloML 二元概率、Poisson 90 分钟
胜平负、预期进球、大小球概率、双方进球概率和比分排名。

## 在手机上提问

选择本仓库的 Cloud Environment 后，可以直接发送：

> 读取仓库中的 AGENTS.md 和 worldcup-eloml-predictor 技能，使用最新公开
> 赛程和盘口数据，按照固定排版分析下一场世界杯比赛。必须运行严格 EloML
> 脚本，并把 Poisson 比分层、盘口、让球、大小球、阵容和可能意外分开说明。

## 模型边界

严格 EloML 是不含平局的两队相对强度概率，也不直接预测比分。比分来自
单独的 Poisson 扩展。盘口和赔率只用于校准，不得反过来冒充模型结果。

本项目仅用于模型学习与足球比赛理解，不涉及、不建议、也不参与任何体彩、
竞猜、博彩或相关行为。

