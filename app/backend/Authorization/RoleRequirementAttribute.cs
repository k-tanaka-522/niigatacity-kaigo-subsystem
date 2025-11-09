using Microsoft.AspNetCore.Authorization;

namespace NiigataKaigo.API.Authorization;

/// <summary>
/// ロールベースアクセス制御（RBAC）のための認可属性
///
/// 目的: Cognito のカスタムクレーム "custom:role" を検証し、
///       指定されたロールのユーザーのみ API アクセスを許可
/// 影響: Controller または Action メソッドに適用され、
///       条件を満たさない場合は 403 Forbidden を返す
/// 前提: JWT 認証が完了し、カスタムクレームがマッピングされていること
///
/// 使用例:
/// [RoleRequirement("system_admin")]
/// public async Task<IActionResult> DeleteUser(int id) { ... }
///
/// [RoleRequirement("system_admin", "org_admin")]
/// public async Task<IActionResult> UpdateApplication(int id) { ... }
/// </summary>
[AttributeUsage(AttributeTargets.Class | AttributeTargets.Method, AllowMultiple = false)]
public class RoleRequirementAttribute : AuthorizeAttribute
{
    /// <summary>
    /// 許可するロールのリスト
    ///
    /// 目的: 複数ロールを OR 条件で指定可能にする
    /// 影響: いずれかのロールを持っていればアクセス許可
    /// </summary>
    public string[] AllowedRoles { get; }

    /// <summary>
    /// コンストラクタ
    ///
    /// 目的: 許可するロールを指定してインスタンス化
    /// 影響: 指定されたロールのいずれかを持つユーザーのみアクセス可能
    /// 前提: roles には有効なロール名（system_admin / org_admin / staff / auditor）を指定
    /// </summary>
    /// <param name="roles">許可するロール（複数指定可能）</param>
    public RoleRequirementAttribute(params string[] roles)
    {
        AllowedRoles = roles;
        // AuthorizeAttribute の Policy にロールリストを設定
        // RoleRequirementHandler で検証される
        Policy = $"RequireRole:{string.Join(",", roles)}";
    }
}
