using Microsoft.AspNetCore.Authorization;
using NiigataKaigo.API.Helpers;

namespace NiigataKaigo.API.Authorization;

/// <summary>
/// ロール要件を検証する認可ハンドラー
///
/// 目的: RoleRequirementAttribute で指定されたロールを持つユーザーのみアクセス許可
/// 影響: 認可失敗時は 403 Forbidden を返し、API 実行を中断
/// 前提: JWT 認証が完了し、ClaimsPrincipal にカスタムクレームが設定されている
/// </summary>
public class RoleRequirement : IAuthorizationRequirement
{
    /// <summary>
    /// 許可するロールのリスト（OR 条件）
    ///
    /// 目的: 複数ロールのいずれかを持っていればアクセス許可
    /// 影響: いずれかのロールにマッチすればSuccess、全てマッチしなければFail
    /// </summary>
    public string[] AllowedRoles { get; }

    public RoleRequirement(params string[] roles)
    {
        AllowedRoles = roles;
    }
}

/// <summary>
/// ロール要件のハンドラー実装
///
/// 目的: ユーザーのロールが許可リストに含まれているか検証
/// 影響: 検証成功 → API 実行継続、検証失敗 → 403 Forbidden
/// 前提: JWT トークンに "custom:role" クレームが含まれている
/// </summary>
public class RoleRequirementHandler : AuthorizationHandler<RoleRequirement>
{
    private readonly ILogger<RoleRequirementHandler> _logger;

    public RoleRequirementHandler(ILogger<RoleRequirementHandler> logger)
    {
        _logger = logger;
    }

    /// <summary>
    /// ロール検証を実行
    ///
    /// 目的: ユーザーのロールが許可されたロールに含まれているか確認
    /// 影響: 認可成功時は context.Succeed(requirement) を呼び出し、
    ///       認可失敗時は何もせず（デフォルトで Fail）
    /// 前提: context.User に ClaimsPrincipal が設定されている
    ///
    /// ロジック:
    /// 1. JwtHelper.GetRole() でユーザーのロールを取得
    /// 2. AllowedRoles にユーザーのロールが含まれているか確認
    /// 3. 含まれていれば成功、含まれていなければ失敗
    /// </summary>
    protected override Task HandleRequirementAsync(
        AuthorizationHandlerContext context,
        RoleRequirement requirement)
    {
        // ユーザーのロールを取得
        // 影響: "custom:role" クレームが存在しない場合は null
        var userRole = JwtHelper.GetRole(context.User);

        if (userRole == null)
        {
            // ロール情報がない場合は認可失敗
            _logger.LogWarning(
                "Authorization failed: User {UserId} has no role claim",
                JwtHelper.GetUserId(context.User));
            return Task.CompletedTask; // Fail（Succeed を呼ばない）
        }

        // 許可されたロールに含まれているか確認
        // 影響: いずれかのロールにマッチすれば認可成功
        if (requirement.AllowedRoles.Contains(userRole, StringComparer.OrdinalIgnoreCase))
        {
            _logger.LogInformation(
                "Authorization succeeded: User {UserId} with role {Role} is allowed",
                JwtHelper.GetUserId(context.User),
                userRole);
            context.Succeed(requirement);
        }
        else
        {
            // ロールが許可リストに含まれていない場合は認可失敗
            _logger.LogWarning(
                "Authorization failed: User {UserId} with role {Role} is not in allowed roles [{AllowedRoles}]",
                JwtHelper.GetUserId(context.User),
                userRole,
                string.Join(", ", requirement.AllowedRoles));
        }

        return Task.CompletedTask;
    }
}
