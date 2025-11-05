using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace NiigatacityKaigoApi.Models;

/// <summary>
/// 要介護認定申請
/// </summary>
public class CareApplication
{
    [Key]
    public Guid Id { get; set; }

    /// <summary>
    /// 申請番号
    /// </summary>
    [Required]
    [StringLength(50)]
    public string ApplicationNumber { get; set; } = string.Empty;

    /// <summary>
    /// 対象者ID
    /// </summary>
    [Required]
    public Guid SubjectId { get; set; }

    /// <summary>
    /// 対象者（ナビゲーションプロパティ）
    /// </summary>
    [ForeignKey(nameof(SubjectId))]
    public Subject? Subject { get; set; }

    /// <summary>
    /// 申請区分 (新規/更新/変更)
    /// </summary>
    [Required]
    [StringLength(20)]
    public string ApplicationType { get; set; } = string.Empty;

    /// <summary>
    /// 申請日
    /// </summary>
    [Required]
    public DateTime ApplicationDate { get; set; }

    /// <summary>
    /// 申請事業所ID
    /// </summary>
    public Guid? FacilityId { get; set; }

    /// <summary>
    /// 申請状態 (申請中/調査中/審査中/認定済み/却下)
    /// </summary>
    [Required]
    [StringLength(20)]
    public string Status { get; set; } = "申請中";

    /// <summary>
    /// 認定結果 (非該当/要支援1/要支援2/要介護1-5)
    /// </summary>
    [StringLength(20)]
    public string? CertificationResult { get; set; }

    /// <summary>
    /// 認定有効期間開始日
    /// </summary>
    public DateTime? ValidFrom { get; set; }

    /// <summary>
    /// 認定有効期間終了日
    /// </summary>
    public DateTime? ValidTo { get; set; }

    /// <summary>
    /// 備考
    /// </summary>
    [StringLength(1000)]
    public string? Remarks { get; set; }

    /// <summary>
    /// 作成日時
    /// </summary>
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    /// <summary>
    /// 更新日時
    /// </summary>
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    /// <summary>
    /// 作成者ID
    /// </summary>
    [Required]
    public Guid CreatedBy { get; set; }

    /// <summary>
    /// 更新者ID
    /// </summary>
    public Guid? UpdatedBy { get; set; }

    /// <summary>
    /// 削除フラグ
    /// </summary>
    public bool IsDeleted { get; set; } = false;
}
