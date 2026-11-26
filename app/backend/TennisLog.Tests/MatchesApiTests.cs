using System.Net;
using System.Net.Http.Json;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using TennisLog.Api.Data;
using TennisLog.Api.Models;

namespace TennisLog.Tests;

/// <summary>Boots the real API in memory, swapping PostgreSQL for the EF in-memory provider.</summary>
public class ApiFactory : WebApplicationFactory<Program>
{
    private readonly string _dbName = Guid.NewGuid().ToString();

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.ConfigureServices(services =>
        {
            var registration = services.Single(s => s.ServiceType == typeof(DbContextOptions<AppDbContext>));
            services.Remove(registration);
            services.AddDbContext<AppDbContext>(o => o.UseInMemoryDatabase(_dbName));
        });
    }
}

/// <summary>API-level tests: CRUD flow, validation, health and metrics endpoints.</summary>
public class MatchesApiTests(ApiFactory factory) : IClassFixture<ApiFactory>
{
    private readonly HttpClient _client = factory.CreateClient();

    private static object ValidBody(string opponent = "Carlos") => new
    {
        matchDate = "2026-11-01",
        opponent,
        score = "6-4 6-3",
        surface = "Saibro",
        notes = "Good serve day"
    };

    private async Task<Match> CreateAsync(string opponent = "Carlos")
    {
        var response = await _client.PostAsJsonAsync("/matches", ValidBody(opponent));
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        return (await response.Content.ReadFromJsonAsync<Match>())!;
    }

    [Fact]
    public async Task Health_ReturnsHealthy()
    {
        var response = await _client.GetAsync("/health");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal("Healthy", await response.Content.ReadAsStringAsync());
    }

    [Fact]
    public async Task Metrics_ExposesPrometheusFormat()
    {
        await _client.GetAsync("/matches"); // generate at least one HTTP sample
        var body = await (await _client.GetAsync("/metrics")).Content.ReadAsStringAsync();
        Assert.Contains("http_request_duration_seconds", body);
    }

    [Fact]
    public async Task Create_PersistsAndIsReturnedByGet()
    {
        var created = await CreateAsync("Ana");
        var fetched = await _client.GetFromJsonAsync<Match>($"/matches/{created.Id}");
        Assert.Equal("Ana", fetched!.Opponent);
        Assert.Equal(new DateOnly(2026, 11, 1), fetched.MatchDate);
    }

    [Fact]
    public async Task Create_InvalidBody_Returns400()
    {
        var response = await _client.PostAsJsonAsync("/matches", new { opponent = "", score = "" });
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task Get_UnknownId_Returns404()
    {
        var response = await _client.GetAsync("/matches/999999");
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task Update_ChangesFields()
    {
        var created = await CreateAsync();
        var response = await _client.PutAsJsonAsync($"/matches/{created.Id}", new
        {
            matchDate = "2026-11-02",
            opponent = "Bia",
            score = "7-5 6-4"
        });
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var updated = await _client.GetFromJsonAsync<Match>($"/matches/{created.Id}");
        Assert.Equal("Bia", updated!.Opponent);
        Assert.Null(updated.Surface);
    }

    [Fact]
    public async Task Update_UnknownId_Returns404()
    {
        var response = await _client.PutAsJsonAsync("/matches/999999", ValidBody());
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task Delete_RemovesMatch()
    {
        var created = await CreateAsync();
        Assert.Equal(HttpStatusCode.NoContent, (await _client.DeleteAsync($"/matches/{created.Id}")).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await _client.GetAsync($"/matches/{created.Id}")).StatusCode);
    }
}
