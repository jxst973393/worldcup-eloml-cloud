---
name: worldcup-eloml-predictor
description: 使用 ModelOriented/EloML 原生流程、Poisson 比分扩展和最新公开市场数据分析世界杯或国家队比赛。用于用户要求赛前预测、当日更新、临场复查、赛中走地观察、赛后复盘，或要求同时解释严格 EloML、胜平负、让球/受让、赔率水位、大小球、阵容和三个比分时。输出固定采用普通 Markdown 无外框排版，并包含模型学习声明。
---

# 世界杯 EloML 综合预测

按“严格模型为底座，比分层独立扩展，市场只作校准”的顺序分析。不要把盘口当成比赛真相，也不要把内容写成投注建议。

开始前必须读取：

- `references/method-and-corrections.md`：模型边界、市场修正规则和已验证教训。
- `references/output-template.md`：用户固定排版和字段。

## 工作流

1. 确认比赛、开球时间和用户时区。对“今天、现在、最新、临场、走地”等请求必须联网核实。
2. 核实最新完赛结果。训练数据只纳入开球日期之前、已有正式比分的比赛；不得将未完赛或空比分行计入。
3. 获取至少两个公开来源的最新信息：
   - 90 分钟胜平负及时间戳；
   - 亚洲让球的初盘、当前盘和双方水位；
   - 大小球的初盘、当前盘和双方水位；
   - 伤停和预计阵容；开赛前约一小时再确认官方首发；
   - 已开赛时核实比分、分钟、红牌、射门和高质量机会，再讨论走地。
4. 运行严格模型脚本。Codex Cloud 或 macOS/Linux 在项目根目录执行：

   ```bash
   bash scripts/predict-match.sh --team-a England --team-b Argentina --match-date 2026-07-15 --neutral true --refresh true
   ```

   Windows 技能随项目复制时执行：

   ```powershell
   Rscript .\skills\worldcup-eloml-predictor\scripts\predict_match.R --team-a England --team-b Argentina --match-date 2026-07-15 --neutral true --refresh true
   ```

   技能安装到 Windows Codex 全局目录时执行：

   ```powershell
   Rscript "$env:USERPROFILE\.codex\skills\worldcup-eloml-predictor\scripts\predict_match.R" --team-a England --team-b Argentina --match-date 2026-07-15 --neutral true --refresh true
   ```

   macOS 若 `Rscript` 不在 PATH，可使用 `/opt/homebrew/bin/Rscript`。Windows 首次运行前安装 R、Rtools，并在 R 中执行：

   ```r
   install.packages("remotes", repos = "https://cloud.r-project.org")
   remotes::install_github("ModelOriented/EloML")
   ```

5. 记录脚本输出中的训练窗口、样本数、最新比分日期、严格二元概率、Poisson 胜平负、大小球概率和 Top 比分。
6. 按参考规则综合模型、盘口、大小球和阵容，不凭单一数据翻转结论。
7. 按 `references/output-template.md` 输出。必须使用普通 Markdown；不要使用 writing block、HTML 卡片或带外框内容块。

## 数据处理

默认优先读取项目中的：

1. `data/international_results_latest.csv`
2. `data/international_results.csv`
3. `martj42/international_results` 在线 CSV

当前比赛分析使用 `--refresh true` 尝试在线更新；若在线失败则回退本地缓存，并在答案中明确本地数据的最新日期。

如果公开赛果已经确认但 CSV 尚未更新，可以在数据副本中补入该比分。必须说明补入的比赛和来源，不得猜测比分。

## 模型口径

- “严格 EloML”只指 GitHub 项目的 `calculate_epp()` 与 `calculate_probability()` 原生流程。
- 严格概率是二元相对强度，不含平局，不预测比分。
- Poisson 层使用 EloML EPP 差值与中立场变量估计双方进球，是明确标注的扩展，不得称为 EloML 原生比分功能。
- 结果概率与单个比分不矛盾：某队总胜率可能最高，但胜率会分散到多个比分，单一最高比分仍可能是平局。
- 晋级概率若用“平局后双方各 50%”近似，必须标为粗略估计；有加时或点球信息时再调整。

## 当前更新

同一比赛多次复查时：

1. 保留上一版的赔率、让球、大小球和时间戳作为基准。
2. 若没有新增完赛数据，不必重新解释 EloML 变化；模型数值通常不变。
3. 逐项写出“旧值 -> 新值 -> 含义”。
4. 只有让球档位、双方水位和 1X2 同步变化，才称为真实增强或减弱。
5. 仅赔率微调而盘口不升，不得夸大为方向翻转。

## 赛中更新

- 先报告当前比分、分钟和重大事件，再分析。
- 红牌、点球、主力伤退会显著破坏赛前模型结构，应降低赛前概率权重。
- 谁先进球通常赢面上升，但不是必然；结合剩余时间、场面质量和实时盘口判断。
- 区分“控球多”与“高质量机会多”。只有后者才应明显调整比分分布。
- 不提供下注金额、串关、回报或操作指令。
