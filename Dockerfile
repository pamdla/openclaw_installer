FROM node:22-bookworm

LABEL maintainer="https://github.com/pamdla"
LABEL description="OpenClaw - Your Personal AI Assistant"
LABEL version="1.0.0"

# ===== 阶段 1: 设置非交互环境（关键！必须最先设置）=====
ENV OPENCLAW_NO_PROMPT=1 \
    OPENCLAW_NO_ONBOARD=1 \
    CI=true \
    DEBIAN_FRONTEND=noninteractive \
    TZ=Asia/Shanghai

# 设置时区
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# ===== 阶段 2: 安装系统依赖（含原生模块编译工具）=====
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    jq \
    tzdata \
    python3 \
    make \
    g++ \
    ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# ===== 阶段 3: 配置 npm 和 pnpm（正确顺序！）=====
# 1. 先设置 npm registry
RUN npm config set registry https://registry.npmmirror.com

# 2. 安装 pnpm（此时还未设置 PNPM_HOME，使用默认位置）
RUN npm install -g pnpm@latest

# 3. 【关键】设置 PNPM_HOME 并创建目录（必须在配置前创建！）
ENV PNPM_HOME="/opt/pnpm"
ENV PATH="$PNPM_HOME/bin:$PATH"
RUN mkdir -p "$PNPM_HOME/bin" && chmod 755 "$PNPM_HOME" "$PNPM_HOME/bin"

# 4. 配置 pnpm 全局目录（现在 pnpm 已安装，命令可用）
RUN pnpm config set global-dir "$PNPM_HOME" && \
    pnpm config set global-bin-dir "$PNPM_HOME/bin" && \
    pnpm config set registry https://registry.npmmirror.com/

# ===== 阶段 4: 全局安装 OpenClaw（非交互模式）=====
# 直接使用 pnpm 安装，避免运行 install.sh（它可能触发 TTY 检查）
RUN pnpm add -g openclaw@latest

# 验证安装（静默模式，避免任何交互尝试）
RUN openclaw --version 2>&1 | grep -q "openclaw" && echo "✓ OpenClaw installed successfully" || \
    (echo "⚠ OpenClaw binary not in PATH, fixing..." && \
     export PATH="/opt/pnpm/bin:$PATH" && \
     openclaw --version && echo "✓ PATH fixed")

# ===== 阶段 5: 运行时配置 =====
WORKDIR /app

# 确保运行时 PATH 包含 pnpm bin
ENV PATH="/opt/pnpm/bin:$PATH"
ENV NODE_OPTIONS="--no-warnings"
ENV TERM="xterm"

# 启动 OpenClaw（非交互模式）
# CMD ["openclaw"]
