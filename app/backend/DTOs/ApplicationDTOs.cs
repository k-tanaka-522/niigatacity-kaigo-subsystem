using System.ComponentModel.DataAnnotations;

namespace NiigataKaigo.API.DTOs;

public class ApplicationDto
{
    public int Id { get; set; }
    public string ApplicationNumber { get; set; } = string.Empty;
    public int OfficeId { get; set; }
    public string? OfficeName { get; set; }
    public int UserId { get; set; }
    public string? UserName { get; set; }
    public string ApplicationType { get; set; } = string.Empty;
    public string Title { get; set; } = string.Empty;
    public string? Content { get; set; }
    public string Status { get; set; } = string.Empty;
    public DateTime? SubmittedAt { get; set; }
    public DateTime? ReviewedAt { get; set; }
    public int? ReviewedBy { get; set; }
    public string? ReviewerName { get; set; }
    public string? ReviewComment { get; set; }
    public int FileCount { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}

public class CreateApplicationDto
{
    [Required(ErrorMessage = "申請種別は必須です")]
    public string ApplicationType { get; set; } = string.Empty;

    [Required(ErrorMessage = "タイトルは必須です")]
    [MaxLength(200)]
    public string Title { get; set; } = string.Empty;

    public string? Content { get; set; }
}

public class ReviewApplicationDto
{
    public bool Approved { get; set; }
    public string? Comment { get; set; }
}
