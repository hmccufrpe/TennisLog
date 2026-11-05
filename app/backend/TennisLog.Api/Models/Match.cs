using System.ComponentModel.DataAnnotations;

namespace TennisLog.Api.Models;

/// <summary>A tennis match stored in the "matches" table.</summary>
public class Match
{
    public int Id { get; set; }
    public DateOnly MatchDate { get; set; }
    public string Opponent { get; set; } = "";

    /// <summary>Free-form score, e.g. "6-4 3-6 7-5".</summary>
    public string Score { get; set; } = "";
    public string? Surface { get; set; }
    public string? Notes { get; set; }
}

/// <summary>
/// Request body for create/update. Validation rules live here (DataAnnotations)
/// so the API rejects bad input with a 400 before touching the database.
/// </summary>
public class MatchInput
{
    [Required] public DateOnly? MatchDate { get; set; }
    [Required, StringLength(100)] public string? Opponent { get; set; }
    [Required, StringLength(30)] public string? Score { get; set; }
    [StringLength(20)] public string? Surface { get; set; }
    [StringLength(500)] public string? Notes { get; set; }

    /// <summary>Runs DataAnnotations validation and groups messages by field.</summary>
    public bool TryValidate(out Dictionary<string, string[]> errors)
    {
        var results = new List<ValidationResult>();
        var ok = Validator.TryValidateObject(this, new ValidationContext(this), results, validateAllProperties: true);
        errors = results
            .SelectMany(r => (r.MemberNames.Any() ? r.MemberNames : new[] { "" })
                .Select(member => (member, message: r.ErrorMessage ?? "Invalid value.")))
            .GroupBy(x => x.member)
            .ToDictionary(g => g.Key, g => g.Select(x => x.message).ToArray());
        return ok;
    }

    /// <summary>Copies validated input onto an entity (new or existing).</summary>
    public void ApplyTo(Match match)
    {
        match.MatchDate = MatchDate!.Value;
        match.Opponent = Opponent!.Trim();
        match.Score = Score!.Trim();
        match.Surface = string.IsNullOrWhiteSpace(Surface) ? null : Surface.Trim();
        match.Notes = string.IsNullOrWhiteSpace(Notes) ? null : Notes.Trim();
    }
}
