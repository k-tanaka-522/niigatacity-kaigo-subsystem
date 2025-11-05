using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace NiigataKaigo.API.Models;

/// <summary>
/// 介護保険事業所
/// </summary>
[Table("offices")]
public class Office
{
    [Key]
    [Column("id")]
    public int Id { get; set; }

    [Required]
    [MaxLength(100)]
    [Column("office_code")]
    public string OfficeCode { get; set; } = string.Empty;

    [Required]
    [MaxLength(200)]
    [Column("office_name")]
    public string OfficeName { get; set; } = string.Empty;

    [MaxLength(50)]
    [Column("office_type")]
    public string? OfficeType { get; set; } // 訪問介護、通所介護、etc

    [MaxLength(10)]
    [Column("postal_code")]
    public string? PostalCode { get; set; }

    [MaxLength(500)]
    [Column("address")]
    public string? Address { get; set; }

    [MaxLength(20)]
    [Column("phone")]
    public string? Phone { get; set; }

    [MaxLength(100)]
    [Column("representative_name")]
    public string? RepresentativeName { get; set; }

    [Column("is_active")]
    public bool IsActive { get; set; } = true;

    [Column("created_at")]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    [Column("updated_at")]
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    // Navigation properties
    public virtual ICollection<User> Users { get; set; } = new List<User>();
    public virtual ICollection<Application> Applications { get; set; } = new List<Application>();
}
