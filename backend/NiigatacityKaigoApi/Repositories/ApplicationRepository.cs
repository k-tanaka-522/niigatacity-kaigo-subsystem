using Microsoft.EntityFrameworkCore;
using NiigatacityKaigoApi.Configuration;
using NiigatacityKaigoApi.Models;

namespace NiigatacityKaigoApi.Repositories;

/// <summary>
/// 要介護認定申請リポジトリ実装
/// </summary>
public class ApplicationRepository : IApplicationRepository
{
    private readonly ApplicationDbContext _context;

    public ApplicationRepository(ApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<CareApplication?> GetByIdAsync(Guid id)
    {
        return await _context.CareApplications
            .Include(a => a.Subject)
            .FirstOrDefaultAsync(a => a.Id == id && !a.IsDeleted);
    }

    public async Task<IEnumerable<CareApplication>> GetAllAsync(int page = 1, int pageSize = 20)
    {
        return await _context.CareApplications
            .Include(a => a.Subject)
            .Where(a => !a.IsDeleted)
            .OrderByDescending(a => a.CreatedAt)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync();
    }

    public async Task<IEnumerable<CareApplication>> GetBySubjectIdAsync(Guid subjectId)
    {
        return await _context.CareApplications
            .Include(a => a.Subject)
            .Where(a => a.SubjectId == subjectId && !a.IsDeleted)
            .OrderByDescending(a => a.ApplicationDate)
            .ToListAsync();
    }

    public async Task<IEnumerable<CareApplication>> GetByFacilityIdAsync(Guid facilityId)
    {
        return await _context.CareApplications
            .Include(a => a.Subject)
            .Where(a => a.FacilityId == facilityId && !a.IsDeleted)
            .OrderByDescending(a => a.ApplicationDate)
            .ToListAsync();
    }

    public async Task<CareApplication> CreateAsync(CareApplication application)
    {
        application.Id = Guid.NewGuid();
        application.CreatedAt = DateTime.UtcNow;
        application.UpdatedAt = DateTime.UtcNow;

        _context.CareApplications.Add(application);
        await _context.SaveChangesAsync();

        return application;
    }

    public async Task<CareApplication> UpdateAsync(CareApplication application)
    {
        application.UpdatedAt = DateTime.UtcNow;

        _context.CareApplications.Update(application);
        await _context.SaveChangesAsync();

        return application;
    }

    public async Task<bool> DeleteAsync(Guid id)
    {
        var application = await _context.CareApplications.FindAsync(id);
        if (application == null)
            return false;

        // 論理削除
        application.IsDeleted = true;
        application.UpdatedAt = DateTime.UtcNow;

        await _context.SaveChangesAsync();
        return true;
    }

    public async Task<int> GetTotalCountAsync()
    {
        return await _context.CareApplications
            .Where(a => !a.IsDeleted)
            .CountAsync();
    }
}
