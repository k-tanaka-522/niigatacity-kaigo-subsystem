using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace NiigataKaigo.API.Models;

/// <summary>
/// 介護保険申請書類
/// </summary>
[Table("applications")]
public class Application
{
    [Key]
    [Column("id")]
    public int Id { get; set; }

    [Required]
    [MaxLength(50)]
    [Column("application_number")]
    public string ApplicationNumber { get; set; } = string.Empty;

    [Column("office_id")]
    public int OfficeId { get; set; }

    [Column("user_id")]
    public int UserId { get; set; }

    [Required]
    [MaxLength(50)]
    [Column("application_type")]
    public string ApplicationType { get; set; } = string.Empty; // 新規申請、変更申請、廃止申請

    [Required]
    [MaxLength(200)]
    [Column("title")]
    public string Title { get; set; } = string.Empty;

    [Column("content", TypeName = "text")]
    public string? Content { get; set; }

    [Required]
    [MaxLength(30)]
    [Column("status")]
    public string Status { get; set; } = "draft"; // draft, submitted, in_review, approved, rejected

    [Column("submitted_at")]
    public DateTime? SubmittedAt { get; set; }

    [Column("reviewed_at")]
    public DateTime? ReviewedAt { get; set; }

    [Column("reviewed_by")]
    public int? ReviewedBy { get; set; }

    [MaxLength(500)]
    [Column("review_comment")]
    public string? ReviewComment { get; set; }

    [Column("created_at")]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    [Column("updated_at")]
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    // Navigation properties
    [ForeignKey("OfficeId")]
    public virtual Office Office { get; set; } = null!;

    [ForeignKey("UserId")]
    public virtual User User { get; set; } = null!;

    [ForeignKey("ReviewedBy")]
    public virtual User? Reviewer { get; set; }

    public virtual ICollection<ApplicationFile> Files { get; set; } = new List<ApplicationFile>();
}
