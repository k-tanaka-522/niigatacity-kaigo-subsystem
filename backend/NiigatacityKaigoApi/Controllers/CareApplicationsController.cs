using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using NiigatacityKaigoApi.DTOs;
using NiigatacityKaigoApi.Services;
using System.Security.Claims;

namespace NiigatacityKaigoApi.Controllers;

/// <summary>
/// 要介護認定申請コントローラー
/// </summary>
[ApiController]
[Route("api/[controller]")]
[Authorize]
public class CareApplicationsController : ControllerBase
{
    private readonly IApplicationService _applicationService;
    private readonly ILogger<CareApplicationsController> _logger;

    public CareApplicationsController(
        IApplicationService applicationService,
        ILogger<CareApplicationsController> logger)
    {
        _applicationService = applicationService;
        _logger = logger;
    }

    /// <summary>
    /// 申請一覧取得
    /// </summary>
    [HttpGet]
    [ProducesResponseType(typeof(IEnumerable<CareApplicationResponseDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IEnumerable<CareApplicationResponseDto>>> GetApplications(
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 20)
    {
        var applications = await _applicationService.GetAllAsync(page, pageSize);
        var totalCount = await _applicationService.GetTotalCountAsync();

        Response.Headers["X-Total-Count"] = totalCount.ToString();
        Response.Headers["X-Page"] = page.ToString();
        Response.Headers["X-Page-Size"] = pageSize.ToString();

        return Ok(applications);
    }

    /// <summary>
    /// 申請詳細取得
    /// </summary>
    [HttpGet("{id}")]
    [ProducesResponseType(typeof(CareApplicationResponseDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<CareApplicationResponseDto>> GetApplication(Guid id)
    {
        var application = await _applicationService.GetByIdAsync(id);
        if (application == null)
        {
            return NotFound(new { message = "申請が見つかりません" });
        }

        return Ok(application);
    }

    /// <summary>
    /// 対象者別申請一覧取得
    /// </summary>
    [HttpGet("subject/{subjectId}")]
    [ProducesResponseType(typeof(IEnumerable<CareApplicationResponseDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IEnumerable<CareApplicationResponseDto>>> GetApplicationsBySubject(Guid subjectId)
    {
        var applications = await _applicationService.GetBySubjectIdAsync(subjectId);
        return Ok(applications);
    }

    /// <summary>
    /// 事業所別申請一覧取得
    /// </summary>
    [HttpGet("facility/{facilityId}")]
    [ProducesResponseType(typeof(IEnumerable<CareApplicationResponseDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IEnumerable<CareApplicationResponseDto>>> GetApplicationsByFacility(Guid facilityId)
    {
        var applications = await _applicationService.GetByFacilityIdAsync(facilityId);
        return Ok(applications);
    }

    /// <summary>
    /// 申請新規作成
    /// </summary>
    [HttpPost]
    [ProducesResponseType(typeof(CareApplicationResponseDto), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<CareApplicationResponseDto>> CreateApplication(
        [FromBody] CreateCareApplicationDto dto)
    {
        if (!ModelState.IsValid)
        {
            return BadRequest(ModelState);
        }

        var userId = GetCurrentUserId();
        var application = await _applicationService.CreateAsync(dto, userId);

        return CreatedAtAction(
            nameof(GetApplication),
            new { id = application.Id },
            application);
    }

    /// <summary>
    /// 申請更新
    /// </summary>
    [HttpPut("{id}")]
    [ProducesResponseType(typeof(CareApplicationResponseDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<CareApplicationResponseDto>> UpdateApplication(
        Guid id,
        [FromBody] UpdateCareApplicationDto dto)
    {
        if (!ModelState.IsValid)
        {
            return BadRequest(ModelState);
        }

        var userId = GetCurrentUserId();
        var application = await _applicationService.UpdateAsync(id, dto, userId);

        if (application == null)
        {
            return NotFound(new { message = "申請が見つかりません" });
        }

        return Ok(application);
    }

    /// <summary>
    /// 申請削除
    /// </summary>
    [HttpDelete("{id}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> DeleteApplication(Guid id)
    {
        var result = await _applicationService.DeleteAsync(id);

        if (!result)
        {
            return NotFound(new { message = "申請が見つかりません" });
        }

        return NoContent();
    }

    private Guid GetCurrentUserId()
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        return Guid.TryParse(userIdClaim, out var userId) ? userId : Guid.Empty;
    }
}
