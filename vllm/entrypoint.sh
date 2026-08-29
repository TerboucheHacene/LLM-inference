#!/usr/bin/env bash
set -euo pipefail

# The image ldconfigs CUDA user-mode driver compat libs (libcuda from 575/580).
# On GeForce + host driver 535 that triggers CUDA error 804 (forward compatibility
# is not supported on consumer GPUs). Drop those libs and use the host driver.
shopt -s nullglob
rm -rf /usr/local/cuda/compat /usr/local/cuda-*/compat
ldconfig

# The OTel SDK/API/exporter/semconv packages are already bundled in the vLLM
# image. What's missing for logs<->traces correlation are the *instrumentation*
# packages: FastAPI (opens a live server span per request so logs get a real
# trace_id) and logging (injects that trace_id into every LogRecord). Install
# them only when the serve config enables a traces endpoint. Idempotent.
CONFIG_FILE=/etc/vllm/config.yaml
TRACING_ENABLED=0
if [[ -f "$CONFIG_FILE" ]] && grep -Eq '^[[:space:]]*otlp-traces-endpoint:' "$CONFIG_FILE"; then
	TRACING_ENABLED=1
	if ! python3 -c "import opentelemetry.instrumentation.fastapi" 2>/dev/null; then
		echo "entrypoint: installing OpenTelemetry instrumentation for log<->trace correlation..."
		pip install --no-cache-dir \
			opentelemetry-instrumentation-fastapi \
			opentelemetry-instrumentation-logging
	fi
fi

# Launch under opentelemetry-instrument so the auto-instrumentation (FastAPI +
# logging) is active. Falls back to a plain launch when tracing is disabled.
if [[ "$TRACING_ENABLED" == "1" ]]; then
	exec opentelemetry-instrument vllm serve "$@"
fi

exec vllm serve "$@"
