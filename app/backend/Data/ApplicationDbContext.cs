using Microsoft.EntityFrameworkCore;
using NiigataKaigo.API.Models;

namespace NiigataKaigo.API.Data;

public class ApplicationDbContext : DbContext
{
    public ApplicationDbContext(DbContextOptions<ApplicationDbContext> options)
        : base(options)
    {
    }

    public DbSet<User> Users { get; set; }
    public DbSet<Office> Offices { get; set; }
    public DbSet<Application> Applications { get; set; }
    public DbSet<ApplicationFile> ApplicationFiles { get; set; }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        // User
        modelBuilder.Entity<User>(entity =>
        {
            entity.HasIndex(e => e.Email).IsUnique();
            entity.HasOne(e => e.Office)
                .WithMany(o => o.Users)
                .HasForeignKey(e => e.OfficeId)
                .OnDelete(DeleteBehavior.SetNull);
        });

        // Office
        modelBuilder.Entity<Office>(entity =>
        {
            entity.HasIndex(e => e.OfficeCode).IsUnique();
        });

        // Application
        modelBuilder.Entity<Application>(entity =>
        {
            entity.HasIndex(e => e.ApplicationNumber).IsUnique();
            entity.HasOne(e => e.Office)
                .WithMany(o => o.Applications)
                .HasForeignKey(e => e.OfficeId)
                .OnDelete(DeleteBehavior.Restrict);
            entity.HasOne(e => e.User)
                .WithMany(u => u.Applications)
                .HasForeignKey(e => e.UserId)
                .OnDelete(DeleteBehavior.Restrict);
        });

        // ApplicationFile
        modelBuilder.Entity<ApplicationFile>(entity =>
        {
            entity.HasOne(e => e.Application)
                .WithMany(a => a.Files)
                .HasForeignKey(e => e.ApplicationId)
                .OnDelete(DeleteBehavior.Cascade);
        });
    }
}
