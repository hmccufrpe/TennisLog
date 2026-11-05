# --- build stage: restore first so the layer is cached until the csproj changes
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY TennisLog.Api/TennisLog.Api.csproj TennisLog.Api/
RUN dotnet restore TennisLog.Api/TennisLog.Api.csproj
COPY TennisLog.Api/ TennisLog.Api/
RUN dotnet publish TennisLog.Api/TennisLog.Api.csproj -c Release -o /out --no-restore

# --- runtime stage: small image, non-root user
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime
WORKDIR /app
COPY --from=build /out .
USER app
ENV ASPNETCORE_HTTP_PORTS=8080
EXPOSE 8080
ENTRYPOINT ["dotnet", "TennisLog.Api.dll"]
