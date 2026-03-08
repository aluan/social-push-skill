#!/bin/bash
# 小红书长文发布脚本
# Usage: ./xiaohongshu-article.sh <文件路径> <标题> <简介> [话题] [模版风格] [发布动作] [原创声明]

set -e

# 参数检查
if [ $# -lt 3 ]; then
    echo "Usage: $0 <文件路径> <标题> <简介> [话题] [模版风格] [发布动作] [原创声明]"
    echo "Example: $0 /path/to/article.md '我的标题' '这是简介' '技术分享' '清晰明朗' 'publish' 'true'"
    echo ""
    echo "可选模版风格："
    echo "  简约基础、清晰明朗、黑白极简、轻感明快、黄昏手稿、手帐书写、灵感备忘、文艺清新、"
    echo "  札记集尘、涂鸦马克、素雅底纹、理性现代、优雅几何、逻辑结构、大图纯享、杂志先锋、"
    echo "  平实叙事、交叉拓扑、拼接色块、线条复古"
    echo ""
    echo "发布动作："
    echo "  publish - 立即发布（默认）"
    echo "  draft   - 保存草稿"
    echo ""
    echo "原创声明："
    echo "  true  - 声明原创（默认）"
    echo "  false - 不声明"
    exit 1
fi

FILE_PATH="$1"
TITLE="$2"
DESCRIPTION="$3"
TOPIC="${4:-}"
TEMPLATE="${5:-}"
ACTION="${6:-publish}"
ORIGINAL="${7:-true}"

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
[[ "$ORIGINAL" == "true" ]] && echo "原创声明: 是"
echo ""

# 1. 打开发布长文的网站
echo "步骤 1: 打开小红书创作者平台..."
agent-browser --headed --profile /tmp/agent-profile open "https://creator.xiaohongshu.com/publish/publish?source=official&from=tab_switch&target=article"

# 等待页面加载
agent-browser wait --load networkidle

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
agent-browser wait --load networkidle

# 9. 一键排版
echo "步骤 9: 一键排版..."
agent-browser snapshot -i > /tmp/xhs_snapshot.txt 2>&1
FORMAT_BUTTON_REF=$(grep "button \"一键排版\"" /tmp/xhs_snapshot.txt | head -1 | sed -n 's/.*\[ref=\(e[0-9]*\)\].*/\1/p')
agent-browser click "@$FORMAT_BUTTON_REF"

# 10. 选择模版风格并进入下一步
echo "步骤 10: 准备进入发布设置..."
agent-browser wait --load networkidle

if [ -n "$TEMPLATE" ]; then
    echo "提示：模版风格 '$TEMPLATE' 需要手动选择（页面文字可能略有差异）"
    # 尝试点击模版，如果失败则继续
    agent-browser click "text=$TEMPLATE" 2>/dev/null || echo "模版选择跳过，使用默认"
    sleep 1
fi

# 11. 检测页面状态：若有"下一步"则点击，若已在发布页则跳过
echo "步骤 11: 检测页面状态..."
sleep 2
PAGE_STATE=$(agent-browser eval "
  const hasNext = Array.from(document.querySelectorAll('button')).some(b => b.textContent.trim() === '下一步');
  const hasPublish = Array.from(document.querySelectorAll('button')).some(b => b.textContent.trim() === '发布');
  hasNext ? 'need_next' : (hasPublish ? 'publish_page' : 'unknown');
" 2>/dev/null | tr -d '"\r\n ')

if [[ "$PAGE_STATE" == "publish_page" ]]; then
    echo "  已在发布设置页，跳过'下一步'"
elif [[ "$PAGE_STATE" == "need_next" ]]; then
    echo "  检测到'下一步'按钮，点击进入发布设置..."
    NEXT_CLICKED="false"
    for i in 1 2 3 4 5; do
        LOOP_STATE=$(agent-browser eval "
          const hasNext = Array.from(document.querySelectorAll('button')).some(b => b.textContent.trim() === '下一步');
          const hasPublish = Array.from(document.querySelectorAll('button')).some(b => b.textContent.trim() === '发布');
          hasPublish && !hasNext ? 'publish_page' : (hasNext ? 'need_next' : 'unknown');
        " 2>/dev/null | tr -d '"\r\n ')
        if [[ "$LOOP_STATE" == "publish_page" ]]; then
            echo "  已自动跳转到发布设置页"
            NEXT_CLICKED="true"
            break
        fi
        NEXT_CLICKED=$(agent-browser eval "
          const btn = Array.from(document.querySelectorAll('button')).find(b => b.textContent.trim() === '下一步' && !b.disabled);
          if (btn) { btn.click(); 'true'; } else { 'false'; }
        " 2>/dev/null | tr -d '"\r\n ')
        if [[ "$NEXT_CLICKED" == "true" ]]; then
            break
        fi
        echo "  等待'下一步'按钮可用... ($i/5)"
        sleep 2
    done
    if [[ "$NEXT_CLICKED" != "true" ]]; then
        echo "错误：无法找到或点击'下一步'按钮（已重试5次）"
        exit 1
    fi
    agent-browser wait --load networkidle
else
    echo "警告：无法识别页面状态，继续尝试..."
fi

# 12. 等待发布设置页面就绪（确认"发布"按钮出现且"下一步"消失）
echo "步骤 12: 等待发布设置页面就绪..."
agent-browser wait --load networkidle
for i in 1 2 3 4 5; do
    ON_PUBLISH=$(agent-browser eval "
      const hasPublish = Array.from(document.querySelectorAll('button')).some(b => b.textContent.trim() === '发布');
      const hasNext = Array.from(document.querySelectorAll('button')).some(b => b.textContent.trim() === '下一步');
      String(hasPublish && !hasNext);
    " 2>/dev/null | tr -d '"\r\n ')
    if [[ "$ON_PUBLISH" == "true" ]]; then break; fi
    sleep 1
done
sleep 1

# 13. 输入简介（取最新快照，找第一个无名 textbox 即简介框）
echo "步骤 13: 填写简介..."
agent-browser snapshot -i --verbose > /tmp/xhs_snapshot.txt 2>&1
DESC_REF=$(grep 'textbox \[ref=' /tmp/xhs_snapshot.txt | grep -v '"' | head -1 | sed -n 's/.*\[ref=\(e[0-9]*\)\].*/\1/p')
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

# 15. 设置原创声明（如果需要）
if [[ "$ORIGINAL" == "true" ]]; then
    echo "步骤 15: 设置原创声明..."
    sleep 1
    # 点击原创声明 toggle（第一个 .custom-switch-card 的 input）
    agent-browser eval "
      const input = document.querySelectorAll('.custom-switch-card')[0]?.querySelector('input[type=checkbox]');
      if (input && !input.checked) { input.click(); true; } else { input?.checked ?? false; }
    " > /dev/null 2>&1
    sleep 1
    # 确认弹窗：检查是否有"原创声明须知"文字（避免误点其他 checkbox）
    DIALOG_VISIBLE=$(agent-browser eval "document.body.innerText.includes('原创声明须知') ? 'true' : 'false'" 2>/dev/null | tr -d '"\r\n ')
    if [[ "$DIALOG_VISIBLE" == "true" ]]; then
        # 勾选"我已阅读并同意《原创声明须知》"
        agent-browser eval "
          const cbs = document.querySelectorAll('input[type=checkbox]');
          const agreeBox = Array.from(cbs).find(cb => cb.closest('label, div')?.textContent?.includes('原创声明须知'));
          agreeBox?.click();
          true
        " > /dev/null 2>&1
        sleep 0.5
        # 点击"声明原创"按钮
        agent-browser eval "
          const btn = Array.from(document.querySelectorAll('button')).find(b => b.textContent.trim() === '声明原创');
          btn?.click(); !!btn
        " > /dev/null 2>&1
        sleep 1
    fi
    echo "✓ 已开启原创声明"
fi

# 16. 提取发布按钮
echo "步骤 16: 准备发布选项..."
# 等待页面稳定
sleep 1
agent-browser snapshot -i > /tmp/xhs_snapshot.txt 2>&1
DRAFT_BUTTON_REF=$(grep "button \"暂存离开\"" /tmp/xhs_snapshot.txt | head -1 | sed -n 's/.*\[ref=\(e[0-9]*\)\].*/\1/p')
PUBLISH_BUTTON_REF=$(grep "button \"发布\"" /tmp/xhs_snapshot.txt | head -1 | sed -n 's/.*\[ref=\(e[0-9]*\)\].*/\1/p')

# 17. 最后一步：根据参数自动执行或询问用户
echo ""
echo "=== 发布选项 ==="

if [[ "$ACTION" == "publish" ]]; then
    echo "自动发布模式：立即发布..."
    agent-browser click "@$PUBLISH_BUTTON_REF"
    agent-browser wait --load networkidle
    echo "✓ 发布成功"
elif [[ "$ACTION" == "draft" ]]; then
    echo "自动草稿模式：暂存草稿..."
    agent-browser click "@$DRAFT_BUTTON_REF"
    agent-browser wait --load networkidle
    echo "✓ 已保存为草稿"
fi

echo ""
echo "=== 完成 ==="
