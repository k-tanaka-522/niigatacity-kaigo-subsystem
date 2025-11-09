using System.Net;
using System.Text.Json;
using Microsoft.IdentityModel.Tokens;

namespace NiigataKaigo.API.Middleware;

/// <summary>
/// JWT 認証エラーをハンドリングするミドルウェア
///
/// 目的: JWT 検証失敗時に適切なエラーレスポンスを返す
/// 影響: 認証エラー時のユーザー体験を向上、セキュリティログを記録
/// 前提: JWT 認証ミドルウェア（UseAuthentication）の後に配置
///
/// エラー種別:
/// - トークン有効期限切れ: 401 Unauthorized、"トークンの有効期限が切れています"
/// - トークン不正: 401 Unauthorized、"トークンが無効です"
/// - トークンなし: 401 Unauthorized、"認証が必要です"
/// - その他のエラー: 500 Internal Server Error、"認証処理中にエラーが発生しました"
/// </summary>
public class JwtErrorHandlingMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<JwtErrorHandlingMiddleware> _logger;

    public JwtErrorHandlingMiddleware(
        RequestDelegate next,
        ILogger<JwtErrorHandlingMiddleware> logger)
    {
        _next = next;
        _logger = logger;
    }

    /// <summary>
    /// ミドルウェアの実行
    ///
    /// 目的: 次のミドルウェアを実行し、JWT エラーをキャッチ
    /// 影響: SecurityTokenException をキャッチしてエラーレスポンスに変換
    /// 前提: JWT 認証ミドルウェアが先に実行されている
    ///
    /// 処理フロー:
    /// 1. 次のミドルウェアを実行（try）
    /// 2. SecurityTokenException をキャッチ
    /// 3. エラー種別に応じた HTTP ステータスコードとメッセージを返す
    /// 4. エラーログを記録
    /// </summary>
    public async Task InvokeAsync(HttpContext context)
    {
        try
        {
            await _next(context);
        }
        catch (SecurityTokenExpiredException ex)
        {
            // トークン有効期限切れ
            // 影響: フロントエンドでリフレッシュトークンによる更新処理を促す
            _logger.LogWarning(
                ex,
                "JWT token expired for user {UserId} at {RequestPath}",
                context.User.Identity?.Name,
                context.Request.Path);

            await HandleExceptionAsync(
                context,
                HttpStatusCode.Unauthorized,
                "トークンの有効期限が切れています。再度ログインしてください。",
                "TOKEN_EXPIRED");
        }
        catch (SecurityTokenInvalidSignatureException ex)
        {
            // トークン署名が不正（改ざんの可能性）
            // 影響: セキュリティインシデントとして記録、即座にアクセス拒否
            _logger.LogError(
                ex,
                "Invalid JWT signature detected at {RequestPath}. Possible tampering attempt.",
                context.Request.Path);

            await HandleExceptionAsync(
                context,
                HttpStatusCode.Unauthorized,
                "トークンが無効です。",
                "INVALID_SIGNATURE");
        }
        catch (SecurityTokenInvalidIssuerException ex)
        {
            // Issuer（発行者）が不正
            // 影響: 不正な Cognito User Pool からのトークンを拒否
            _logger.LogError(
                ex,
                "Invalid JWT issuer at {RequestPath}",
                context.Request.Path);

            await HandleExceptionAsync(
                context,
                HttpStatusCode.Unauthorized,
                "トークンが無効です。",
                "INVALID_ISSUER");
        }
        catch (SecurityTokenInvalidAudienceException ex)
        {
            // Audience（対象者）が不正
            // 影響: 異なるクライアント向けのトークンを拒否
            _logger.LogError(
                ex,
                "Invalid JWT audience at {RequestPath}",
                context.Request.Path);

            await HandleExceptionAsync(
                context,
                HttpStatusCode.Unauthorized,
                "トークンが無効です。",
                "INVALID_AUDIENCE");
        }
        catch (SecurityTokenException ex)
        {
            // その他の JWT エラー（形式不正、パース失敗など）
            // 影響: 不正なトークン形式を拒否
            _logger.LogError(
                ex,
                "JWT validation failed at {RequestPath}",
                context.Request.Path);

            await HandleExceptionAsync(
                context,
                HttpStatusCode.Unauthorized,
                "トークンが無効です。",
                "INVALID_TOKEN");
        }
        catch (UnauthorizedAccessException ex)
        {
            // 認可失敗（トークンはあるが権限不足）
            // 影響: ロールや事業所IDによるアクセス制御で失敗した場合
            _logger.LogWarning(
                ex,
                "Unauthorized access attempt by user {UserId} at {RequestPath}",
                context.User.Identity?.Name,
                context.Request.Path);

            await HandleExceptionAsync(
                context,
                HttpStatusCode.Forbidden,
                "この操作を実行する権限がありません。",
                "FORBIDDEN");
        }
    }

    /// <summary>
    /// エラーレスポンスを生成
    ///
    /// 目的: 統一されたエラーレスポンス形式で返却
    /// 影響: フロントエンドでエラーコードに応じた処理が可能になる
    /// 前提: context.Response がまだ開始されていない
    ///
    /// レスポンス形式:
    /// {
    ///   "error": "エラーメッセージ",
    ///   "errorCode": "ERROR_CODE",
    ///   "statusCode": 401
    /// }
    /// </summary>
    private static async Task HandleExceptionAsync(
        HttpContext context,
        HttpStatusCode statusCode,
        string message,
        string errorCode)
    {
        context.Response.ContentType = "application/json";
        context.Response.StatusCode = (int)statusCode;

        var response = new
        {
            error = message,
            errorCode = errorCode,
            statusCode = (int)statusCode
        };

        var jsonOptions = new JsonSerializerOptions
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
            WriteIndented = true
        };

        var json = JsonSerializer.Serialize(response, jsonOptions);
        await context.Response.WriteAsync(json);
    }
}

/// <summary>
/// JwtErrorHandlingMiddleware の拡張メソッド
///
/// 目的: Program.cs でのミドルウェア登録を簡潔にする
/// 影響: app.UseJwtErrorHandling() で簡単に登録可能
/// </summary>
public static class JwtErrorHandlingMiddlewareExtensions
{
    public static IApplicationBuilder UseJwtErrorHandling(this IApplicationBuilder builder)
    {
        return builder.UseMiddleware<JwtErrorHandlingMiddleware>();
    }
}
