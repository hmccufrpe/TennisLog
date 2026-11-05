using Microsoft.EntityFrameworkCore;
using Prometheus;
using TennisLog.Api.Data;
using TennisLog.Api.Models;

var builder = WebApplication.CreateBuilder(args);

// Structured (JSON) logs on stdout: one JSON object per line, ready for Promtail/Loki.
builder.Logging.ClearProviders();
builder.Logging.AddJsonConsole(o =>
{
    o.IncludeScopes = true;
    o.UseUtcTimestamp = true;
    o.TimestampFormat = "yyyy-MM-ddTHH:mm:ss.fffZ";
});

// Connection string comes from the environment (ConnectionStrings__Default); never hardcoded.
builder.Services.AddDbContext<AppDbContext>(o =>
    o.UseNpgsql(builder.Configuration.GetConnectionString("Default")));
builder.Services.AddHealthChecks().AddDbContextCheck<AppDbContext>("database");
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

var app = builder.Build();

// Creates the schema on first start (migrations can replace this later).
using (var scope = app.Services.CreateScope())
{
    scope.ServiceProvider.GetRequiredService<AppDbContext>().Database.EnsureCreated();
}

app.UseSwagger();
app.UseSwaggerUI();

// Prometheus: request count, duration and in-progress per route/status.
app.UseHttpMetrics();
app.MapMetrics();            // GET /metrics
app.MapHealthChecks("/health"); // GET /health (checks DB connectivity)

var matches = app.MapGroup("/matches");

matches.MapGet("/", async (AppDbContext db) =>
    await db.Matches.AsNoTracking()
        .OrderByDescending(m => m.MatchDate).ThenByDescending(m => m.Id)
        .ToListAsync());

matches.MapGet("/{id:int}", async (int id, AppDbContext db) =>
    await db.Matches.FindAsync(id) is { } match ? Results.Ok(match) : Results.NotFound());

matches.MapPost("/", async (MatchInput input, AppDbContext db, ILogger<Program> log) =>
{
    if (!input.TryValidate(out var errors)) return Results.ValidationProblem(errors);

    var match = new Match();
    input.ApplyTo(match);
    db.Matches.Add(match);
    await db.SaveChangesAsync();

    log.LogInformation("Match created {MatchId}", match.Id);
    return Results.Created($"/matches/{match.Id}", match);
});

matches.MapPut("/{id:int}", async (int id, MatchInput input, AppDbContext db, ILogger<Program> log) =>
{
    if (!input.TryValidate(out var errors)) return Results.ValidationProblem(errors);
    if (await db.Matches.FindAsync(id) is not { } match) return Results.NotFound();

    input.ApplyTo(match);
    await db.SaveChangesAsync();

    log.LogInformation("Match updated {MatchId}", id);
    return Results.Ok(match);
});

matches.MapDelete("/{id:int}", async (int id, AppDbContext db, ILogger<Program> log) =>
{
    if (await db.Matches.FindAsync(id) is not { } match) return Results.NotFound();

    db.Matches.Remove(match);
    await db.SaveChangesAsync();

    log.LogInformation("Match deleted {MatchId}", id);
    return Results.NoContent();
});

app.Run();

/// <summary>Exposes Program to the test project (WebApplicationFactory).</summary>
public partial class Program;
