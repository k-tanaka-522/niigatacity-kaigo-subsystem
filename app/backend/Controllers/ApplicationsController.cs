using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using NiigataKaigo.API.Data;
using NiigataKaigo.API.DTOs;
using NiigataKaigo.API.Models;
using System.Security.Claims;

namespace NiigataKaigo.API.Controllers;

[Authorize]
[ApiController]
[Route("api/[controller]")]
public class ApplicationsController : ControllerBase
{
    private readonly ApplicationDbContext _context;
    private readonly ILogger<ApplicationsController> _logger;

    public ApplicationsController(
        ApplicationDbContext context,
        ILogger<ApplicationsController> logger)
    {
        _context = context;
        _logger = logger;
    }

    /// <summary>
    /// 申請一覧取得
    /// </summary>
    [HttpGet]
    public async Task<ActionResult<List<ApplicationDto>>> GetApplications(
        [FromQuery] string? status = null,
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 20)
    {
        try
        {
            var userId = int.Parse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value ?? "0");
            var userRole = User.FindFirst(ClaimTypes.Role)?.Value;
            var officeId = int.TryParse(User.FindFirst("office_id")?.Value, out var oid) ? oid : (int?)null;

            var query = _context.Applications
                .Include(a => a.Office)
                .Include(a => a.User)
                .Include(a => a.Files)
                .AsQueryable();

            // 権限によるフィルタリング
            if (userRole == "staff" && officeId.HasValue)
            {
                query = query.Where(a => a.OfficeId == officeId.Value);
            }

            // ステータスフィルタ
            if (!string.IsNullOrEmpty(status))
            {
                query = query.Where(a => a.Status == status);
            }

            var totalCount = await query.CountAsync();
            var applications = await query
                .OrderByDescending(a => a.CreatedAt)
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .Select(a => new ApplicationDto
                {
                    Id = a.Id,
                    ApplicationNumber = a.ApplicationNumber,
                    OfficeId = a.OfficeId,
                    OfficeName = a.Office.OfficeName,
                    UserId = a.UserId,
                    UserName = a.User.Name,
                    ApplicationType = a.ApplicationType,
                    Title = a.Title,
                    Content = a.Content,
                    Status = a.Status,
                    SubmittedAt = a.SubmittedAt,
                    ReviewedAt = a.ReviewedAt,
                    ReviewComment = a.ReviewComment,
                    FileCount = a.Files.Count,
                    CreatedAt = a.CreatedAt,
                    UpdatedAt = a.UpdatedAt
                })
                .ToListAsync();

            Response.Headers.Append("X-Total-Count", totalCount.ToString());
            Response.Headers.Append("X-Page", page.ToString());
            Response.Headers.Append("X-Page-Size", pageSize.ToString());

            return Ok(applications);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting applications");
            return StatusCode(500, new { message = "申請一覧の取得中にエラーが発生しました" });
        }
    }

    /// <summary>
    /// 申請詳細取得
    /// </summary>
    [HttpGet("{id}")]
    public async Task<ActionResult<ApplicationDto>> GetApplication(int id)
    {
        try
        {
            var application = await _context.Applications
                .Include(a => a.Office)
                .Include(a => a.User)
                .Include(a => a.Files)
                .Include(a => a.Reviewer)
                .FirstOrDefaultAsync(a => a.Id == id);

            if (application == null)
            {
                return NotFound(new { message = "申請が見つかりません" });
            }

            return Ok(new ApplicationDto
            {
                Id = application.Id,
                ApplicationNumber = application.ApplicationNumber,
                OfficeId = application.OfficeId,
                OfficeName = application.Office.OfficeName,
                UserId = application.UserId,
                UserName = application.User.Name,
                ApplicationType = application.ApplicationType,
                Title = application.Title,
                Content = application.Content,
                Status = application.Status,
                SubmittedAt = application.SubmittedAt,
                ReviewedAt = application.ReviewedAt,
                ReviewedBy = application.ReviewedBy,
                ReviewerName = application.Reviewer?.Name,
                ReviewComment = application.ReviewComment,
                FileCount = application.Files.Count,
                CreatedAt = application.CreatedAt,
                UpdatedAt = application.UpdatedAt
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting application {Id}", id);
            return StatusCode(500, new { message = "申請の取得中にエラーが発生しました" });
        }
    }

    /// <summary>
    /// 申請作成
    /// </summary>
    [HttpPost]
    public async Task<ActionResult<ApplicationDto>> CreateApplication([FromBody] CreateApplicationDto dto)
    {
        try
        {
            var userId = int.Parse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value ?? "0");
            var officeId = int.TryParse(User.FindFirst("office_id")?.Value, out var oid) ? oid : (int?)null;

            if (!officeId.HasValue)
            {
                return BadRequest(new { message = "事業所が設定されていません" });
            }

            // 申請番号生成（年月日 + 連番）
            var today = DateTime.UtcNow;
            var prefix = $"APP{today:yyyyMMdd}";
            var lastNumber = await _context.Applications
                .Where(a => a.ApplicationNumber.StartsWith(prefix))
                .CountAsync();
            var applicationNumber = $"{prefix}{(lastNumber + 1):D4}";

            var application = new Models.Application
            {
                ApplicationNumber = applicationNumber,
                OfficeId = officeId.Value,
                UserId = userId,
                ApplicationType = dto.ApplicationType,
                Title = dto.Title,
                Content = dto.Content,
                Status = "draft"
            };

            _context.Applications.Add(application);
            await _context.SaveChangesAsync();

            return CreatedAtAction(nameof(GetApplication), new { id = application.Id }, new ApplicationDto
            {
                Id = application.Id,
                ApplicationNumber = application.ApplicationNumber,
                ApplicationType = application.ApplicationType,
                Title = application.Title,
                Content = application.Content,
                Status = application.Status,
                CreatedAt = application.CreatedAt
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error creating application");
            return StatusCode(500, new { message = "申請の作成中にエラーが発生しました" });
        }
    }

    /// <summary>
    /// 申請提出
    /// </summary>
    [HttpPost("{id}/submit")]
    public async Task<ActionResult> SubmitApplication(int id)
    {
        try
        {
            var application = await _context.Applications.FindAsync(id);
            if (application == null)
            {
                return NotFound(new { message = "申請が見つかりません" });
            }

            if (application.Status != "draft")
            {
                return BadRequest(new { message = "この申請は既に提出されています" });
            }

            application.Status = "submitted";
            application.SubmittedAt = DateTime.UtcNow;
            application.UpdatedAt = DateTime.UtcNow;

            await _context.SaveChangesAsync();

            return Ok(new { message = "申請を提出しました" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error submitting application {Id}", id);
            return StatusCode(500, new { message = "申請の提出中にエラーが発生しました" });
        }
    }

    /// <summary>
    /// 申請審査（承認/却下）
    /// </summary>
    [Authorize(Roles = "admin,city_staff")]
    [HttpPost("{id}/review")]
    public async Task<ActionResult> ReviewApplication(int id, [FromBody] ReviewApplicationDto dto)
    {
        try
        {
            var userId = int.Parse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value ?? "0");
            var application = await _context.Applications.FindAsync(id);

            if (application == null)
            {
                return NotFound(new { message = "申請が見つかりません" });
            }

            if (application.Status != "submitted" && application.Status != "in_review")
            {
                return BadRequest(new { message = "この申請は審査できません" });
            }

            application.Status = dto.Approved ? "approved" : "rejected";
            application.ReviewedAt = DateTime.UtcNow;
            application.ReviewedBy = userId;
            application.ReviewComment = dto.Comment;
            application.UpdatedAt = DateTime.UtcNow;

            await _context.SaveChangesAsync();

            return Ok(new { message = dto.Approved ? "申請を承認しました" : "申請を却下しました" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error reviewing application {Id}", id);
            return StatusCode(500, new { message = "申請の審査中にエラーが発生しました" });
        }
    }
}
