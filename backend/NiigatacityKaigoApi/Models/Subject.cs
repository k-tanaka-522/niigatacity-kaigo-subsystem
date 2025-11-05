using System.ComponentModel.DataAnnotations;

namespace NiigatacityKaigoApi.Models;

/// <summary>
/// 対象者（被保険者）
/// </summary>
public class Subject
{
    [Key]
    public Guid Id { get; set; }

    /// <summary>
    /// 被保険者番号
    /// </summary>
    [Required]
    [StringLength(20)]
    public string InsuredNumber { get; set; } = string.Empty;

    /// <summary>
    /// 氏名
    /// </summary>
    [Required]
    [StringLength(100)]
    public string Name { get; set; } = string.Empty;

    /// <summary>
    /// 氏名カナ
    /// </summary>
    [StringLength(100)]
    public string? NameKana { get; set; }

    /// <summary>
    /// 生年月日
    /// </summary>
    [Required]
    public DateTime DateOfBirth { get; set; }

    /// <summary>
    /// 性別 (男性/女性/その他)
    /// </summary>
    [Required]
    [StringLength(10)]
    public string Gender { get; set; } = string.Empty;

    /// <summary>
    /// 郵便番号
    /// </summary>
    [StringLength(10)]
    public string? PostalCode { get; set; }

    /// <summary>
    /// 住所
    /// </summary>
    [StringLength(500)]
    public string? Address { get; set; }

    /// <summary>
    /// 電話番号
    /// </summary>
    [StringLength(20)]
    public string? PhoneNumber { get; set; }

    /// <summary>
    /// 緊急連絡先
    /// </summary>
    [StringLength(20)]
    public string? EmergencyContact { get; set; }

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
