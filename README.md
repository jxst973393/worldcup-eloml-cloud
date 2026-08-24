# 世界杯 EloML 云端预测

这是为 Codex Cloud 整理的独立版本。它包含：

- GitHub 项目 `ModelOriented/EloML` 的原生 `calculate_epp()` 与
  `calculate_probability()` 流程；
- 明确独立标注的 Poisson 比分扩展；
- 最新国际比赛结果缓存；
- 盘口、让球、大小球、阵容和走地数据的综合修正规则；
- 固定中文普通 Markdown 排版。

## Codex Cloud 设置

本仓库的两个 Skill 位于 Codex 可自动发现的 `.agents/skills/`：

- `$worldcup-eloml-predictor`
- `$european-league-eloml-predictor`

其中 `$european-league-eloml-predictor` 同时包含隔离的欧战杯赛模式，支持
欧冠、欧联和欧协联，但不会把杯赛结果混入五大联赛训练集。

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

## Windows 本地运行（不使用云端）

在Windows安装Git、R和Python 3，将完整仓库克隆或复制到本机。推荐使用Git：

```powershell
winget install --id Git.Git -e
winget install --id RProject.R -e
winget install --id Python.Python.3.12 -e

git clone https://github.com/jxst973393/worldcup-eloml-cloud.git
cd worldcup-eloml-cloud
powershell -ExecutionPolicy Bypass -File scripts/setup-windows.ps1
```

随后在Codex PC客户端中打开`worldcup-eloml-cloud`根目录。仓库内的
`AGENTS.md`和`.agents/skills/`会提供完整工作流；模型与联网助手均在本机
运行，不需要Cloud Environment。

Windows直接运行联赛模型的入口为：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/predict-league-match.ps1 `
  --league epl --home-team Arsenal --away-team Liverpool `
  --match-date 2026-08-15 --seasons 2324,2425,2526 --refresh true
```

更新项目只需在仓库目录运行`git pull origin main`。

## 在手机上提问

选择本仓库的 Cloud Environment 后，可以直接发送：

> 使用 `$worldcup-eloml-predictor`，读取仓库中的 AGENTS.md，使用最新公开
> 赛程和盘口数据，按照固定排版分析下一场世界杯比赛。必须运行严格 EloML
> 脚本，并把 Poisson 比分层、盘口、让球、大小球、阵容和可能意外分开说明。

五大联赛可以直接发送：

> 使用 `$european-league-eloml-predictor`，联网确认比赛时间、最新赛果、
> 伤停、首发和公开市场变化，运行联赛模型并分析指定比赛。严格 EloML、
> 俱乐部比分层和市场校准必须分别展示。

欧战杯赛可以继续使用同一个 Skill：

> 使用 `$european-league-eloml-predictor` 的欧战杯赛模式，联网确认赛事轮次、
> 首回合或次回合、总比分、最新正式赛、阵容、1X2、亚洲让球和大小球。
> 不要直接套用五大联赛进球基线；严格层样本不可比时不要输出伪精确概率。
> 分别展示强度参考、杯赛比分层、市场去水、三个核心比分和可能意外。

完整的云端、手机和本机用法见 [`docs/CLOUD-USAGE.md`](docs/CLOUD-USAGE.md)。

## 模型边界

严格 EloML 是不含平局的两队相对强度概率，也不直接预测比分。比分来自
单独的 Poisson 扩展。盘口和赔率只用于校准，不得反过来冒充模型结果。

本项目仅用于模型学习与足球比赛理解，不涉及、不建议、也不参与任何体彩、
竞猜、博彩或相关行为。

## 独立的五大联赛版本

世界杯版本完整保留在 `.agents/skills/worldcup-eloml-predictor/`，国际比赛数据仍在
`data/international_results_latest.csv`。五大联赛使用另一套目录和数据，
两者不会互相覆盖：

- 联赛技能：`.agents/skills/european-league-eloml-predictor/`
- 联赛入口：`scripts/predict-league-match.sh`
- 联赛缓存：`data/leagues/`
- 默认重点：英超和西甲；同时支持意甲、德甲、法甲

联赛版保留 GitHub EloML 原生二元强弱概率，并增加独立的俱乐部主客场攻防、
时间衰减、Dixon-Coles 低比分修正和赔率去水校准。示例：

```bash
bash scripts/predict-league-match.sh \
  --league epl \
  --home-team Arsenal \
  --away-team Liverpool \
  --match-date 2026-08-15 \
  --seasons 2324,2425,2526 \
  --refresh true
```

有当前赔率时还可以传入 `--home-odds`、`--draw-odds`、`--away-odds`、
`--over-2.5-odds`、`--under-2.5-odds` 和 `--market-weight`。严格 EloML、
比分层和市场校准始终分别展示。

升班马不在近三季顶级联赛样本、联赛脚本无法解析时，不补造严格结果。
在官方赛程和两个当前公开市场来源均已核验，且取得同一家机构完整的 1X2
与 2.5 大小球快照后，可运行独立市场回退：

```bash
bash scripts/predict-market-score.sh \
  --home-team Arsenal --away-team Coventry \
  --home-odds 1.20 --draw-odds 7.50 --away-odds 16.00 \
  --over-2.5-odds 1.60 --under-2.5-odds 2.42 \
  --asian-line=-1.75 \
  --snapshot-time "2026-08-21 17:43 Asia/Shanghai"
```

该脚本只输出市场独立 Poisson 概率、预期进球和比分矩阵，不能称为
严格 EloML 或俱乐部历史比分层。

云端浏览接口若返回401，可从命令行运行双源市场助手：

```bash
python3 scripts/fetch-oddstorm-market.py \
  --league-id 325 --league-slug england-premier-league \
  --home Arsenal --away "Coventry City" --bookmaker Pinnacle

python3 scripts/fetch-betexplorer-market.py \
  --league-path football/england/premier-league \
  --home Arsenal --away Coventry --bookmaker bet365
```

助手只读取公开页面，不需要账号、Cookie或API key。

欧战杯赛规则位于
`.agents/skills/european-league-eloml-predictor/references/european-cup-mode.md`，
已复盘的杯赛预测保存在 `data/evaluations/european-cup-predictions.csv`。
