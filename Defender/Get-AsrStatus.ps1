<#
    Outputs Attack Surface Reduction rule status
#>

function Get-AttackSurfaceReductionRuleStatus {

    function Get-AsrStatus ($Value) {
        switch ($Value) {
            0 { "Disabled" }
            1 { "Enabled" }
            2 { "Audit" }
            default { "Not configured" }
        }
    }

    $Prefs = Get-MpPreference
    if ($null -eq $Prefs.AttackSurfaceReductionRules_Ids) {
        Write-Host "ASR rules not configured."
    }
    else {
        for ($i = 0; $i -le ($Prefs.AttackSurfaceReductionRules_Ids.Count - 1); $i++) {
            [PSCustomObject]@{
                RuleId = $Prefs.AttackSurfaceReductionRules_Ids[$i]
                Status = Get-AsrStatus -Value $Prefs.AttackSurfaceReductionRules_Actions[$i]
            }
        }
    }
}
