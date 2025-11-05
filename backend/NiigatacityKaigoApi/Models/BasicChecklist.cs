using System.ComponentModel.DataAnnotations;

namespace NiigatacityKaigoApi.Models;

/// <summary>
/// 基本チェックリスト
/// </summary>
public class BasicChecklist
{
    [Key]
    public Guid Id { get; set; }

    /// <summary>
    /// 対象者ID
    /// </summary>
    [Required]
    public Guid SubjectId { get; set; }

    /// <summary>
    /// チェック実施日
    /// </summary>
    [Required]
    public DateTime CheckDate { get; set; }

    /// <summary>
    /// チェックリストデータ（JSON形式で保存）
    /// </summary>
    [Required]
    public string ChecklistData { get; set; } = "{}";

    /// <summary>
    /// 総合判定結果
    /// </summary>
    [StringLength(100)]
    public string? JudgmentResult { get; set; }

    /// <summary>
    /// 提出状態 (下書き/提出済み)
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
