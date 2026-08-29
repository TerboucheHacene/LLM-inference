# LLM-inference

Local lab for **quantizing**, **serving**, **benchmarking**, and **observing** an LLM with [vLLM](https://github.com/vllm-project/vllm).

## Layout

```
.
├── docker-compose.yml          # vLLM + Prometheus/Grafana/Loki/Tempo/Alloy + exporters
├── .env.example                # image tags, ports, which serve config to mount
├── vllm/
│   ├── entrypoint.sh           # CUDA compat fix + OTel instrumentation wrapper
│   └── configs/
│       ├── bf16.yaml           # Qwen3-0.6B bfloat16
│       └── w4a16.yaml          # GPTQ W4A16 checkpoint
├── observability/              # scrape configs, dashboards, instrumentation notes
├── notebooks/
│   ├── 01-quantize-gptq.ipynb  # post-training quantization with llm-compressor
│   ├── 02-serve-vllm.ipynb     # OpenAI API, continuous batching, KV / prefix cache
│   └── 03-benchmark-eval.ipynb # GuideLLM + lm_eval
└── models/                     # local weights (gitignored); mounted into the vLLM container
```

## Setup

```bash
uv sync
cp .env.example .env
```

Place model weights under `models/` (for example `models/Qwen3-0.6B`). The notebooks write quantized checkpoints there too.

## Serve

```bash
docker compose up -d
```

The OpenAI-compatible API is at http://localhost:8000. Grafana is at http://localhost:3000 (`admin` / `admin` by default).

[`vllm/entrypoint.sh`](vllm/entrypoint.sh) deletes the image's CUDA forward-compat libs (`/usr/local/cuda/compat`) before `vllm serve`. That was required on the local test box: a consumer GeForce with host driver 535, where those libs trigger CUDA error 804 (forward compatibility is not supported on GeForce). Skip or drop that block in production — datacenter GPUs and a driver that matches the image do not need it.

Switch to the W4A16 checkpoint:

```bash
VLLM_CONFIG=w4a16.yaml docker compose up -d --force-recreate
```

## Notebooks

1. `notebooks/01-quantize-gptq.ipynb` — GPTQ W4A16 with `llm-compressor`
2. `notebooks/02-serve-vllm.ipynb` — query the running server and inspect live metrics
3. `notebooks/03-benchmark-eval.ipynb` — throughput / quality evaluation

Generated JSON from the last two lands in `notebooks/outputs/` (gitignored).

## Observability

Metrics, logs, traces, and how they correlate: [`observability/README.md`](observability/README.md). vLLM-side instrumentation (metric names, log format, spans): [`observability/vllm-instrumentation.md`](observability/vllm-instrumentation.md).
