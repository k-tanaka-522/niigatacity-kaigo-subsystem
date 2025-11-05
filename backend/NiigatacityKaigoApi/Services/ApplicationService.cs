using NiigatacityKaigoApi.DTOs;
using NiigatacityKaigoApi.Models;
using NiigatacityKaigoApi.Repositories;

namespace NiigatacityKaigoApi.Services;

/// <summary>
/// 要介護認定申請サービス実装
/// </summary>
public class ApplicationService : IApplicationService
{
    private readonly IApplicationRepository _repository;
    private readonly ILogger<ApplicationService> _logger;

    public ApplicationService(
        IApplicationRepository repository,
        ILogger<ApplicationService> logger)
    {
        _repository = repository;
        _logger = logger;
    }

    public async Task<CareApplicationResponseDto?> GetByIdAsync(Guid id)
    {
        var application = await _repository.GetByIdAsync(id);
        return application != null ? MapToResponseDto(application) : null;
    }

    public async Task<IEnumerable<CareApplicationResponseDto>> GetAllAsync(int page = 1, int pageSize = 20)
    {
        var applications = await _repository.GetAllAsync(page, pageSize);
        return applications.Select(MapToResponseDto);
    }

    public async Task<IEnumerable<CareApplicationResponseDto>> GetBySubjectIdAsync(Guid subjectId)
    {
        var applications = await _repository.GetBySubjectIdAsync(subjectId);
        return applications.Select(MapToResponseDto);
    }

    public async Task<IEnumerable<CareApplicationResponseDto>> GetByFacilityIdAsync(Guid facilityId)
    {
        var applications = await _repository.GetByFacilityIdAsync(facilityId);
        return applications.Select(MapToResponseDto);
    }

    public async Task<CareApplicationResponseDto> CreateAsync(CreateCareApplicationDto dto, Guid userId)
    {
        var application = new CareApplication
        {
            ApplicationNumber = GenerateApplicationNumber(),
            SubjectId = dto.SubjectId,
            ApplicationType = dto.ApplicationType,
            ApplicationDate = dto.ApplicationDate,
            FacilityId = dto.FacilityId,
            Remarks = dto.Remarks,
            Status = "申請中",
            CreatedBy = userId
        };

        var created = await _repository.CreateAsync(application);
        _logger.LogInformation("Created new care application: {ApplicationNumber}", created.ApplicationNumber);

        return MapToResponseDto(created);
    }

    public async Task<CareApplicationResponseDto?> UpdateAsync(Guid id, UpdateCareApplicationDto dto, Guid userId)
    {
        var application = await _repository.GetByIdAsync(id);
        if (application == null)
            return null;

        // 更新可能なフィールドのみ更新
        if (dto.Status != null)
            application.Status = dto.Status;

        if (dto.CertificationResult != null)
            application.CertificationResult = dto.CertificationResult;

        if (dto.ValidFrom.HasValue)
            application.ValidFrom = dto.ValidFrom;

        if (dto.ValidTo.HasValue)
            application.ValidTo = dto.ValidTo;

        if (dto.Remarks != null)
            application.Remarks = dto.Remarks;

        application.UpdatedBy = userId;

        var updated = await _repository.UpdateAsync(application);
        _logger.LogInformation("Updated care application: {ApplicationNumber}", updated.ApplicationNumber);

        return MapToResponseDto(updated);
    }

    public async Task<bool> DeleteAsync(Guid id)
    {
        var result = await _repository.DeleteAsync(id);
        if (result)
        {
            _logger.LogInformation("Deleted care application: {Id}", id);
        }
        return result;
    }

    public Task<int> GetTotalCountAsync()
    {
        return _repository.GetTotalCountAsync();
    }

    private static CareApplicationResponseDto MapToResponseDto(CareApplication application)
    {
        return new CareApplicationResponseDto
        {
            Id = application.Id,
            ApplicationNumber = application.ApplicationNumber,
            SubjectId = application.SubjectId,
            SubjectName = application.Subject?.Name ?? string.Empty,
            ApplicationType = application.ApplicationType,
            ApplicationDate = application.ApplicationDate,
            Status = application.Status,
            CertificationResult = application.CertificationResult,
            ValidFrom = application.ValidFrom,
            ValidTo = application.ValidTo,
            Remarks = application.Remarks,
            CreatedAt = application.CreatedAt,
            UpdatedAt = application.UpdatedAt
        };
    }

    private static string GenerateApplicationNumber()
    {
        // 申請番号の生成ロジック (例: APP-YYYYMMDD-XXXXX)
        var date = DateTime.Now.ToString("yyyyMMdd");
        var random = new Random().Next(10000, 99999);
        return $"APP-{date}-{random}";
    }
}
