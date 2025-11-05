using System.ComponentModel.DataAnnotations;

namespace NiigatacityKaigoApi.Models;

/// <summary>
/// ケアプラン届
/// </summary>
public class CarePlan
{
    [Key]
    public Guid Id { get; set; }

    /// <summary>
    /// 対象者ID
    /// </summary>
    [Required]
    public Guid SubjectId { get; set; }

    /// <summary>
    /// ケアプラン作成日
    /// </summary>
    [Required]
    public DateTime PlanDate { get; set; }

    /// <summary>
    /// ケアマネージャー名
    /// </summary>
    [Required]
    [StringLength(100)]
    public string CareManagerName { get; set; } = string.Empty;

    /// <summary>
    /// 事業所ID
    /// </summary>
    [Required]
    public Guid FacilityId { get; set; }

    /// <summary>
    /// ケアプランデータ（JSON形式で保存）
    /// </summary>
    [Required]
    public string PlanData { get; set; } = "{}";

    /// <summary>
    /// 提出状態 (下書き/提出済み/承認済み/差し戻し)
    /// </summary>
    [Required]
    [StringLength(20)]
    public string SubmissionStatus { get; set; } = "下書き";

    /// <summary>
    /// 提出日時
    /// </summary>
    public DateTime? SubmittedAt { get; set; }

    /// <summary>
    /// 承認日時
    /// </summary>
    public DateTime? ApprovedAt { get; set; }

    /// <summary>
    /// 承認者ID
    /// </summary>
    public Guid? ApprovedBy { get; set; }

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
    /// 削除フラグ
    /// </summary>
    public bool IsDeleted { get; set; } = false;
}
