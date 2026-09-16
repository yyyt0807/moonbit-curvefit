# MoonCurveFit 发布后验收证据

核验日期：2026-09-16；使用 osc2026-guide，并以用户提供九月规则为时间/申报特殊要求来源。属于工程自查，不冒充主办方验收结果。

## 总体判断

公开仓库、实际远端 CI、mooncakes 发布与独立安装三个工程阻塞项已解除。项目为可运行的 MoonBit 库，核心承诺与申报辅助草稿一致。仍须参赛者本人改写正式申报书、确认身份/单人一个项目原则，主办方判断选题重合度及最终验收；不宣称必然通过或获奖。

## GitHub 与远端 CI

- 公开仓库：https://github.com/yyyt0807/moonbit-curvefit；API 验证 visibility=public、default_branch=main，完整历史已推送。
- 首次源码验证提交：818098a9cc6713bfd4d6d2779dee3126120cb60c。
- 实际成功运行：https://github.com/yyyt0807/moonbit-curvefit/actions/runs/35049033454。
- Ubuntu、Windows、macOS job 均 completed/success；不是仅检查 YAML 文件。
- CI 实际执行全 target check/build/test、fmt/info 无差异、三个后端应用示例、Native 准确性工作负载及 CLI；Ubuntu 另执行独立 SciPy 对照。
- 发布记录/申报草稿后的文档提交将继续触发 CI；最终交接前核对最新 main 运行，运行链接可在 Actions 页面检查。

## mooncakes 发布与独立安装

- 模块 yyyt0807/curvefit，版本 0.1.0；`moon publish` 检查原项目和提取后的归档项目通过，服务器返回 200 OK。
- `moon search curvefit --json --limit 10` 实际返回 yyyt0807/curvefit@0.1.0，不仅依赖发布命令退出码。
- 包文档：https://mooncakes.io/docs/yyyt0807/curvefit。
- 在被忽略的独立目录 `_build/registry-smoke` 新建 consumer，声明远端依赖 yyyt0807/curvefit@0.1.0；moon 输出 Downloading，随后 check --deny-warn 与 wasm-gc 最小拟合运行成功，断言斜率接近 2 且确已收敛。
- 发布 ZIP SHA-256：A1B1553AA50EC21284E554FBDA23624EA525694FA12D0160868AADEF2614F0A3。归档未包含 .git、.venv、_build 或凭据。
- 数值实现/manifest 0.1.0 发布后未改动；后续文档状态更新以 GitHub 为准，归档 README 中发布前状态仅为历史文字，不代表发布失败。

## 申报与剩余确认

`MoonCurveFit项目申报书.md` 参考 MoonMIME 的简洁结构，不复制其姓名/联系方式；包含定位、已有生态交集说明、三个可复现完整场景、量化证据、交付与边界。Markdown 23 行，按一页材料编排；实际显示页面长度由提交端渲染决定。

九月规则明确申报书人工撰写，因此文件显式标注辅助草稿，须本人改写确认，不能以 AI 草稿冒充已满足人工要求。主要贡献者/申请人身份需本人核实；Git 作者名与登录账号一致不等于身份认证。源码 4,065 有效 MoonBit 行包含测试/示例（库单独 2,706）；对规模口径/生态差异如有疑问须向主办方确认。
