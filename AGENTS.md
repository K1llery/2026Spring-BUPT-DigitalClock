# AGENTS Guide for TEC-8 Electronic Clock

本文件用于让 AI 编码代理在本仓库中快速、安全地完成开发与验证。

## 1. Project Scope

- 平台: TEC-8
- 目标器件: EPM7128SLC84-15 (MAX7000S)
- 顶层模块: [clock.v](clock.v)
- Quartus 工程: [clock.qpf](clock.qpf)
- 引脚与工程设置来源: [clock.qsf](clock.qsf)
- 硬件使用说明: [使用教程.md](使用教程.md)

只在明确任务要求下改动 RTL。默认先仿真，再综合。

## 2. Hardware Constraints That Must Be Preserved

- 资源受限: EPM7128 逻辑资源较小，优先面积优化，不引入复杂或宽位计数逻辑。
- 主时钟: `clk` 对应 PIN_55，按 1MHz 使用。
- 复位: `rst_n` 对应 PIN_1，低有效。
- 显示接口为混合模式，不是多位扫描共用段线:
- LG1: 七段译码直出 `lg1_seg[7:0]`。
- LG2~LG6: 每位 4-bit BCD 输入 `lg*_bcd[3:0]`。
- 小数点相关引脚不作为功能需求使用（无需实现独立小数点显示功能）。
- PIN_52 与板上其他功能存在复用关系，当前工程优先用于显示输出。

如与外部 PPT 引脚表冲突，以课程要求为准；修改前先在提交说明中标注差异点。

## 3. Display Rules (Important)

- 最低位数码管(LG1)使用七段译码输出（参考 [seg_decoder.v](seg_decoder.v)）。
- 其余位(LG2~LG6)保持 BCD 输出，不要改成统一七段扫描方案。
- 数码管极性按板卡实物校验，默认遵循当前工程参数；若要改极性，必须同步更新仿真检查点。

## 4. Standard Verification Workflow

### 4.1 Icarus Verilog Simulation (Required)

在仓库根目录执行:

```powershell
iverilog -g2005-sv -o sim_clock.vvp clock.v input_timebase.v clk_div.v set_ctrl.v time_core.v alarm_core.v display_mux.v seg_decoder.v key_filter.v tb_clock.v
vvp sim_clock.vvp
```

要求:

- 修改时序、按键、模式切换、显示路径后，必须重跑仿真。
- 若改动了端口或文件名，更新上述命令与 [tb_clock.v](tb_clock.v)。

### 4.2 Quartus Compile Check (Required)

优先 GUI: 打开 [clock.qpf](clock.qpf) 后执行 `Processing -> Start Compilation`。

如本机已配置命令行工具，可使用:

```powershell
quartus_map clock
quartus_fit clock
quartus_asm clock
quartus_tan clock
```

说明:

- 对 MAX7000S / EPM7128，`quartus_sta`(TimeQuest) 不支持，应使用 `quartus_tan`(Classic Timing Analyzer)。

要求:

- 至少完成一次完整编译检查（Map/Fit/Asm/Sta）。
- 关注资源利用率与未约束/冲突引脚告警。

## 5. Git Workflow (Required)

每次任务最小流程:

```powershell
git status
git add <changed-files>
git commit -m "<type>: <summary>"
```

建议:

- 提交信息示例: `fix: correct lg1 segment polarity` / `test: extend tb for mode switch`。
- 不提交 `db/`、`incremental_db/` 等编译中间产物。

## 6. Change Boundaries

- 优先改已有模块，不随意新增模块层级。
- 不重命名顶层端口，除非任务明确要求并同步修改 [clock.qsf](clock.qsf)。
- 涉及引脚改动时，必须在变更说明中列出 old/new pin 对照。

## 7. Fast File Map for Agents

- 顶层集成: [clock.v](clock.v)
- 时基与按键脉冲: [input_timebase.v](input_timebase.v)
- 时间核心: [time_core.v](time_core.v)
- 模式控制: [set_ctrl.v](set_ctrl.v)
- 闹钟逻辑: [alarm_core.v](alarm_core.v)
- 显示路由: [display_mux.v](display_mux.v)
- 七段译码: [seg_decoder.v](seg_decoder.v)
- 仿真测试: [tb_clock.v](tb_clock.v)
- 工程教程: [使用教程.md](使用教程.md)

## 8. When Unsure

- 先做最小改动并补充可复现实验步骤。
- 优先在仿真中复现问题，再改 RTL。
- 若缺少关键硬件信息（例如 PPT 里的特殊引脚限制），先在说明中列出假设，不要臆测接线。