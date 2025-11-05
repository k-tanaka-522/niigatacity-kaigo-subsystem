using System.ComponentModel.DataAnnotations;

namespace NiigatacityKaigoApi.Models;

/// <summary>
/// 事業所ユーザー
/// </summary>
public class FacilityUser
{
    [Key]
    public Guid Id { get; set; }

    /// <summary>
    /// Cognito User ID
    /// </summary>
    [Required]
    [StringLength(256)]
    public string CognitoUserId { get; set; } = string.Empty;

    /// <summary>
    /// メールアドレス
    /// </summary>
    [Required]
    [StringLength(256)]
    public string Email { get; set; } = string.Empty;

    /// <summary>
    /// 氏名
    /// </summary>
    [Required]
    [StringLength(100)]
    public string Name { get; set; } = string.Empty;

    /// <summary>
    /// 事業所名
    /// </summary>
    [Required]
    [StringLength(200)]
    public string FacilityName { get; set; } = string.Empty;

    /// <summary>
    /// 事業所番号
    /// </summary>
    [Required]
    [StringLength(50)]
    public string FacilityNumber { get; set; } = string.Empty;

    /// <summary>
    /// 役割 (管理者/一般ユーザー)
    /// </summary>
    [Required]
    [StringLength(20)]
    public string Role { get; set; } = "一般ユーザー";

    /// <summary>
    /// 電話番号
    /// </summary>
    [StringLength(20)]
    public string? PhoneNumber { get; set; }

    /// <summary>
    /// 有効フラグ
    /// </summary>
    public bool IsActive { get; set; } = true;

    /// <summary>
    /// 最終ログイン日時
    /// </summary>
    public DateTime? LastLoginAt { get; set; }

    /// <summary>
    /// 作成日時
    /// </summary>
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    /// <summary>
    /// 更新日時
    /// </summary>
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    /// <summary>
    /// 削除フラグ
    /// </summary>
    public bool IsDeleted { get; set; } = false;
}
