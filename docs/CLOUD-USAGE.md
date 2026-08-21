# 云端、手机与本机使用指南

本仓库已经按 Codex 的仓库级 Skill 规范配置。云端克隆仓库后会自动发现：

- `$worldcup-eloml-predictor`：世界杯和国家队比赛。
- `$european-league-eloml-predictor`：英超、西甲、意甲、德甲、法甲，以及隔离口径的欧冠、欧联和欧协联。

## 第一次配置 Codex Cloud

1. 在 Codex Cloud 连接 GitHub 仓库 `jxst973393/worldcup-eloml-cloud`。
2. 选择 `main` 分支。
3. 为这个仓库创建 Cloud Environment。
4. Setup script 填写：

   ```bash
   bash scripts/setup-cloud.sh
   ```

5. 开启 Agent internet access。当前赛程、完赛结果、伤停、首发和公开市场信息都必须联网核实。
6. 第一次运行等待 R 和固定版本 EloML 安装完成；后续环境可使用缓存。

不需要填写 OpenAI API key。不要把任何体育网站账号、Cookie 或 token 提交到仓库。

## 在云端分析五大联赛

直接复制下面的提示词，替换联赛、球队和日期：

```text
使用 $european-league-eloml-predictor。

分析联赛：英超
主队：阿森纳
客队：利物浦
比赛日期：2026-08-15
我的时区：Asia/Shanghai

先联网确认准确开球时间、最新完赛结果、伤停、预计首发、休息天数、
连续主客场和欧战影响，再运行 scripts/predict-league-match.sh。

分别输出严格 EloML、主客场攻防比分层、市场去水概率、综合校准概率、
预期进球、三个核心比分和可能意外路径。不要编造缺失数据，不提供下注建议。

如果目标队是升班马且联赛脚本提示找不到球队，不要把低级别数据直接混入
顶级联赛，也不要在已取得可靠市场快照时把所有分析一并停止。明确标记严格
EloML和同联赛比分层不可用；在官方赛程双源确认、同一家机构完整1X2与
2.5大小球、第二市场来源交叉确认均满足后，运行
scripts/predict-market-score.sh，并把结果标注为“市场独立Poisson回退”。
缺少任一条件时停止，不生成比分。

如果云端浏览接口返回 `401 Unauthorized`，不要立即写“当前数据不存在”。先在
仓库根目录运行 `scripts/fetch-oddstorm-market.py` 和
`scripts/fetch-betexplorer-market.py`。这两个脚本通过普通 HTTPS 读取两个独立
公开来源，并输出机构、赔率、URL和UTC抓取时间。只有两个脚本也无法取得完整
快照时，才按数据不足停止。
```

联赛参数对应关系：

| 联赛 | 参数 |
| --- | --- |
| 英超 | `epl` |
| 西甲 | `laliga` |
| 意甲 | `seriea` |
| 德甲 | `bundesliga` |
| 法甲 | `ligue1` |

## 在云端分析欧战杯赛

欧冠、欧联和欧协联继续调用同一个俱乐部 Skill，但要明确要求杯赛模式：

```text
使用 $european-league-eloml-predictor 的欧战杯赛模式。

分析比赛：奥胡斯 vs 萨巴赫
赛事：欧冠资格赛
比赛日期：2026-08-11
我的时区：Asia/Shanghai

读取 references/european-cup-mode.md。联网确认轮次、首回合比分、总比分、
开球时间、场地、最近正式赛、伤停、停赛、预计首发、1X2、亚洲让球和大小球。
不要直接套用五大联赛进球基线；严格 EloML 样本不可比时明确写不输出
伪精确概率。分别展示强度参考、杯赛比分层、市场去水、三个核心比分、
可能意外、90 分钟方向和晋级方向。不提供下注建议。
```

已经完成的预测会追加到 `data/evaluations/european-cup-predictions.csv`。
单场赛果只用于复盘；累计至少 50 场后才评估是否调整参数。

## 在云端分析世界杯或国家队

```text
使用 $worldcup-eloml-predictor。

分析法国对英格兰，比赛日期 2026-07-18，中立场，时区 Asia/Shanghai。
联网确认最新赛果、伤停、首发、胜平负、让球和大小球时间戳，
运行 scripts/predict-match.sh。

分别展示严格 EloML、Poisson 比分层和市场校准，给出三个核心比分和意外路径。
不要把盘口称为模型结果，不提供下注建议。
```

## 手机使用

手机不运行 R 模型。手机只负责向 Codex Cloud 提交任务；模型在云端容器运行。

1. 用同一个 ChatGPT 账号打开 Codex。
2. 选择 `worldcup-eloml-cloud` 仓库和已配置的 Cloud Environment。
3. 发送上面的提示词。
4. 对同一场比赛临场复查时，继续在原任务中说：

   ```text
   使用同一个 Skill 复查这场比赛。列出上次数据到当前数据的变化，
   重新确认官方首发和重大伤停；没有变化的模型部分不要夸大解释。
   ```

## 本机使用

在仓库根目录启动 Codex，两个 Skill 会从 `.agents/skills/` 自动发现：

```bash
codex
```

也可以绕过对话直接运行模型：

```bash
bash scripts/predict-league-match.sh \
  --league epl \
  --home-team Arsenal \
  --away-team Liverpool \
  --match-date 2026-08-15 \
  --seasons 2324,2425,2526 \
  --refresh true
```

## 刚上传的其他 Skills 怎么用

Codex 云端的仓库级 Skills 只在选择对应仓库时自动加载：

| GitHub 仓库 | 自动可用内容 | 调用方式 |
| --- | --- | --- |
| `jxst973393/worldcup-eloml-cloud` | 世界杯、五大联赛及隔离欧战杯赛模式 | `$worldcup-eloml-predictor`、`$european-league-eloml-predictor` |
| `jxst973393/seallon-workspace` | Seallon SEO、询盘、周报、搜索词聚类等 | 选择该仓库后用 `$seallon-yandex-seo-richtext` 等 |
| `jxst973393/codex-global-skills` | 设计、SEO、文档、图表、发布和安全分析等通用 Skills | 选择该仓库后用 `$seo`、`$baoyu-design`、`$docs-generator` 等 |

本机或家里 PC 可以克隆后运行各仓库的安装脚本，把 Skills 安装到 `~/.agents/skills`。云端不读取家里电脑的 `~/.agents/skills`；它只读取云端容器中的用户 Skill 和所选仓库的 `.agents/skills`。

## 常见问题

- 看不到 `$skill`：确认使用最新 `main` 分支并新建云端任务；必要时重置 Environment cache。
- 模型脚本找不到 R：重新运行 Environment setup，确认 `bash scripts/setup-cloud.sh` 成功。
- 无法获得最新伤停或赛程：检查 Agent internet access；没有可靠来源时不要把结果写成已确认预测。
- 想分析另一联赛：新建一条提示词，明确联赛、主客队、日期和时区。
- Skill 选择错误：第一句明确写 `$european-league-eloml-predictor` 或 `$worldcup-eloml-predictor`。
