# 云端、手机与本机使用指南

本仓库已经按 Codex 的仓库级 Skill 规范配置。云端克隆仓库后会自动发现：

- `$worldcup-eloml-predictor`：世界杯和国家队比赛。
- `$european-league-eloml-predictor`：英超、西甲、意甲、德甲和法甲。

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
```

联赛参数对应关系：

| 联赛 | 参数 |
| --- | --- |
| 英超 | `epl` |
| 西甲 | `laliga` |
| 意甲 | `seriea` |
| 德甲 | `bundesliga` |
| 法甲 | `ligue1` |

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
| `jxst973393/worldcup-eloml-cloud` | 世界杯和五大联赛两个 EloML Skill | `$worldcup-eloml-predictor`、`$european-league-eloml-predictor` |
| `jxst973393/seallon-workspace` | Seallon SEO、询盘、周报、搜索词聚类等 | 选择该仓库后用 `$seallon-yandex-seo-richtext` 等 |
| `jxst973393/codex-global-skills` | 设计、SEO、文档、图表、发布和安全分析等通用 Skills | 选择该仓库后用 `$seo`、`$baoyu-design`、`$docs-generator` 等 |

本机或家里 PC 可以克隆后运行各仓库的安装脚本，把 Skills 安装到 `~/.agents/skills`。云端不读取家里电脑的 `~/.agents/skills`；它只读取云端容器中的用户 Skill 和所选仓库的 `.agents/skills`。

## 常见问题

- 看不到 `$skill`：确认使用最新 `main` 分支并新建云端任务；必要时重置 Environment cache。
- 模型脚本找不到 R：重新运行 Environment setup，确认 `bash scripts/setup-cloud.sh` 成功。
- 无法获得最新伤停或赛程：检查 Agent internet access；没有可靠来源时不要把结果写成已确认预测。
- 想分析另一联赛：新建一条提示词，明确联赛、主客队、日期和时区。
- Skill 选择错误：第一句明确写 `$european-league-eloml-predictor` 或 `$worldcup-eloml-predictor`。
