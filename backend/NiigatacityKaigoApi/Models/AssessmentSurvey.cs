using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace NiigatacityKaigoApi.Models;

/// <summary>
/// 認定調査票
/// </summary>
public class AssessmentSurvey
{
    [Key]
    public Guid Id { get; set; }

    /// <summary>
    /// 申請ID
    /// </summary>
    [Required]
    public Guid ApplicationId { get; set; }

    /// <summary>
    /// 申請（ナビゲーションプロパティ）
    /// </summary>
    [ForeignKey(nameof(ApplicationId))]
    public CareApplication? CareApplication { get; set; }

    /// <summary>
    /// 調査日
    /// </summary>
    [Required]
    public DateTime SurveyDate { get; set; }

    /// <summary>
    /// 調査員名
    /// </summary>
    [Required]
    [StringLength(100)]
    public string SurveyorName { get; set; } = string.Empty;

    /// <summary>
    /// 調査票データ（JSON形式で保存）
    /// </summary>
    [Required]
    public string SurveyData { get; set; } = "{}";

    /// <summary>
    /// 提出状態 (下書き/提出済み/差し戻し)
    /// </summary>
    [Required]
    [StringLength(20)]
    public string SubmissionStatus { get; set; } = "下書き";

    /// <summary>
    /// 提出日時
    /// </summary>
    public DateTime? SubmittedAt { get; set; }

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
