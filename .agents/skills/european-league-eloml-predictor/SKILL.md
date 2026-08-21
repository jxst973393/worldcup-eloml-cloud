---
name: european-league-eloml-predictor
description: 使用 ModelOriented/EloML 原生强度流程和独立的俱乐部比分层，分析英超、西甲及其他欧洲五大联赛，并在明确切换口径后分析欧冠、欧联、欧协联等欧洲俱乐部杯赛。用于赛前预测、临场复查、走地观察、赛后复盘，或需要综合严格 EloML、90 分钟胜平负、让球、大小球、阵容、赛程密度、欧战阶段和三个比分时。联赛、欧战杯赛和世界杯数据必须彼此独立。
---

# 欧洲俱乐部 EloML 综合预测

按“严格强度、联赛比分、市场校准、比赛信息”四层分析。不要把盘口称为模型结果，也不要把输出写成投注建议。

开始前读取：

- `references/model-and-league-rules.md`：模型边界、联赛差异和修正规则。
- `references/european-cup-mode.md`：仅在分析欧冠、欧联、欧协联等杯赛时读取。
- `references/output-template.md`：固定中文排版和更新格式。

## 适用范围

- 默认重点：英超 `epl`、西甲 `laliga`。
- 同一接口支持：意甲 `seriea`、德甲 `bundesliga`、法甲 `ligue1`。
- 联赛默认只分析 90 分钟结果。
- 欧冠、欧联、欧协联等杯赛必须切换到“欧战杯赛模式”，不得直接套用同一联赛的进球基线或把跨联赛市场概率冒充严格 EloML。
- 国家队和世界杯继续使用 `worldcup-eloml-predictor`；不得混用数据、脚本或模板。

## 工作流

1. 确认联赛、主客队、开球时间和用户时区。“今天、现在、最新、临场、走地”必须联网核实。
2. 判断是联赛还是欧战杯赛：
   - 联赛：继续执行本节第 3 步；
   - 欧战杯赛：读取 `references/european-cup-mode.md`，确认首回合、次回合或单场制，并使用杯赛隔离流程。
3. 联赛模式获取最新完赛赛果，并排除目标比赛日期当天及之后的数据。优先使用最近三个完整/进行中赛季，同一联赛单独建模，然后运行俱乐部模型。例如：

   ```bash
   bash scripts/predict-league-match.sh --league epl --home-team Arsenal --away-team Liverpool --match-date 2026-08-15 --seasons 2324,2425,2526 --refresh true
   ```

   若目标队是升班马、重返顶级联赛球队或样本不足，导致脚本无法解析球队：

   - 严格 EloML 与同联赛俱乐部比分层均标记为“不可用”，不得用名气、旧赛季或低级别原始数据补造；
   - 不把脚本失败扩展为“所有市场分析都必须停止”；
   - 先用赛事官网和俱乐部官网等两个来源确认赛程，再核实至少两个当前公开市场来源；
   - 只有取得同一家来源完整的 1X2 与 2.5 大小球快照，并用第二来源交叉确认方向后，运行市场回退脚本：

     ```bash
     bash scripts/predict-market-score.sh \
       --home-team Arsenal --away-team Coventry \
       --home-odds 1.20 --draw-odds 7.50 --away-odds 16.00 \
       --over-2.5-odds 1.60 --under-2.5-odds 2.42 \
       --asian-line=-1.75 \
       --snapshot-time "2026-08-21 17:43 Asia/Shanghai"
     ```

   该结果只能称为“市场校准比分层”或“市场独立 Poisson 回退”，不能称为严格 EloML、俱乐部历史比分层或综合模型。若缺少完整市场快照，继续停止，不生成比分。

4. 记录四组结果，不得混称：
   - 严格 EloML 二元强弱概率；
   - 主客场攻防比分层的 90 分钟胜平负、预期进球和 Top 比分；
   - 公开赔率去水后的市场概率；
   - 设定权重后的综合校准概率。

   升班马回退没有前两组原生结果，也没有可与市场加权的历史基线；只展示“不可用”的原生层和独立的市场回退层，不虚构综合权重。
5. 联网核实至少两个公开来源的当前 1X2、亚洲让球、大小球和时间戳。赔率可用参数传入脚本进行去水校准；没有可靠数值时不要编造。
   - 浏览或搜索接口返回 `401/403` 时，不等于公开数据不存在。若 Agent internet access 已开启，改用普通 HTTPS 命令行抓取。
   - 英超可先运行以下两个独立来源助手，再把同一家机构的完整快照传给比分脚本：

     ```bash
     python3 scripts/fetch-oddstorm-market.py \
       --league-id 325 --league-slug england-premier-league \
       --home Arsenal --away "Coventry City" --bookmaker Pinnacle

     python3 scripts/fetch-betexplorer-market.py \
       --league-path football/england/premier-league \
       --home Arsenal --away Coventry --bookmaker bet365
     ```

   - 两个助手都成功且方向一致时，满足市场双源核验；记录输出中的 URL、机构名与抓取时间。任一助手失败时继续寻找可靠来源，不得使用文档示范赔率替代当前快照。
   - 2026/27 英超官方完整赛程可从 `https://www.premierleague.com/en/news/4675097/all-380-fixtures-for-202627-premier-league-season` 读取；再用对应俱乐部官方赛程新闻交叉确认。动态赛程页解析失败时，不要忽略已经成功读取的官方静态赛程。
6. 核实伤停、停赛、预计首发、休息天数、连续客场、欧战和换帅信息。开赛前约一小时再检查官方首发。
7. 按参考模板输出三个核心比分和可能意外路径。普通 Markdown 排版，不使用 writing block、HTML 卡片或外框。

欧战杯赛模式不得为了填表而运行不适用的联赛脚本。严格 EloML 样本不足或跨联赛不可比时，明确写“严格层不输出伪精确概率”，再分别展示可核实的俱乐部强度参考、杯赛比分层和市场去水概率。

## 参数示例

有可靠市场快照时传入十进制赔率：

```bash
bash scripts/predict-league-match.sh \
  --league laliga \
  --home-team Barcelona \
  --away-team "Real Madrid" \
  --match-date 2026-08-23 \
  --seasons 2324,2425,2526 \
  --home-odds 2.10 --draw-odds 3.70 --away-odds 3.20 \
  --over-2.5-odds 1.78 --under-2.5-odds 2.08 \
  --market-weight 0.25 --refresh true
```

- `--market-weight` 只允许 `0` 到 `0.5`，默认 `0.25`。阵容未确认或盘口来源分歧时降低到 `0.10-0.20`。
- `--half-life-days` 默认 `240`，让较新的俱乐部比赛权重更高；不要改变严格 EloML 原生结果的名称。
- `--refresh true` 下载并缓存指定赛季；失败时可以回退 `data/leagues/` 中的独立缓存。
- `--asian-line` 仅记录当前让球档位，不会伪装成 EloML 输入。

## 当前与走地更新

- 赛前复查逐项写“旧值 -> 新值 -> 含义”，区分真实升降盘和同盘水位微调。
- 已开赛时先报告比分、分钟、红牌、射门和高质量机会；赛前概率仅作为先验。
- 红牌、点球、门将或中卫伤退会显著破坏赛前结构，应降低模型权重。
- 谁先进球通常赢面上升，但必须结合剩余时间、领先方风格和实时场面，不能写成必然。
- 不提供金额、串关、回报、下注或操作指令。

## 固定声明

每次输出结尾加入：

> 本内容仅用于模型学习与足球比赛分析，不涉及、不建议、也不参与任何体彩、竞猜、博彩或相关行为。
