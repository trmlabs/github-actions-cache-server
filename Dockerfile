ARG BASE_IMAGE=node:24.22.1-alpine@sha256:6a1c190e17215d844926b0677f4bf87273ff7d5e54db06d3b5b5863ab0b09a3d

FROM ${BASE_IMAGE} AS builder

WORKDIR /app

RUN --mount=type=cache,target=/root/.npm npm install -g pnpm@latest-10

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./

RUN --mount=type=cache,target=/root/.local/share/pnpm/store pnpm fetch --prod
RUN --mount=type=cache,target=/root/.local/share/pnpm/store pnpm install --frozen-lockfile --prod --offline

COPY . .

ARG BUILD_HASH
ENV BUILD_HASH=${BUILD_HASH}
RUN pnpm run build

# --------------------------------------------

FROM ${BASE_IMAGE} AS runner

ARG BASE_IMAGE

ENV NITRO_CLUSTER_WORKERS=1
ENV NODE_CAGED=false

WORKDIR /app

COPY --from=builder /app/.output ./

RUN if echo "$BASE_IMAGE" | grep -q "node-caged"; then \
			echo "export NODE_CAGED=true" > /app/.runtime-env; \
		else \
			echo "export NODE_CAGED=false" > /app/.runtime-env; \
		fi

CMD ["sh", "-c", ". /app/.runtime-env && exec node --expose-gc /app/server/index.mjs"]