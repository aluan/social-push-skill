#!/bin/bash
# 微信公众号文章发布脚本
# Usage: ./weixin-article.sh <文件路径> <标题> [作者] [封面图片路径] [操作]

set -e

# 参数检查
if [ $# -lt 2 ]; then
    echo "Usage: $0 <文件路径> <标题> [作者] [封面图片路径] [操作]"
    echo "Example: $0 /path/to/article.md '我的标题' '张三' /path/to/cover.jpg draft"
    echo ""
    echo "操作选项："
    echo "  draft   - 保存为草稿（默认）"
    echo "  publish - 立即发表"
    exit 1
fi

FILE_PATH="$1"
TITLE="$2"
AUTHOR="${3:-}"
COVER_IMAGE="${4:-}"
ACTION="${5:-draft}"

# 检查文件是否存在
if [ ! -f "$FILE_PATH" ]; then
    echo "错误：文件不存在: $FILE_PATH"
    exit 1
fi

# 检查封面图片（如果提供）
if [ -n "$COVER_IMAGE" ] && [ ! -f "$COVER_IMAGE" ]; then
    echo "错误：封面图片不存在: $COVER_IMAGE"
    exit 1
fi

echo "=== 微信公众号文章发布流程 ==="
echo "文件: $FILE_PATH"
echo "标题: $TITLE"
[ -n "$AUTHOR" ] && echo "作者: $AUTHOR"
[ -n "$COVER_IMAGE" ] && echo "封面: $COVER_IMAGE"
echo ""

# 1. 打开公众号后台
echo "步骤 1: 打开微信公众号后台..."
agent-browser --headed --profile /tmp/agent-profile open "https://mp.weixin.qq.com/"
sleep 3

# 2. 检测是否需要登录
agent-browser snapshot -i > /tmp/wx_snapshot.txt 2>&1
if grep -q '立即注册\|使用账号登录\|扫码登录' /tmp/wx_snapshot.txt; then
    echo ""
    echo ">>> 检测到未登录，请在浏览器中扫码或输入账号密码完成登录"
    read -p "    登录完成后按 Enter 继续..."
    sleep 2
fi

# 3. 点击新建文章
echo "步骤 3: 新建文章..."
agent-browser eval "document.querySelector('.new-creation__menu-title').click()"
sleep 3

# 4. 查看交互并提取元素
echo "步骤 4: 查看编辑页面..."
agent-browser snapshot -i > /tmp/wx_snapshot.txt 2>&1

# 5. 填写标题（精确匹配占位符）
echo "步骤 5: 填写标题..."
TITLE_REF=$(grep 'textbox "请在这里输入标题"' /tmp/wx_snapshot.txt | head -1 | sed -n 's/.*\[ref=\(e[0-9]*\)\].*/\1/p')
if [ -z "$TITLE_REF" ]; then
    echo "错误：无法找到标题输入框"
    exit 1
fi
agent-browser fill "@$TITLE_REF" "$TITLE"

# 6. 填写作者（如果提供）
if [ -n "$AUTHOR" ]; then
    echo "步骤 6: 填写作者..."
    AUTHOR_REF=$(grep 'textbox "请输入作者"' /tmp/wx_snapshot.txt | head -1 | sed -n 's/.*\[ref=\(e[0-9]*\)\].*/\1/p')
    if [ -n "$AUTHOR_REF" ]; then
        agent-browser click "@$AUTHOR_REF"
        sleep 1
        agent-browser snapshot -i > /tmp/wx_snapshot.txt 2>&1
        AUTHOR_OPTION_REF=$(grep "$AUTHOR" /tmp/wx_snapshot.txt | head -1 | sed -n 's/.*\[ref=\(e[0-9]*\)\].*/\1/p')
        [ -n "$AUTHOR_OPTION_REF" ] && agent-browser click "@$AUTHOR_OPTION_REF" || echo "未找到作者选项，跳过"
    else
        echo "未找到作者输入框，跳过"
    fi
fi

# 7. 粘贴正文内容到编辑器（ProseMirror）
echo "步骤 7: 粘贴正文内容..."
cat "$FILE_PATH" | pbcopy
agent-browser click ".ProseMirror"
sleep 1
agent-browser press "Meta+v"
sleep 2

# 8. 上传封面图片（如果提供）
if [ -n "$COVER_IMAGE" ]; then
    echo "步骤 8: 上传封面图片..."
    # 封面菜单不在 a11y tree，直接用 eval 点击"从图片库选择"
    COVER_DIALOG=$(agent-browser eval "(() => { var el = document.querySelector('#js_cover_null .js_imagedialog'); if(el){el.click(); return 'clicked';} return 'not found'; })()" 2>&1)
    if echo "$COVER_DIALOG" | grep -q "clicked"; then
        sleep 1
        agent-browser upload "input[type=file][accept*='image/bmp']" "$COVER_IMAGE"
        sleep 5
        # 点击下一步
        agent-browser find text "下一步" click
        sleep 2
        # 点击确认完成裁剪
        agent-browser snapshot -i > /tmp/wx_snapshot.txt 2>&1
        CONFIRM_REF=$(grep 'button "确认"' /tmp/wx_snapshot.txt | head -1 | sed -n 's/.*\[ref=\(e[0-9]*\)\].*/\1/p')
        if [ -n "$CONFIRM_REF" ]; then
            agent-browser click "@$CONFIRM_REF"
        else
            echo "未找到确认按钮，跳过"
        fi
        sleep 1
    else
        echo "未找到封面区域，跳过封面上传"
    fi
fi

# 9. 提取发布相关按钮
echo "步骤 9: 准备发布选项..."
agent-browser snapshot -i > /tmp/wx_snapshot.txt 2>&1
DRAFT_REF=$(grep 'button "保存为草稿"' /tmp/wx_snapshot.txt | head -1 | sed -n 's/.*\[ref=\(e[0-9]*\)\].*/\1/p')
PUBLISH_REF=$(grep 'button "发表"' /tmp/wx_snapshot.txt | head -1 | sed -n 's/.*\[ref=\(e[0-9]*\)\].*/\1/p')

# 10. 最后一步：根据参数执行操作
echo ""
if [[ "$ACTION" == "publish" ]]; then
    echo "发表文章..."
    agent-browser click "@$PUBLISH_REF"
    echo "✓ 发表成功"
else
    echo "保存草稿..."
    agent-browser click "@$DRAFT_REF"
    echo "✓ 已保存为草稿"
fi

echo ""
echo "=== 完成 ==="
