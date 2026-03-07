---
name: social-push
description: 使用 agent-browser 帮用户将内容发到社交媒体上。当用户需要发布内容、推送文章、上传文章、发帖到社交平台时使用此 skill。
disable-model-invocation: false
---

用户输入 $ARGUMENTS

# Social-push Skill
你需要使用 bash 运行自动化脚本，帮助用户将文章、图片上传到对应的社交平台上

# Rules
1. 优先使用 scripts 目录下的自动化脚本（如果存在）
2. 如果没有对应的脚本，则参考 references 中对应平台的 workflow，使用 agent-browser 逐步执行
3. 脚本会自动处理浏览器打开、登录检查、内容填充等步骤
4. 脚本执行失败时，查看错误信息并根据 references 中的 workflow 进行调试

# Core Workflow
1. 确认发布信息 调用 AskUserQuestion tool：目标平台（还是**添加新平台**）、内容类型、内容来源（文件路径/直接输入/ai 创作）、标题、话题标签
2. 检查 scripts 目录是否有对应平台的自动化脚本
3. 如果有脚本，直接调用脚本并传入参数
4. 如果没有脚本，读取 references 中对应平台的 workflow，使用 agent-browser 逐步执行


# Self-evolution

## fix and verify Workflow
网页交互可能发生变化，脚本或 workflow 可能失效，按以下步骤修复：
1. 运行 `agent-browser snapshot` 查看当前页面的详细元素
2. 对比 workflow 中的元素 ref 和当前页面的元素 ref，找到失效的步骤
3. 当查找失败，运行 `agent-browser eval "js"` 查看具体 html 元素
4. 验证正确的交互路径后：
   - 如果有对应的脚本，编辑 scripts 目录下的脚本文件
   - 如果没有脚本，编辑 references 目录下的 workflow 文件

## 添加新的社交平台
当用户询问需要新添加一个平台时候，按以下步骤添加：
1. 参考 references 下已有的 workflow 作为模板
2. 用 `agent-browser --help` 查看可用命令 和 agent-browser 的 skill
3. 启动浏览器，完整一步一步测试新的平台交互路径，确保每步操作正确
4. 在 references 目录下创建新平台的 workflow 文件
5. （可选）基于 workflow 创建自动化脚本，放在 scripts 目录下
6. 在下方 References 中添加链接



# References

## 小红书
- **脚本**: [xiaohongshu-image.sh](./scripts/xiaohongshu-image.sh) - 图文发布自动化脚本
  - 用法: `./scripts/xiaohongshu-image.sh <图片路径> <标题> <正文内容> [话题]`
- **脚本**: [xiaohongshu-article.sh](./scripts/xiaohongshu-article.sh) - 长文发布自动化脚本
  - 用法: `./scripts/xiaohongshu-article.sh <文件路径> <标题> <简介> [话题] [模版风格]`
- **参考**: [小红书图文](./references/小红书图文.md) - 图文发布 workflow（用于调试）
- **参考**: [小红书长文](./references/小红书长文.md) - 长文发布 workflow（用于调试）

## X (Twitter)
- `X推文` ：查看[X推文](./references/X推文.md)发布推文时候需要的 workflow

## 微博 (Weibo)
- `微博` ：查看[微博](./references/微博.md)发布微博时候需要的 workflow

## 微信公众号
- `微信公众号文章` ：查看[微信公众号文章](./references/微信公众号文章.md)发布公众号文章时候需要的 workflow

## 掘金
- `掘金文章` ：查看[掘金文章](./references/掘金文章.md)发布掘金文章并自动保存草稿的 workflow

## Linux.do
- `LinuxDo发帖` ：查看[LinuxDo发帖](./references/LinuxDo发帖.md)发布帖子（含类别与标签选择）的 workflow
