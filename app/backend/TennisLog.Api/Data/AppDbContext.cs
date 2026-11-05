using Microsoft.EntityFrameworkCore;
using TennisLog.Api.Models;

namespace TennisLog.Api.Data;

/// <summary>EF Core context; column limits mirror the DataAnnotations in MatchInput.</summary>
public class AppDbContext(DbContextOptions<AppDbContext> options) : DbContext(options)
{
    public DbSet<Match> Matches => Set<Match>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<Match>(e =>
        {
            e.ToTable("matches");
            e.Property(m => m.Opponent).HasMaxLength(100).IsRequired();
            e.Property(m => m.Score).HasMaxLength(30).IsRequired();
            e.Property(m => m.Surface).HasMaxLength(20);
            e.Property(m => m.Notes).HasMaxLength(500);
            e.HasIndex(m => m.MatchDate);
        });
    }
}
