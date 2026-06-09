# Step11.5 Stage3 Supplementary Thesis Writing Text

## Case 1: Metkl30 passed and ill-conditioned real stress naturally triggered

本文进一步对 Step11.5 Stage2 推荐的 C05 自适应搜索策略进行了 Metkl=30 多 seed 复验和更强 ill-conditioned real-search stress。结果表明，C05 不仅在代表性场景下稳定保持候选数优势与安全性，而且病态分支可在真实搜索压力样本中自然触发，并输出低置信安全状态。因此，Step11.5 C05 可作为 controlled pair2d beamspace ML 的最终自适应搜索增强策略。

## Case 2: Metkl30 passed, ill-conditioned real stress did not naturally trigger, guard probe passed

本文进一步对 Step11.5 Stage2 推荐的 C05 自适应搜索策略进行了 Metkl=30 多 seed 复验，结果表明该策略在更大样本和多个 seed group 下仍保持 fixed topK3 的安全性与候选数优势。针对 ill-conditioned 分支，真实搜索压力样本在当前固定 W、网格和阈值条件下未自然触发该分支，但 deterministic guard probe 验证了病态保护逻辑会输出低置信状态且不会造成高置信误用。因此，本文将 C05 作为代表性场景下的最终正向增强结果，同时将 ill-conditioned 真实触发作为边界分析和未来工作保留。

## Case 3: Metkl30 did not pass

本文进一步对 Step11.5 Stage2 推荐的 C05 自适应搜索策略进行了 Metkl=30 多 seed 复验，但结果未能稳定保持 fixed topK3 的安全性或候选数优势。因此，本文不进一步强化 Step11.5 C05 的最终主张，而保留已有 Stage3 required validation 结论，并将更大样本稳定性作为后续工作。
