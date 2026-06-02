# 00 FPGA/SoC Positioning

## 第二创新点定位

本步骤面向论文第二创新点：面向 shared-center 局部增强测角链路的 FPGA/SoC 协同实现框架。它不是提出新的 MUSIC 谱函数，也不是继续扩展算法实验，而是把已经收束的主线从“算法可用”推进到“工程可落地、接口可验证、硬件边界可说明”。

第一创新点聚焦 shared-center 局部增强测角链路本身：前端检测、粗角度、65-column 局部工作子阵、Y_work 构造和 Step8.7 verified lazy cascade backend。第二创新点则聚焦该链路如何在 FPGA/SoC 平台上分层部署：把规则、高吞吐、并行计算放入 FPGA，把数值敏感和分支密集的决策放在 SoC/CPU 或浮点 IP 侧。

## 工程创新属性

本目录的创新属性是工程架构创新：明确 FPGA/SoC 边界、数据流、接口字段、验证方法、固定点风险和资源延迟估算框架。它服务于论文中“可实现性”和“工程价值”的论证。

## 非纯 FPGA 全算法实现

本步骤不声称完成 Step8.7 的纯 FPGA 定点实现。Step8.9 已经表明 fixed-point not closed，steering/template/cache 量化和 route decision 对数值扰动敏感。因此第一版工程路线采用 FPGA/SoC 协同，不把 EVD/SVD、rank1 分支和 confidence/boundary 状态机强行改写为全定点 FPGA。

## 与 Step10 和 Step8.7 的关系

Step10 给出最终论文路线和硬件边界证据，本步骤继承该路线，不改变算法主线。Step8.7 是已验证的 lazy cascade backend，本步骤把它作为 SoC/CPU 侧 route decision 的参考后端，不继续修改其逻辑。
