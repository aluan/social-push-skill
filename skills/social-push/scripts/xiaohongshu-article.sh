#!/bin/bash
# 小红书长文发布脚本
# Usage: ./xiaohongshu-article.sh <文件路径> <标题> <简介> [话题] [模版风格] [发布动作]

set -e

# 参数检查
if [ $# -lt 3 ]; then
    echo "Usage: $0 <文件路径> <标题> <简介> [话题] [模版风格] [发布动作]"
    echo "Example: $0 /path/to/article.md '我的标题' '这是简介' '技术分享' '清晰明朗' 'publish'"
    echo ""
    echo "可选模版风格："
    echo "  简约基础、清晰明朗、黑白极简、轻感明快、黄昏手稿、手帐书写、灵感备忘、文艺清新、"
    echo "  札记集尘、涂鸦马克、素雅底纹、理性现代、优雅几何、逻辑结构、大图纯享、杂志先锋、"
    echo "  平实叙事、交叉拓扑、拼接色块、线条复古"
    echo ""
    echo "发布动作："
    echo "  draft   - 保存草稿（默认）"
    echo "  publish - 立即发布"
    exit 1
fi

FILE_PATH="$1"
TITLE="$2"
DESCRIPTION="$3"
TOPIC="${4:-}"
TEMPLATE="${5:-}"
ACTION="${6:-draft}"

# 检查文件是否存在
if [ ! -f "$FILE_PATH" ]; then
    echo "错误：文件不存在: $FILE_PATH"
    exit 1
fi

echo "=== 小红书长文发布流程 ==="
echo "文件: $FILE_PATH"
echo "标题: $TITLE"
echo "简介: $DESCRIPTION"
[ -n "$TOPIC" ] && echo "话题: $TOPIC"
[ -n "$TEMPLATE" ] && echo "模版: $TEMPLATE"
echo ""

# 1. 打开发布长文的网站
echo "步骤 1: 打开小红书创作者平台..."
agent-browser --headed --profile /tmp/agent-profile open "https://creator.xiaohongshu.com/publish/publish?source=official&from=tab_switch&target=article"

# 等待页面加载
sleep 2

# 2. 查看交互并提取"新的创作"按钮
echo "步骤 2: 查看页面交互元素..."
agent-browser snapshot -i > /tmp/xhs_snapshot.txt 2>&1
cat /tmp/xhs_snapshot.txt
NEW_BUTTON_REF=$(grep "button \"新的创作\"" /tmp/xhs_snapshot.txt | head -1 | sed -n 's/.*\[ref=\(e[0-9]*\)\].*/\1/p')
if [ -z "$NEW_BUTTON_REF" ]; then
    echo "错误：无法找到'新的创作'按钮"
    exit 1
fi

# 3. 进入长文
echo "步骤 3: 点击进入长文编辑..."
agent-browser click "@$NEW_BUTTON_REF"

# 4. 查看交互并提取标题输入框
echo "步骤 4: 查看编辑页面..."
agent-browser snapshot -i > /tmp/xhs_snapshot.txt 2>&1
TITLE_REF=$(grep "textbox \"输入标题\"" /tmp/xhs_snapshot.txt | head -1 | sed -n 's/.*\[ref=\(e[0-9]*\)\].*/\1/p')

# 5. 插入标题
echo "步骤 5: 填写标题..."
agent-browser fill "@$TITLE_REF" "$TITLE"

# 6. 将文件内容保存到剪切板
echo "步骤 6: 复制文件内容到剪切板..."
cat "$FILE_PATH" | pbcopy

# 7. 点击正文编辑框
echo "步骤 7: 点击正文编辑框..."
agent-browser click ".ProseMirror"

# 8. 粘贴内容
echo "步骤 8: 粘贴内容..."
agent-browser press "Meta+v"

# 等待内容加载
sleep 2

# 9. 一键排版
echo "步骤 9: 一键排版..."
agent-browser snapshot -i > /tmp/xhs_snapshot.txt 2>&1
FORMAT_BUTTON_REF=$(grep "button \"一键排版\"" /tmp/xhs_snapshot.txt | head -1 | sed -n 's/.*\[ref=\(e[0-9]*\)\].*/\1/p')
agent-browser click "@$FORMAT_BUTTON_REF"

# 10. 选择模版风格并进入下一步
echo "步骤 10: 准备进入发布设置..."
sleep 5
agent-browser snapshot -i > /tmp/xhs_snapshot.txt 2>&1

if [ -n "$TEMPLATE" ]; then
    echo "提示：模版风格 '$TEMPLATE' 需要手动选择（页面文字可能略有差异）"
    # 尝试点击模版，如果失败则继续
    agent-browser click "text=$TEMPLATE" 2>/dev/null || echo "模版选择跳过，使用默认"
    sleep 1
fi

# 点击"下一步"按钮
NEXT_BUTTON_REF=$(grep "button \"下一步\"" /tmp/xhs_snapshot.txt | head -1 | sed -n 's/.*\[ref=\(e[0-9]*\)\].*/\1/p')
if [ -z "$NEXT_BUTTON_REF" ]; then
    echo "错误：无法找到'下一步'按钮"
    exit 1
fi
agent-browser click "@$NEXT_BUTTON_REF"

# 12. 查看发布设置页面
echo "步骤 12: 查看发布设置页面..."
sleep 1

# 13. 输入简介
echo "步骤 13: 填写简介..."
agent-browser snapshot -i > /tmp/xhs_snapshot.txt 2>&1
DESC_REF=$(grep -m 1 'textbox \[ref=' /tmp/xhs_snapshot.txt | sed -n 's/.*\[ref=\(e[0-9]*\)\].*/\1/p')
if [ -n "$DESC_REF" ]; then
    agent-browser fill "@$DESC_REF" "$DESCRIPTION"

    # 14. 添加话题（如果提供）
    if [ -n "$TOPIC" ]; then
        echo "步骤 14: 添加话题..."
        agent-browser type "@$DESC_REF" " #$TOPIC"
        agent-browser press "Enter"
    fi
else
    echo "警告：未找到简介输入框，跳过"
fi

# 15. 提取发布按钮
echo "步骤 15: 准备发布选项..."
agent-browser snapshot -i > /tmp/xhs_snapshot.txt 2>&1
DRAFT_BUTTON_REF=$(grep "button \"暂存离开\"" /tmp/xhs_snapshot.txt | head -1 | sed -n 's/.*\[ref=\(e[0-9]*\)\].*/\1/p')
PUBLISH_BUTTON_REF=$(grep "button \"发布\"" /tmp/xhs_snapshot.txt | head -1 | sed -n 's/.*\[ref=\(e[0-9]*\)\].*/\1/p')

# 16. 最后一步：根据参数自动执行或询问用户
echo ""
echo "=== 发布选项 ==="

if [[ "$ACTION" == "publish" ]]; then
    echo "自动发布模式：立即发布..."
    agent-browser click "@$PUBLISH_BUTTON_REF"
    echo "✓ 发布成功"
elif [[ "$ACTION" == "draft" ]]; then
    echo "自动草稿模式：暂存草稿..."
    agent-browser click "@$DRAFT_BUTTON_REF"
    echo "✓ 已保存为草稿"
else
    echo "1) 暂存草稿并离开"
    echo "2) 立即发布"
    read -p "请选择操作 (1/2): " -n 1 -r
    echo

    if [[ $REPLY == "1" ]]; then
        echo "暂存草稿..."
        agent-browser click "@$DRAFT_BUTTON_REF"
        echo "✓ 已保存为草稿"
    elif [[ $REPLY == "2" ]]; then
        echo "发布内容..."
        agent-browser click "@$PUBLISH_BUTTON_REF"
        echo "✓ 发布成功"
    else
        echo "无效选择，退出"
        exit 1
    fi
fi

echo ""
echo "=== 完成 ==="
