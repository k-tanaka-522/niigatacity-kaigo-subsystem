# マルチステージビルド
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# プロジェクトファイルをコピーして復元
COPY ["NiigatacityKaigoApi/NiigatacityKaigoApi.csproj", "NiigatacityKaigoApi/"]
RUN dotnet restore "NiigatacityKaigoApi/NiigatacityKaigoApi.csproj"

# ソースコードをコピーしてビルド
COPY . .
WORKDIR "/src/NiigatacityKaigoApi"
RUN dotnet build "NiigatacityKaigoApi.csproj" -c Release -o /app/build

# 公開
FROM build AS publish
RUN dotnet publish "NiigatacityKaigoApi.csproj" -c Release -o /app/publish /p:UseAppHost=false

# ランタイムイメージ
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS final
WORKDIR /app

# 非rootユーザーで実行
RUN groupadd -r appuser && useradd -r -g appuser appuser
RUN chown -R appuser:appuser /app

COPY --from=publish --chown=appuser:appuser /app/publish .

USER appuser

EXPOSE 8080

ENV ASPNETCORE_URLS=http://+:8080
ENV ASPNETCORE_ENVIRONMENT=Production

ENTRYPOINT ["dotnet", "NiigatacityKaigoApi.dll"]
