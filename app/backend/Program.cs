using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;
using NiigataKaigo.API.Authorization;
using NiigataKaigo.API.Data;
using NiigataKaigo.API.Middleware;
using System.Text;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new OpenApiInfo
    {
        Title = "新潟市介護保険事業所システム API",
        Version = "v1",
        Description = "新潟市介護保険事業所システムのWeb API"
    });

    // JWT認証設定
    c.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Description = "JWT Authorization header using the Bearer scheme. Example: \"Bearer {token}\"",
        Name = "Authorization",
        In = ParameterLocation.Header,
        Type = SecuritySchemeType.ApiKey,
        Scheme = "Bearer"
    });

    c.AddSecurityRequirement(new OpenApiSecurityRequirement
    {
        {
            new OpenApiSecurityScheme
            {
                Reference = new OpenApiReference
                {
                    Type = ReferenceType.SecurityScheme,
                    Id = "Bearer"
                }
            },
            Array.Empty<string>()
        }
    });
});

// Database Configuration
var connectionString = builder.Configuration.GetConnectionString("DefaultConnection")
    ?? throw new InvalidOperationException("ConnectionStrings:DefaultConnection is not configured");

builder.Services.AddDbContext<ApplicationDbContext>(options =>
    options.UseMySql(connectionString, ServerVersion.AutoDetect(connectionString)));

// Cognito JWT Authentication
// 目的: Amazon Cognito が発行した JWT トークンを検証
// 影響: すべての [Authorize] 属性付き API エンドポイントで認証が必須
// 前提: Cognito User Pool が作成済み、appsettings.json に設定値が記載されている
var cognitoRegion = builder.Configuration["Cognito:Region"]
    ?? throw new InvalidOperationException("Cognito:Region is not configured");
var cognitoUserPoolId = builder.Configuration["Cognito:UserPoolId"]
    ?? throw new InvalidOperationException("Cognito:UserPoolId is not configured");
var cognitoClientId = builder.Configuration["Cognito:ClientId"]
    ?? throw new InvalidOperationException("Cognito:ClientId is not configured");

// JWKS メタデータアドレス（Cognito の公開鍵を取得）
// 影響: JWT 署名検証に使用される RSA 公開鍵を動的に取得
// 注意: 対称鍵（SymmetricSecurityKey）ではなく、非対称鍵（RSA）を使用
var metadataAddress = $"https://cognito-idp.{cognitoRegion}.amazonaws.com/{cognitoUserPoolId}/.well-known/jwks.json";

// Issuer（発行者）の検証値
// 影響: JWT の "iss" クレームがこの値と一致しない場合は検証失敗
var issuer = $"https://cognito-idp.{cognitoRegion}.amazonaws.com/{cognitoUserPoolId}";

builder.Services.AddAuthentication(options =>
{
    options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
    options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
})
.AddJwtBearer(options =>
{
    options.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuer = true,
        ValidIssuer = issuer,
        ValidateAudience = true,
        ValidAudience = cognitoClientId,
        ValidateLifetime = true,
        ValidateIssuerSigningKey = true,
        // 公開鍵は JWKS から自動取得（MetadataAddress を指定）
        // 影響: トークン署名を RSA 公開鍵で検証
    };

    // JWKS メタデータアドレスを設定
    // 影響: Cognito の公開鍵を自動的に取得・キャッシュ
    options.MetadataAddress = metadataAddress;

    // カスタムクレームのマッピング
    // 目的: Cognito のカスタムクレーム（custom:organizationId, custom:role）を
    //       .NET の ClaimsPrincipal にマッピング
    // 影響: JwtHelper でカスタムクレームが取得可能になる
    options.Events = new JwtBearerEvents
    {
        OnTokenValidated = context =>
        {
            var claims = context.Principal?.Claims;
            if (claims != null)
            {
                // カスタムクレームをログ出力（デバッグ用）
                var logger = context.HttpContext.RequestServices
                    .GetRequiredService<ILogger<Program>>();
                logger.LogInformation(
                    "JWT validated for user {UserId}, claims: {Claims}",
                    context.Principal?.FindFirst("sub")?.Value,
                    string.Join(", ", claims.Select(c => $"{c.Type}={c.Value}")));
            }
            return Task.CompletedTask;
        },
        OnAuthenticationFailed = context =>
        {
            var logger = context.HttpContext.RequestServices
                .GetRequiredService<ILogger<Program>>();
            logger.LogError(
                context.Exception,
                "JWT authentication failed: {Message}",
                context.Exception.Message);
            return Task.CompletedTask;
        }
    };
});

// 認可ハンドラーの登録
// 目的: RoleRequirementAttribute と OrganizationAccessHandler の動作に必要
// 影響: [RoleRequirement] 属性と OrganizationAccessRequirement が動作する
builder.Services.AddSingleton<IAuthorizationHandler, RoleRequirementHandler>();
builder.Services.AddSingleton<IAuthorizationHandler, OrganizationAccessHandler>();

builder.Services.AddAuthorization();

// CORS設定
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowFrontend", policy =>
    {
        policy.WithOrigins("http://localhost:3000", "https://localhost:3000")
              .AllowAnyHeader()
              .AllowAnyMethod()
              .AllowCredentials();
    });
});

var app = builder.Build();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI(c =>
    {
        c.SwaggerEndpoint("/swagger/v1/swagger.json", "新潟市介護保険事業所システム API v1");
    });
}

app.UseHttpsRedirection();

app.UseCors("AllowFrontend");

// JWT エラーハンドリングミドルウェア
// 目的: JWT 検証エラーを統一されたフォーマットで返す
// 影響: 認証エラー時のユーザー体験を向上
// 注意: UseAuthentication() の後に配置
app.UseJwtErrorHandling();

app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

// Health Check Endpoint
app.MapGet("/health", () => Results.Ok(new { status = "healthy", timestamp = DateTime.UtcNow }));

app.Run();
