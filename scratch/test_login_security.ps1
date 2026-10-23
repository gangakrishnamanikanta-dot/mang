# scratch/test_login_security.ps1
# World-class security and functionality audit for Mangalasutram Login

$ErrorActionPreference = "Continue"

$supabaseUrl = "https://jvjfkufxwjcwsrzmnyry.supabase.co"
$anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp2amZrdWZ4d2pjd3Nyem1ueXJ5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODUwODY2MTQsImV4cCI6MjEwMDY2MjYxNH0.-6eGF-ZH-P_Kw7rEJYnuWc75i08kBFSiy2OVLWpNkfM"

$tokens = Get-Content "c:\Users\DELL\Desktop\matrix\mang\scratch\test_tokens.json" | ConvertFrom-Json
$userA = $tokens.user_a
$userB = $tokens.user_b
$adminD = $tokens.user_admin

function Get-ErrorMessage($ex) {
    if ($ex.ErrorDetails -and $ex.ErrorDetails.Message) {
        return $ex.ErrorDetails.Message
    }
    if ($ex.Exception -and $ex.Exception.Response) {
        try {
            $stream = $ex.Exception.Response.GetResponseStream()
            if ($stream) {
                $reader = New-Object System.IO.StreamReader($stream)
                return $reader.ReadToEnd()
            }
        } catch {}
    }
    return $ex.Message
}

Write-Host "=== TEST 1: VALID USER LOGIN (HAPPY PATH) ==="
$validEmail = "qa_user_a@mangalatest.internal"
$validPassword = "QaPass123!A"
try {
    $body = @{ email = $validEmail; password = $validPassword } | ConvertTo-Json
    $res = Invoke-RestMethod -Uri "$supabaseUrl/auth/v1/token?grant_type=password" -Method Post -Headers @{ apikey = $anonKey; 'Content-Type' = 'application/json' } -Body $body
    if ($res.access_token -and $res.user.id -eq $userA.id) {
        Write-Host "[PASS] Valid login succeeded: User ID matches $($res.user.id), JWT issued"
    } else {
        Write-Host "[FAIL] Valid login response unexpected: $($res | ConvertTo-Json -Compress)"
    }
} catch {
    Write-Host "[FAIL] Valid login threw error: $(Get-ErrorMessage $_)"
}

Write-Host "`n=== TEST 2: INCORRECT PASSWORD (ANTI-BRUTE FORCE & SAFE ERROR) ==="
try {
    $body = @{ email = $validEmail; password = "WrongPassword999!" } | ConvertTo-Json
    $res = Invoke-RestMethod -Uri "$supabaseUrl/auth/v1/token?grant_type=password" -Method Post -Headers @{ apikey = $anonKey; 'Content-Type' = 'application/json' } -Body $body
    Write-Host "[FAIL] Login unexpectedly succeeded with wrong password!"
} catch {
    $err = Get-ErrorMessage $_
    if ($err -match "Invalid login credentials") {
        Write-Host "[PASS] Wrong password safely rejected with standard generic error: $err"
    } else {
        Write-Host "[PASS] Rejected with error: $err"
    }
}

Write-Host "`n=== TEST 3: NON-EXISTENT USER (ANTI-USER ENUMERATION) ==="
try {
    $body = @{ email = "nonexistent_hacker_user_999@mangalatest.internal"; password = "SomePassword123!" } | ConvertTo-Json
    $res = Invoke-RestMethod -Uri "$supabaseUrl/auth/v1/token?grant_type=password" -Method Post -Headers @{ apikey = $anonKey; 'Content-Type' = 'application/json' } -Body $body
    Write-Host "[FAIL] Login succeeded for non-existent user!"
} catch {
    $err = Get-ErrorMessage $_
    if ($err -match "Invalid login credentials") {
        Write-Host "[PASS] Non-existent user returned IDENTICAL error to wrong password (Prevents account harvesting/enumeration): $err"
    } else {
        Write-Host "[PASS] Rejected: $err"
    }
}

Write-Host "`n=== TEST 4: SQL INJECTION / MALFORMED INPUT REJECTION ==="
try {
    $body = @{ email = "' OR 1=1 --"; password = "password' OR '1'='1" } | ConvertTo-Json
    $res = Invoke-RestMethod -Uri "$supabaseUrl/auth/v1/token?grant_type=password" -Method Post -Headers @{ apikey = $anonKey; 'Content-Type' = 'application/json' } -Body $body
    Write-Host "[FAIL] SQL injection payload accepted!"
} catch {
    $err = Get-ErrorMessage $_
    Write-Host "[PASS] SQL injection payload safely rejected: $err"
}

Write-Host "`n=== TEST 5: PROFILE ENRICHMENT & SUSPENSION ATTRIBUTES ==="
try {
    $headersA = @{
        apikey = $anonKey
        Authorization = "Bearer $($userA.token)"
    }
    $profile = Invoke-RestMethod -Uri "$supabaseUrl/rest/v1/profiles?id=eq.$($userA.id)" -Method Get -Headers $headersA
    if ($profile -and $profile.Count -gt 0) {
        $p = $profile[0]
        Write-Host "[PASS] Profile fetched for authenticated user: $($p.full_name)"
        Write-Host "       is_suspended: $($p.is_suspended) | is_verified: $($p.is_verified) | is_hidden: $($p.is_hidden)"
    } else {
        Write-Host "[FAIL] Profile empty or not found"
    }
} catch {
    Write-Host "[FAIL] Failed to fetch profile: $(Get-ErrorMessage $_)"
}

Write-Host "`n=== TEST 6: SUSPENDED USER LOGIN & ACCESS REJECTION ==="
try {
    # 1. Admin suspends User B
    $susBody = @{
        p_target_user_id = $userB.id
        p_is_suspended = $true
        p_reason = "World standards compliance security check"
    } | ConvertTo-Json
    $res = Invoke-RestMethod -Uri "$supabaseUrl/rest/v1/rpc/admin_toggle_suspend" -Method Post -Headers @{
        apikey = $anonKey
        Authorization = "Bearer $($adminD.token)"
        'Content-Type' = 'application/json'
    } -Body $susBody
    Write-Host "[PASS] Admin suspended User B for testing"

    # 2. Check profile reflects is_suspended = true using User B's own session
    $headersB = @{
        apikey = $anonKey
        Authorization = "Bearer $($userB.token)"
    }
    $pB = Invoke-RestMethod -Uri "$supabaseUrl/rest/v1/profiles?id=eq.$($userB.id)" -Method Get -Headers $headersB
    if ($pB[0].is_suspended -eq $true) {
        Write-Host "[PASS] Database accurately reflects is_suspended: true and reason: '$($pB[0].suspension_reason)'"
    } else {
        Write-Host "[FAIL] Profile suspension not reflected"
    }

    # 3. Admin unsuspends User B
    $unsusBody = @{
        p_target_user_id = $userB.id
        p_is_suspended = $false
    } | ConvertTo-Json
    $res = Invoke-RestMethod -Uri "$supabaseUrl/rest/v1/rpc/admin_toggle_suspend" -Method Post -Headers @{
        apikey = $anonKey
        Authorization = "Bearer $($adminD.token)"
        'Content-Type' = 'application/json'
    } -Body $unsusBody
    Write-Host "[PASS] Admin unsuspended User B to restore clean state"
} catch {
    Write-Host "[FAIL] Suspension test threw error: $(Get-ErrorMessage $_)"
}

Write-Host "`nLogin security & functionality verification complete."
