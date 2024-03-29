FROM mcr.microsoft.com/dotnet/aspnet:8.0.2-jammy@sha256:691ca98172664fe4c4fe8ba0720ca7d00bcda6d742ba859770df38fcf9e19120 as certs
ARG TARGETARCH
ARG BUILD_DATE
ARG BUILD_URL
ARG COMMIT_SHA

RUN apt update && apt install curl -y
RUN curl -ks 'https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem' -o 'global-bundle.pem'
RUN csplit -sz global-bundle.pem '/-BEGIN CERTIFICATE-/' '{*}'
RUN /bin/sh -c 'for CERT in xx*; do cp $CERT /usr/local/share/ca-certificates/$CERT.crt;done'
RUN update-ca-certificates

FROM mcr.microsoft.com/dotnet/aspnet:8.0.2-jammy-chiseled@sha256:cb35170c5c4687e42749a4f3538e6667cd682493466cc1535d8579befc23e077 as final

LABEL org.opencontainers.image.title="Dotnet Sample API Project" \
  org.opencontainers.image.source="https://github.com/callmetirex/tirex-live-ci-cd" \
  org.opencontainers.image.created=$BUILD_DATE \
  org.opencontainers.image.revision=$COMMIT_SHA \
  org.opencontainers.image.url=$BUILD_URL

WORKDIR /app
COPY ./app/publish .
COPY --from=certs /etc/ssl/certs /etc/ssl/certs

# Enable Datadog automatic instrumentation
# App is being copied to /app, so Datadog assets are at /app/datadog
ENV CORECLR_ENABLE_PROFILING=1 \
    CORECLR_PROFILER={846F5F1C-F9AE-4B07-969E-05C26BC060D8} \
    CORECLR_PROFILER_PATH=/app/datadog/linux-arm64/Datadog.Trace.ClrProfiler.Native.so \
    DD_LOGS_INJECTION=true \
    DD_DOTNET_TRACER_HOME=/app/datadog \
    DD_TRACE_LOG_DIRECTORY=/tmp/datadog \
    DOTNET_EnableDiagnostics=1 \
    DOTNET_EnableDiagnostics_IPC=0 \
    DOTNET_EnableDiagnostics_Debugger=0 \
    DOTNET_EnableDiagnostics_Profiler=1

ENTRYPOINT ["dotnet", "DotNetSampleProject.API.dll"]