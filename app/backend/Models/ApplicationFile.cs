using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace NiigataKaigo.API.Models;

/// <summary>
/// 申請書類の添付ファイル
/// </summary>
[Table("application_files")]
public class ApplicationFile
{
    [Key]
    [Column("id")]
    public int Id { get; set; }

    [Column("application_id")]
    public int ApplicationId { get; set; }

    [Required]
    [MaxLength(255)]
    [Column("file_name")]
    public string FileName { get; set; } = string.Empty;

    [Required]
    [MaxLength(500)]
    [Column("file_path")]
    public string FilePath { get; set; } = string.Empty;

    [MaxLength(100)]
    [Column("file_type")]
    public string? FileType { get; set; }

    [Column("file_size")]
    public long FileSize { get; set; }

    [Column("uploaded_at")]
    public DateTime UploadedAt { get; set; } = DateTime.UtcNow;

    // Navigation property
    [ForeignKey("ApplicationId")]
    public virtual Application Application { get; set; } = null!;
}
