# syntax=docker/dockerfile:1

# ---------- base ----------
FROM node:22-slim AS base
ENV PNPM_HOME="/pnpm" \
    PATH="/pnpm:$PATH" \
    NEXT_TELEMETRY_DISABLED=1
# corepack نسخهٔ pnpm را از فیلد packageManager در package.json می‌خواند
RUN corepack enable
WORKDIR /app

# ---------- deps ----------
FROM base AS deps
# رجیستری قابل تغییر (برای شبکهٔ کند می‌توان mirror داد)
ARG NPM_REGISTRY=https://registry.npmjs.org
ENV COREPACK_NPM_REGISTRY=${NPM_REGISTRY}
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
# timeout بلند برای شبکهٔ ضعیف (فقط فلگ‌هایی که pnpm 12 می‌پذیرد).
# پکیج‌های دانلودشده در cache mount می‌مانند و با اجرای دوباره ادامه پیدا می‌کنند.
RUN --mount=type=cache,id=pnpm-store,target=/pnpm/store \
    pnpm install --frozen-lockfile \
      --registry=${NPM_REGISTRY} \
      --fetch-timeout=600000

# ---------- builder ----------
FROM base AS builder
COPY --from=deps /app/node_modules ./node_modules
COPY . .
# next/font/google هنگام build فونت‌ها را دانلود می‌کند، پس build به اینترنت نیاز دارد
RUN pnpm build

# ---------- runner ----------
FROM node:22-slim AS runner
ENV NODE_ENV=production \
    NEXT_TELEMETRY_DISABLED=1 \
    PORT=3000 \
    HOSTNAME=0.0.0.0
WORKDIR /app

COPY --from=builder --chown=node:node /app/public ./public
COPY --from=builder --chown=node:node /app/.next/standalone ./
COPY --from=builder --chown=node:node /app/.next/static ./.next/static

USER node
EXPOSE 3000
CMD ["node", "server.js"]
