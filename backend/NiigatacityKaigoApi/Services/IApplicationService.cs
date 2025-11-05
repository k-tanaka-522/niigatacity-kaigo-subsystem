using NiigatacityKaigoApi.DTOs;

namespace NiigatacityKaigoApi.Services;

/// <summary>
/// 要介護認定申請サービスインターフェース
/// </summary>
public interface IApplicationService
{
    Task<CareApplicationResponseDto?> GetByIdAsync(Guid id);
    Task<IEnumerable<CareApplicationResponseDto>> GetAllAsync(int page = 1, int pageSize = 20);
    Task<IEnumerable<CareApplicationResponseDto>> GetBySubjectIdAsync(Guid subjectId);
    Task<IEnumerable<CareApplicationResponseDto>> GetByFacilityIdAsync(Guid facilityId);
    Task<CareApplicationResponseDto> CreateAsync(CreateCareApplicationDto dto, Guid userId);
    Task<CareApplicationResponseDto?> UpdateAsync(Guid id, UpdateCareApplicationDto dto, Guid userId);
    Task<bool> DeleteAsync(Guid id);
    Task<int> GetTotalCountAsync();
}
