using NiigatacityKaigoApi.Models;

namespace NiigatacityKaigoApi.Repositories;

/// <summary>
/// 要介護認定申請リポジトリインターフェース
/// </summary>
public interface IApplicationRepository
{
    Task<CareApplication?> GetByIdAsync(Guid id);
    Task<IEnumerable<CareApplication>> GetAllAsync(int page = 1, int pageSize = 20);
    Task<IEnumerable<CareApplication>> GetBySubjectIdAsync(Guid subjectId);
    Task<IEnumerable<CareApplication>> GetByFacilityIdAsync(Guid facilityId);
    Task<CareApplication> CreateAsync(CareApplication application);
    Task<CareApplication> UpdateAsync(CareApplication application);
    Task<bool> DeleteAsync(Guid id);
    Task<int> GetTotalCountAsync();
}
