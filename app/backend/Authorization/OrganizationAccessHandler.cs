using Microsoft.AspNetCore.Authorization;
using NiigataKaigo.API.Helpers;

namespace NiigataKaigo.API.Authorization;

/// <summary>
/// 事業所IDによるデータ分離のための認可要件
///
/// 目的: リソースベースアクセス制御（ABAC: Attribute-Based Access Control）
///       ユーザーの事業所IDとリソースの事業所IDが一致するか検証
/// 影響: データ分離（マルチテナント）を実現、他事業所のデータアクセスを防止
/// 前提: JWT トークンに "custom:organizationId" クレームが含まれている
/// 例外: system_admin と auditor は全事業所アクセス可能
/// </summary>
public class OrganizationAccessRequirement : IAuthorizationRequirement
{
    /// <summary>
    /// アクセス対象リソースの事業所ID
    ///
    /// 目的: ユーザーの事業所IDと比較するための値
    /// 影響: この値とユーザーの organizationId が一致しない場合はアクセス拒否
    /// 前提: Controller からリソースの事業所IDを取得して設定
    /// </summary>
    public string ResourceOrganizationId { get; }

    public OrganizationAccessRequirement(string resourceOrganizationId)
    {
        ResourceOrganizationId = resourceOrganizationId;
    }
}

/// <summary>
/// 事業所アクセス要件のハンドラー実装
///
/// 目的: ユーザーが対象リソースにアクセス可能か検証
/// 影響: 検証失敗時は 403 Forbidden を返す
/// 前提: JWT トークンに "custom:organizationId" と "custom:role" が含まれている
///
/// ロジック:
/// 1. system_admin または auditor → 全事業所アクセス可能（認可成功）
/// 2. org_admin または staff → 自事業所のみアクセス可能
///    - ユーザーの organizationId == リソースの organizationId → 成功
///    - 一致しない → 失敗
/// </summary>
public class OrganizationAccessHandler : AuthorizationHandler<OrganizationAccessRequirement>
{
    private readonly ILogger<OrganizationAccessHandler> _logger;

    public OrganizationAccessHandler(ILogger<OrganizationAccessHandler> logger)
    {
        _logger = logger;
    }

    /// <summary>
    /// 事業所アクセス検証を実行
    ///
    /// 目的: ユーザーが対象リソースの事業所にアクセス可能か確認
    /// 影響: 認可成功時は context.Succeed(requirement)、失敗時は何もしない
    /// 前提: context.User に ClaimsPrincipal が設定されている
    ///
    /// 検証フロー:
    /// 1. ユーザーのロールと事業所IDを取得
    /// 2. system_admin または auditor の場合 → 即座に成功
    /// 3. その他のロール → 事業所IDが一致するか確認
    /// </summary>
    protected override Task HandleRequirementAsync(
        AuthorizationHandlerContext context,
        OrganizationAccessRequirement requirement)
    {
        var userId = JwtHelper.GetUserId(context.User);
        var userRole = JwtHelper.GetRole(context.User);
        var userOrgId = JwtHelper.GetOrganizationId(context.User);

        // ロール情報がない場合は認可失敗
        if (userRole == null)
        {
            _logger.LogWarning(
                "Organization access denied: User {UserId} has no role claim",
                userId);
            return Task.CompletedTask; // Fail
        }

        // system_admin と auditor は全事業所アクセス可能
        // 影響: すべてのリソースに対して認可成功
        if (JwtHelper.CanAccessAllOrganizations(context.User))
        {
            _logger.LogInformation(
                "Organization access granted: User {UserId} with role {Role} can access all organizations",
                userId,
                userRole);
            context.Succeed(requirement);
            return Task.CompletedTask;
        }

        // org_admin と staff は自事業所のみアクセス可能
        // 影響: organizationId が一致しない場合は 403 Forbidden
        if (userOrgId == null)
        {
            _logger.LogWarning(
                "Organization access denied: User {UserId} has no organizationId claim",
                userId);
            return Task.CompletedTask; // Fail
        }

        // 事業所IDが一致するか確認
        // 影響: 一致すれば認可成功、一致しなければ失敗
        if (userOrgId.Equals(requirement.ResourceOrganizationId, StringComparison.OrdinalIgnoreCase))
        {
            _logger.LogInformation(
                "Organization access granted: User {UserId} from organization {OrgId} can access resource from the same organization",
                userId,
                userOrgId);
            context.Succeed(requirement);
        }
        else
        {
            _logger.LogWarning(
                "Organization access denied: User {UserId} from organization {UserOrgId} attempted to access resource from organization {ResourceOrgId}",
                userId,
                userOrgId,
                requirement.ResourceOrganizationId);
        }

        return Task.CompletedTask;
    }
}
