using System.Security.Claims;

namespace NiigataKaigo.API.Helpers;

/// <summary>
/// JWT トークンからユーザー情報を取得するヘルパークラス
///
/// 目的: Cognito が発行した JWT トークンのカスタムクレームから情報を抽出
/// 影響: すべての Controller で User 情報取得時に使用される
/// 前提: JWT 認証が正常に完了し、ClaimsPrincipal が設定されていること
/// </summary>
public static class JwtHelper
{
    /// <summary>
    /// ユーザーID（Cognito sub）を取得
    ///
    /// 目的: ユーザーを一意に識別する ID を取得
    /// 影響: ログ出力、監査ログ記録時に使用
    /// 前提: JWT トークンに "sub" クレームが含まれている
    /// </summary>
    /// <param name="user">ClaimsPrincipal（Controller の User プロパティ）</param>
    /// <returns>ユーザーID（UUID形式）、取得できない場合は null</returns>
    public static string? GetUserId(ClaimsPrincipal user)
    {
        return user.FindFirst(ClaimTypes.NameIdentifier)?.Value
               ?? user.FindFirst("sub")?.Value;
    }

    /// <summary>
    /// 事業所IDを取得
    ///
    /// 目的: データフィルタリング、事業所別アクセス制御に使用
    /// 影響: DB クエリで WHERE organizationId = {this value} のフィルタリング
    /// 前提: JWT トークンに "custom:organizationId" クレームが含まれている
    /// 注意: system_admin と auditor は全事業所アクセス可能なため、
    ///       フィルタリング不要な場合がある
    /// </summary>
    /// <param name="user">ClaimsPrincipal</param>
    /// <returns>事業所ID（例: "ORG-001"）、取得できない場合は null</returns>
    public static string? GetOrganizationId(ClaimsPrincipal user)
    {
        return user.FindFirst("custom:organizationId")?.Value;
    }

    /// <summary>
    /// ロールを取得
    ///
    /// 目的: ロールベースアクセス制御（RBAC）で権限チェックに使用
    /// 影響: API エンドポイントへのアクセス可否を決定
    /// 前提: JWT トークンに "custom:role" クレームが含まれている
    /// </summary>
    /// <param name="user">ClaimsPrincipal</param>
    /// <returns>ロール（system_admin / org_admin / staff / auditor）、取得できない場合は null</returns>
    public static string? GetRole(ClaimsPrincipal user)
    {
        return user.FindFirst("custom:role")?.Value
               ?? user.FindFirst(ClaimTypes.Role)?.Value;
    }

    /// <summary>
    /// 職員IDを取得
    ///
    /// 目的: 職員情報の識別、監査ログに記録
    /// 影響: 職員マスタとの紐付け、操作履歴の記録
    /// 前提: JWT トークンに "custom:employeeId" クレームが含まれている
    /// 注意: オプション属性のため、null の場合がある
    /// </summary>
    /// <param name="user">ClaimsPrincipal</param>
    /// <returns>職員ID（例: "EMP-12345"）、取得できない場合は null</returns>
    public static string? GetEmployeeId(ClaimsPrincipal user)
    {
        return user.FindFirst("custom:employeeId")?.Value;
    }

    /// <summary>
    /// メールアドレスを取得
    ///
    /// 目的: ユーザー識別、通知送信先として使用
    /// 影響: メール通知機能、ユーザー表示名として使用
    /// 前提: JWT トークンに "email" クレームが含まれている
    /// </summary>
    /// <param name="user">ClaimsPrincipal</param>
    /// <returns>メールアドレス、取得できない場合は null</returns>
    public static string? GetEmail(ClaimsPrincipal user)
    {
        return user.FindFirst(ClaimTypes.Email)?.Value
               ?? user.FindFirst("email")?.Value;
    }

    /// <summary>
    /// ユーザー名を取得
    ///
    /// 目的: ユーザー表示、ログ出力時の識別
    /// 影響: UI での表示、ログに記録
    /// 前提: JWT トークンに "name" クレームが含まれている
    /// </summary>
    /// <param name="user">ClaimsPrincipal</param>
    /// <returns>ユーザー名（姓名）、取得できない場合は null</returns>
    public static string? GetName(ClaimsPrincipal user)
    {
        return user.FindFirst("name")?.Value
               ?? user.FindFirst(ClaimTypes.Name)?.Value;
    }

    /// <summary>
    /// 事業所名を取得
    ///
    /// 目的: UI での事業所表示、ログ出力
    /// 影響: ユーザー情報表示、監査ログに記録
    /// 前提: JWT トークンに "custom:organizationName" クレームが含まれている
    /// </summary>
    /// <param name="user">ClaimsPrincipal</param>
    /// <returns>事業所名、取得できない場合は null</returns>
    public static string? GetOrganizationName(ClaimsPrincipal user)
    {
        return user.FindFirst("custom:organizationName")?.Value;
    }

    /// <summary>
    /// 所属部署を取得
    ///
    /// 目的: 職員情報表示、組織階層フィルタリング
    /// 影響: UI での表示、組織管理機能
    /// 前提: JWT トークンに "custom:department" クレームが含まれている
    /// 注意: オプション属性のため、null の場合がある
    /// </summary>
    /// <param name="user">ClaimsPrincipal</param>
    /// <returns>所属部署名、取得できない場合は null</returns>
    public static string? GetDepartment(ClaimsPrincipal user)
    {
        return user.FindFirst("custom:department")?.Value;
    }

    /// <summary>
    /// システム管理者かどうかを判定
    ///
    /// 目的: システム管理者専用機能のアクセス制御
    /// 影響: すべてのデータへのアクセス、ユーザー管理機能の実行可否
    /// 前提: JWT トークンに "custom:role" クレームが含まれている
    /// </summary>
    /// <param name="user">ClaimsPrincipal</param>
    /// <returns>true: システム管理者、false: その他のロール</returns>
    public static bool IsSystemAdmin(ClaimsPrincipal user)
    {
        var role = GetRole(user);
        return role == "system_admin";
    }

    /// <summary>
    /// 監査担当者かどうかを判定
    ///
    /// 目的: 監査機能のアクセス制御（閲覧のみ、変更不可）
    /// 影響: すべてのデータの閲覧は可能、変更・削除は不可
    /// 前提: JWT トークンに "custom:role" クレームが含まれている
    /// </summary>
    /// <param name="user">ClaimsPrincipal</param>
    /// <returns>true: 監査担当者、false: その他のロール</returns>
    public static bool IsAuditor(ClaimsPrincipal user)
    {
        var role = GetRole(user);
        return role == "auditor";
    }

    /// <summary>
    /// 全事業所アクセス可能かどうかを判定
    ///
    /// 目的: データフィルタリングが必要かどうかの判定
    /// 影響: DB クエリで organizationId フィルタリングを適用するか決定
    /// 前提: JWT トークンに "custom:role" クレームが含まれている
    /// 注意: system_admin と auditor のみ true を返す
    /// </summary>
    /// <param name="user">ClaimsPrincipal</param>
    /// <returns>true: 全事業所アクセス可能、false: 自事業所のみ</returns>
    public static bool CanAccessAllOrganizations(ClaimsPrincipal user)
    {
        var role = GetRole(user);
        return role == "system_admin" || role == "auditor";
    }
}
