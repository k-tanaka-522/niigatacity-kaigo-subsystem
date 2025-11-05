using System.ComponentModel.DataAnnotations;

namespace NiigatacityKaigoApi.DTOs;

/// <summary>
/// 要介護認定申請作成DTO
/// </summary>
public class CreateCareApplicationDto
{
    [Required(ErrorMessage = "対象者IDは必須です")]
    public Guid SubjectId { get; set; }

    [Required(ErrorMessage = "申請区分は必須です")]
    [StringLength(20, ErrorMessage = "申請区分は20文字以内で入力してください")]
    public string ApplicationType { get; set; } = string.Empty;

    [Required(ErrorMessage = "申請日は必須です")]
    public DateTime ApplicationDate { get; set; }

    public Guid? FacilityId { get; set; }

    [StringLength(1000, ErrorMessage = "備考は1000文字以内で入力してください")]
    public string? Remarks { get; set; }
}

/// <summary>
/// 要介護認定申請更新DTO
/// </summary>
public class UpdateCareApplicationDto
{
    [StringLength(20)]
    public string? Status { get; set; }

    [StringLength(20)]
    public string? CertificationResult { get; set; }

    public DateTime? ValidFrom { get; set; }

    public DateTime? ValidTo { get; set; }

    [StringLength(1000)]
    public string? Remarks { get; set; }
}

/// <summary>
/// 要介護認定申請レスポンスDTO
/// </summary>
public class CareApplicationResponseDto
{
    public Guid Id { get; set; }
    public string ApplicationNumber { get; set; } = string.Empty;
    public Guid SubjectId { get; set; }
    public string SubjectName { get; set; } = string.Empty;
    public string ApplicationType { get; set; } = string.Empty;
    public DateTime ApplicationDate { get; set; }
    public string Status { get; set; } = string.Empty;
    public string? CertificationResult { get; set; }
    public DateTime? ValidFrom { get; set; }
    public DateTime? ValidTo { get; set; }
    public string? Remarks { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}
