using Microsoft.EntityFrameworkCore;
using NiigatacityKaigoApi.Models;

namespace NiigatacityKaigoApi.Configuration;

public class ApplicationDbContext : DbContext
{
    public ApplicationDbContext(DbContextOptions<ApplicationDbContext> options)
        : base(options)
    {
    }

    // エンティティセット
    public DbSet<CareApplication> CareApplications { get; set; }
    public DbSet<AssessmentSurvey> AssessmentSurveys { get; set; }
    public DbSet<BasicChecklist> BasicChecklists { get; set; }
    public DbSet<CarePlan> CarePlans { get; set; }
    public DbSet<FacilityUser> FacilityUsers { get; set; }
    public DbSet<Subject> Subjects { get; set; }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        // テーブル名の設定
        modelBuilder.Entity<CareApplication>().ToTable("care_applications");
        modelBuilder.Entity<AssessmentSurvey>().ToTable("assessment_surveys");
        modelBuilder.Entity<BasicChecklist>().ToTable("basic_checklists");
        modelBuilder.Entity<CarePlan>().ToTable("care_plans");
        modelBuilder.Entity<FacilityUser>().ToTable("facility_users");
        modelBuilder.Entity<Subject>().ToTable("subjects");

        // インデックス設定
        modelBuilder.Entity<CareApplication>()
            .HasIndex(a => a.ApplicationNumber)
            .IsUnique();

        modelBuilder.Entity<Subject>()
            .HasIndex(s => s.InsuredNumber);

        // リレーション設定
        modelBuilder.Entity<CareApplication>()
            .HasOne(a => a.Subject)
            .WithMany()
            .HasForeignKey(a => a.SubjectId)
            .OnDelete(DeleteBehavior.Restrict);

        modelBuilder.Entity<AssessmentSurvey>()
            .HasOne(s => s.CareApplication)
            .WithMany()
            .HasForeignKey(s => s.ApplicationId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
