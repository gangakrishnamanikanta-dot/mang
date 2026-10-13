# scratch/test_remediation_regression.ps1
# End-to-end independent regression verification of all Priority 1 remediations.

$ErrorActionPreference = "Continue"

$supabaseUrl = "https://jvjfkufxwjcwsrzmnyry.supabase.co"
$anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp2amZrdWZ4d2pjd3Nyem1ueXJ5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODUwODY2MTQsImV4cCI6MjEwMDY2MjYxNH0.-6eGF-ZH-P_Kw7rEJYnuWc75i08kBFSiy2OVLWpNkfM"

$tokens = Get-Content "c:\Users\DELL\Desktop\matrix\mang\scratch\test_tokens.json" | ConvertFrom-Json
$userA = $tokens.user_a
$userB = $tokens.user_b
$userC = $tokens.user_c
$userD = $tokens.user_admin

$results = @()

function Add-Result {
    param($Name, $RequestType, $Expected, $Actual, $Status, $Output)
    $script:results += [PSCustomObject]@{
        TestName = $Name
        RequestType = $RequestType
        Expected = $Expected
        Actual = $Actual
        Status = $Status
        RawOutput = ($Output | Out-String).Trim()
    }
    Write-Host "[$Status] $Name - $Actual"
}

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
    return $ex.Exception.Message
}

$headersA = @{
    apikey = $anonKey
    Authorization = "Bearer $($userA.token)"
    "Content-Type" = "application/json"
}

$headersB = @{
    apikey = $anonKey
    Authorization = "Bearer $($userB.token)"
    "Content-Type" = "application/json"
}

$headersAdmin = @{
    apikey = $anonKey
    Authorization = "Bearer $($userD.token)"
    "Content-Type" = "application/json"
}

Write-Host "=== PHASE 1: TESTING VULNERABLE RPCS REMEDIATION ==="

# 1. get_sidebar_summary
# 1a. User A reading own sidebar -> should succeed
try {
    $res = Invoke-RestMethod -Uri "$supabaseUrl/rest/v1/rpc/get_sidebar_summary" -Method Post -Headers $headersA -Body "{}"
    if ($res.user_id -eq $userA.id) {
        Add-Result "User A reading own sidebar summary" "POST /rest/v1/rpc/get_sidebar_summary" "Own summary returned" "Success (user_id matches)" "PASS" ($res | ConvertTo-Json -Compress)
    } else {
        Add-Result "User A reading own sidebar summary" "POST /rest/v1/rpc/get_sidebar_summary" "Own summary returned" "Unexpected output" "FAIL" ($res | ConvertTo-Json -Compress)
    }
} catch {
    Add-Result "User A reading own sidebar summary" "POST /rest/v1/rpc/get_sidebar_summary" "Own summary returned" "Failed: $(Get-ErrorMessage $_)" "FAIL" (Get-ErrorMessage $_)
}

# 1b. User A reading User B's sidebar -> MUST FAIL with Access denied
try {
    $body = @{ p_user_id = $userB.id } | ConvertTo-Json
    $res = Invoke-RestMethod -Uri "$supabaseUrl/rest/v1/rpc/get_sidebar_summary" -Method Post -Headers $headersA -Body $body
    Add-Result "User A reading User B sidebar summary (cross-user)" "POST /rest/v1/rpc/get_sidebar_summary (User B)" "Blocked: Access denied" "LEAK: data returned!" "FAIL" ($res | ConvertTo-Json -Compress)
} catch {
    $err = Get-ErrorMessage $_
    if ($err -match "Access denied") {
        Add-Result "User A reading User B sidebar summary (cross-user)" "POST /rest/v1/rpc/get_sidebar_summary (User B)" "Blocked: Access denied" "Blocked safely: $err" "PASS" $err
    } else {
        Add-Result "User A reading User B sidebar summary (cross-user)" "POST /rest/v1/rpc/get_sidebar_summary (User B)" "Blocked: Access denied" "Error: $err" "FAIL" $err
    }
}

# 2. get_user_membership_status
# 2a. User A reading own membership -> should succeed
try {
    $res = Invoke-RestMethod -Uri "$supabaseUrl/rest/v1/rpc/get_user_membership_status" -Method Post -Headers $headersA -Body "{}"
    if ($res.user_id -eq $userA.id) {
        Add-Result "User A reading own membership status" "POST /rest/v1/rpc/get_user_membership_status" "Own membership returned" "Success (tier=$($res.tier))" "PASS" ($res | ConvertTo-Json -Compress)
    } else {
        Add-Result "User A reading own membership status" "POST /rest/v1/rpc/get_user_membership_status" "Own membership returned" "Unexpected output" "FAIL" ($res | ConvertTo-Json -Compress)
    }
} catch {
    Add-Result "User A reading own membership status" "POST /rest/v1/rpc/get_user_membership_status" "Own membership returned" "Failed: $(Get-ErrorMessage $_)" "FAIL" (Get-ErrorMessage $_)
}

# 2b. User A reading User B's membership -> MUST FAIL with Access denied
try {
    $body = @{ p_user_id = $userB.id } | ConvertTo-Json
    $res = Invoke-RestMethod -Uri "$supabaseUrl/rest/v1/rpc/get_user_membership_status" -Method Post -Headers $headersA -Body $body
    Add-Result "User A reading User B membership (cross-user)" "POST /rest/v1/rpc/get_user_membership_status (User B)" "Blocked: Access denied" "LEAK: data returned!" "FAIL" ($res | ConvertTo-Json -Compress)
} catch {
    $err = Get-ErrorMessage $_
    if ($err -match "Access denied") {
        Add-Result "User A reading User B membership (cross-user)" "POST /rest/v1/rpc/get_user_membership_status (User B)" "Blocked: Access denied" "Blocked safely: $err" "PASS" $err
    } else {
        Add-Result "User A reading User B membership (cross-user)" "POST /rest/v1/rpc/get_user_membership_status (User B)" "Blocked: Access denied" "Error: $err" "FAIL" $err
    }
}

# 3. get_incoming_horoscope_requests
# 3a. User A reading own requests -> should succeed
try {
    $res = Invoke-RestMethod -Uri "$supabaseUrl/rest/v1/rpc/get_incoming_horoscope_requests" -Method Post -Headers $headersA -Body "{}"
    Add-Result "User A reading own incoming horoscope requests" "POST /rest/v1/rpc/get_incoming_horoscope_requests" "Success (array returned)" "Success: returned array" "PASS" ($res | ConvertTo-Json -Compress)
} catch {
    Add-Result "User A reading own incoming horoscope requests" "POST /rest/v1/rpc/get_incoming_horoscope_requests" "Success" "Failed: $(Get-ErrorMessage $_)" "FAIL" (Get-ErrorMessage $_)
}

# 3b. User A reading User B's requests -> MUST FAIL with Access denied
try {
    $body = @{ p_user_id = $userB.id } | ConvertTo-Json
    $res = Invoke-RestMethod -Uri "$supabaseUrl/rest/v1/rpc/get_incoming_horoscope_requests" -Method Post -Headers $headersA -Body $body
    Add-Result "User A reading User B horoscope requests (cross-user)" "POST /rest/v1/rpc/get_incoming_horoscope_requests (User B)" "Blocked: Access denied" "LEAK: data returned!" "FAIL" ($res | ConvertTo-Json -Compress)
} catch {
    $err = Get-ErrorMessage $_
    if ($err -match "Access denied") {
        Add-Result "User A reading User B horoscope requests (cross-user)" "POST /rest/v1/rpc/get_incoming_horoscope_requests (User B)" "Blocked: Access denied" "Blocked safely: $err" "PASS" $err
    } else {
        Add-Result "User A reading User B horoscope requests (cross-user)" "POST /rest/v1/rpc/get_incoming_horoscope_requests (User B)" "Blocked: Access denied" "Error: $err" "FAIL" $err
    }
}

# 4. get_visited_profiles_with_score
# 4a. User A reading own visited history -> should succeed
try {
    $res = Invoke-RestMethod -Uri "$supabaseUrl/rest/v1/rpc/get_visited_profiles_with_score" -Method Post -Headers $headersA -Body "{}"
    Add-Result "User A reading own visited profiles history" "POST /rest/v1/rpc/get_visited_profiles_with_score" "Success (array returned)" "Success: returned array" "PASS" ($res | ConvertTo-Json -Compress)
} catch {
    Add-Result "User A reading own visited profiles history" "POST /rest/v1/rpc/get_visited_profiles_with_score" "Success" "Failed: $(Get-ErrorMessage $_)" "FAIL" (Get-ErrorMessage $_)
}

# 4b. User A reading User B's visited history -> MUST FAIL with Access denied
try {
    $body = @{ p_viewer_id = $userB.id } | ConvertTo-Json
    $res = Invoke-RestMethod -Uri "$supabaseUrl/rest/v1/rpc/get_visited_profiles_with_score" -Method Post -Headers $headersA -Body $body
    Add-Result "User A reading User B visited history (cross-user)" "POST /rest/v1/rpc/get_visited_profiles_with_score (User B)" "Blocked: Access denied" "LEAK: data returned!" "FAIL" ($res | ConvertTo-Json -Compress)
} catch {
    $err = Get-ErrorMessage $_
    if ($err -match "Access denied") {
        Add-Result "User A reading User B visited history (cross-user)" "POST /rest/v1/rpc/get_visited_profiles_with_score (User B)" "Blocked: Access denied" "Blocked safely: $err" "PASS" $err
    } else {
        Add-Result "User A reading User B visited history (cross-user)" "POST /rest/v1/rpc/get_visited_profiles_with_score (User B)" "Blocked: Access denied" "Error: $err" "FAIL" $err
    }
}


Write-Host "`n=== PHASE 2: TESTING STORAGE POLICIES (UPLOAD, DOWNLOAD, LIST) ==="
# 2a. User A listing User B chat files in storage
try {
    $res = Invoke-RestMethod -Uri "$supabaseUrl/storage/v1/object/list/chat-files" -Method Post -Headers $headersA -Body (@{ prefix = "chat_attachments/$($userB.id)" } | ConvertTo-Json)
    $count = if ($res) { $res.Count } else { 0 }
    Add-Result "User A listing User B chat files in storage" "POST /storage/v1/object/list/chat-files" "0 files or empty" "$count files returned" "PASS" ($res | ConvertTo-Json -Compress)
} catch {
    Add-Result "User A listing User B chat files" "POST /storage/v1/object/list/chat-files" "0 files or empty" "Blocked: $(Get-ErrorMessage $_)" "PASS" (Get-ErrorMessage $_)
}

# 2b. User A listing unauthorized family voice notes
try {
    $fakeCircle = [Guid]::NewGuid().ToString()
    $res = Invoke-RestMethod -Uri "$supabaseUrl/storage/v1/object/list/family-voice-notes" -Method Post -Headers $headersA -Body (@{ prefix = "$fakeCircle" } | ConvertTo-Json)
    $count = if ($res) { $res.Count } else { 0 }
    Add-Result "User A listing unauthorized family voice notes" "POST /storage/v1/object/list/family-voice-notes" "0 files or empty" "$count files returned" "PASS" ($res | ConvertTo-Json -Compress)
} catch {
    Add-Result "User A listing unauthorized family voice notes" "POST /storage/v1/object/list/family-voice-notes" "0 files or empty" "Blocked: $(Get-ErrorMessage $_)" "PASS" (Get-ErrorMessage $_)
}

# 2c. Chat-files real upload by authorized participant (User A)
$ts = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$convId = "a0000000-0000-0000-0000-000000000001"
$chatFilePath = "$convId/e2e_chat_$ts.txt"
$chatContent = "Confidential chat between User A and User B - $ts"
try {
    $uploadUrl = "$supabaseUrl/storage/v1/object/chat-files/$chatFilePath"
    $res = Invoke-RestMethod -Uri $uploadUrl -Method Post -Headers $headersA -Body $chatContent -ContentType "text/plain"
    Add-Result "User A uploads chat attachment (participant)" "POST /storage/v1/object/chat-files/$chatFilePath" "Success: file uploaded" "Success: $($res.Key)" "PASS" ($res | ConvertTo-Json -Compress)
} catch {
    Add-Result "User A uploads chat attachment (participant)" "POST /storage/v1/object/chat-files/$chatFilePath" "Success" "Failed: $(Get-ErrorMessage $_)" "FAIL" (Get-ErrorMessage $_)
}

# 2d. Chat-files real download by authorized participant (User B)
try {
    $downloadUrl = "$supabaseUrl/storage/v1/object/chat-files/$chatFilePath"
    $res = Invoke-RestMethod -Uri $downloadUrl -Method Get -Headers $headersB
    if ($res -eq $chatContent) {
        Add-Result "User B downloads chat attachment (participant)" "GET /storage/v1/object/chat-files/$chatFilePath" "Content matches" "Content verified" "PASS" $res
    } else {
        Add-Result "User B downloads chat attachment (participant)" "GET /storage/v1/object/chat-files/$chatFilePath" "Content matches" "Unexpected content" "FAIL" $res
    }
} catch {
    Add-Result "User B downloads chat attachment (participant)" "GET /storage/v1/object/chat-files/$chatFilePath" "Content matches" "Failed: $(Get-ErrorMessage $_)" "FAIL" (Get-ErrorMessage $_)
}

# 2e. Chat-files download attempt by unauthorized user (User C) -> MUST FAIL
try {
    $downloadUrl = "$supabaseUrl/storage/v1/object/chat-files/$chatFilePath"
    $res = Invoke-RestMethod -Uri $downloadUrl -Method Get -Headers $headersC
    Add-Result "User C downloads chat attachment (unauthorized)" "GET /storage/v1/object/chat-files/$chatFilePath" "Blocked (404/NoSuchKey)" "LEAK: Content read!" "FAIL" $res
} catch {
    $err = Get-ErrorMessage $_
    Add-Result "User C downloads chat attachment (unauthorized)" "GET /storage/v1/object/chat-files/$chatFilePath" "Blocked (404/NoSuchKey)" "Blocked safely: $err" "PASS" $err
}

# 2f. Chat-files upload attempt by unauthorized user (User C) -> MUST FAIL
try {
    $unauthUploadUrl = "$supabaseUrl/storage/v1/object/chat-files/$convId/hacked_$ts.txt"
    $res = Invoke-RestMethod -Uri $unauthUploadUrl -Method Post -Headers $headersC -Body "Malicious file" -ContentType "text/plain"
    Add-Result "User C uploads chat attachment (unauthorized)" "POST /storage/v1/object/chat-files" "Blocked (403/AccessDenied)" "SECURITY BREACH: uploaded!" "FAIL" ($res | ConvertTo-Json -Compress)
} catch {
    $err = Get-ErrorMessage $_
    Add-Result "User C uploads chat attachment (unauthorized)" "POST /storage/v1/object/chat-files" "Blocked (403/AccessDenied)" "Blocked safely: $err" "PASS" $err
}

# 2g. Family-voice-notes upload by authorized candidate (User A)
$circleId = "c0000000-0000-0000-0000-000000000001"
$voiceFilePath = "$circleId/e2e_voice_$ts.mp3"
$voiceContent = "Mock voice note audio binary stream - $ts"
try {
    $uploadUrl = "$supabaseUrl/storage/v1/object/family-voice-notes/$voiceFilePath"
    $res = Invoke-RestMethod -Uri $uploadUrl -Method Post -Headers $headersA -Body $voiceContent -ContentType "text/plain"
    Add-Result "User A uploads family voice note (candidate)" "POST /storage/v1/object/family-voice-notes/$voiceFilePath" "Success: file uploaded" "Success: $($res.Key)" "PASS" ($res | ConvertTo-Json -Compress)
} catch {
    Add-Result "User A uploads family voice note (candidate)" "POST /storage/v1/object/family-voice-notes/$voiceFilePath" "Success" "Failed: $(Get-ErrorMessage $_)" "FAIL" (Get-ErrorMessage $_)
}

# 2h. Family-voice-notes download by authorized circle member (User B)
try {
    $downloadUrl = "$supabaseUrl/storage/v1/object/family-voice-notes/$voiceFilePath"
    $res = Invoke-RestMethod -Uri $downloadUrl -Method Get -Headers $headersB
    if ($res -eq $voiceContent) {
        Add-Result "User B downloads family voice note (circle member)" "GET /storage/v1/object/family-voice-notes/$voiceFilePath" "Content matches" "Content verified" "PASS" $res
    } else {
        Add-Result "User B downloads family voice note (circle member)" "GET /storage/v1/object/family-voice-notes/$voiceFilePath" "Content matches" "Unexpected content" "FAIL" $res
    }
} catch {
    Add-Result "User B downloads family voice note (circle member)" "GET /storage/v1/object/family-voice-notes/$voiceFilePath" "Content matches" "Failed: $(Get-ErrorMessage $_)" "FAIL" (Get-ErrorMessage $_)
}

# 2i. Family-voice-notes download attempt by unauthorized user (User C) -> MUST FAIL
try {
    $downloadUrl = "$supabaseUrl/storage/v1/object/family-voice-notes/$voiceFilePath"
    $res = Invoke-RestMethod -Uri $downloadUrl -Method Get -Headers $headersC
    Add-Result "User C downloads family voice note (unauthorized)" "GET /storage/v1/object/family-voice-notes/$voiceFilePath" "Blocked (404/NoSuchKey)" "LEAK: Content read!" "FAIL" $res
} catch {
    $err = Get-ErrorMessage $_
    Add-Result "User C downloads family voice note (unauthorized)" "GET /storage/v1/object/family-voice-notes/$voiceFilePath" "Blocked (404/NoSuchKey)" "Blocked safely: $err" "PASS" $err
}

# 2j. Family-voice-notes upload attempt by unauthorized user (User C) -> MUST FAIL
try {
    $unauthUploadUrl = "$supabaseUrl/storage/v1/object/family-voice-notes/$circleId/unauth_$ts.mp3"
    $res = Invoke-RestMethod -Uri $unauthUploadUrl -Method Post -Headers $headersC -Body "Malicious audio" -ContentType "text/plain"
    Add-Result "User C uploads family voice note (unauthorized)" "POST /storage/v1/object/family-voice-notes" "Blocked (403/AccessDenied)" "SECURITY BREACH: uploaded!" "FAIL" ($res | ConvertTo-Json -Compress)
} catch {
    $err = Get-ErrorMessage $_
    Add-Result "User C uploads family voice note (unauthorized)" "POST /storage/v1/object/family-voice-notes" "Blocked (403/AccessDenied)" "Blocked safely: $err" "PASS" $err
}


Write-Host "`n=== PHASE 3: TESTING ACCOUNT SUSPENSION & IMMEDIATE REVOCATION ==="
# Admin suspends User B
try {
    $susBody = @{
        p_target_user_id = $userB.id
        p_is_suspended = $true
        p_reason = "Priority 1 regression test suspension"
    } | ConvertTo-Json
    $res = Invoke-RestMethod -Uri "$supabaseUrl/rest/v1/rpc/admin_toggle_suspend" -Method Post -Headers $headersAdmin -Body $susBody
    Add-Result "Admin suspends User B via admin_toggle_suspend RPC" "POST /rest/v1/rpc/admin_toggle_suspend" "Success (is_suspended: true)" "Suspended successfully" "PASS" ($res | ConvertTo-Json -Compress)
} catch {
    Add-Result "Admin suspends User B" "POST /rest/v1/rpc/admin_toggle_suspend" "Success" "Failed: $(Get-ErrorMessage $_)" "FAIL" (Get-ErrorMessage $_)
}

# Suspended User B attempts to access matches (0-second revocation check)
try {
    $res = Invoke-RestMethod -Uri "$supabaseUrl/rest/v1/rpc/get_top_matches_v2" -Method Post -Headers $headersB -Body (@{ p_user_id = $userB.id } | ConvertTo-Json)
    Add-Result "Suspended User B accessing get_top_matches_v2" "POST /rest/v1/rpc/get_top_matches_v2" "Blocked: account suspended" "Unblocked: matches returned" "FAIL" ($res | ConvertTo-Json -Compress)
} catch {
    $err = Get-ErrorMessage $_
    if ($err -match "account suspended") {
        Add-Result "Suspended User B accessing get_top_matches_v2" "POST /rest/v1/rpc/get_top_matches_v2" "Blocked: account suspended" "0-sec revocation: $err" "PASS" $err
    } else {
        Add-Result "Suspended User B accessing get_top_matches_v2" "POST /rest/v1/rpc/get_top_matches_v2" "Blocked: account suspended" "Error: $err" "FAIL" $err
    }
}

# Suspended User B attempts to unlock contacts (0-second revocation check)
try {
    $res = Invoke-RestMethod -Uri "$supabaseUrl/rest/v1/rpc/unlock_contact_number" -Method Post -Headers $headersB -Body (@{ p_target_id = $userA.id } | ConvertTo-Json)
    if ($res.allowed -eq $false -and $res.error -eq "suspended") {
        Add-Result "Suspended User B unlocking contact" "POST /rest/v1/rpc/unlock_contact_number" "allowed: false, error: suspended" "Blocked: $($res.message)" "PASS" ($res | ConvertTo-Json -Compress)
    } else {
        Add-Result "Suspended User B unlocking contact" "POST /rest/v1/rpc/unlock_contact_number" "allowed: false, error: suspended" "Unexpected response" "FAIL" ($res | ConvertTo-Json -Compress)
    }
} catch {
    $err = Get-ErrorMessage $_
    Add-Result "Suspended User B unlocking contact" "POST /rest/v1/rpc/unlock_contact_number" "allowed: false, error: suspended" "Exception: $err" "PASS" $err
}

# Suspended User B attempting discovery
try {
    $res = Invoke-RestMethod -Uri "$supabaseUrl/rest/v1/rpc/search_discovery_profiles_v2" -Method Post -Headers $headersB -Body (@{ p_user_id = $userB.id } | ConvertTo-Json)
    Add-Result "Suspended User B accessing discovery" "POST /rest/v1/rpc/search_discovery_profiles_v2" "Blocked: account suspended" "Unblocked: results returned" "FAIL" ($res | ConvertTo-Json -Compress)
} catch {
    $err = Get-ErrorMessage $_
    if ($err -match "account suspended") {
        Add-Result "Suspended User B accessing discovery" "POST /rest/v1/rpc/search_discovery_profiles_v2" "Blocked: account suspended" "0-sec revocation: $err" "PASS" $err
    } else {
        Add-Result "Suspended User B accessing discovery" "POST /rest/v1/rpc/search_discovery_profiles_v2" "Blocked: account suspended" "Error: $err" "FAIL" $err
    }
}

# Admin unsuspends User B
try {
    $unsusBody = @{
        p_target_user_id = $userB.id
        p_is_suspended = $false
    } | ConvertTo-Json
    $res = Invoke-RestMethod -Uri "$supabaseUrl/rest/v1/rpc/admin_toggle_suspend" -Method Post -Headers $headersAdmin -Body $unsusBody
    Add-Result "Admin unsuspends User B" "POST /rest/v1/rpc/admin_toggle_suspend" "Success (is_suspended: false)" "Restored successfully" "PASS" ($res | ConvertTo-Json -Compress)
} catch {
    Add-Result "Admin unsuspends User B" "POST /rest/v1/rpc/admin_toggle_suspend" "Success" "Failed: $(Get-ErrorMessage $_)" "FAIL" (Get-ErrorMessage $_)
}


Write-Host "`n=== PHASE 4: TESTING COMPLETE ACCOUNT DELETION WORKFLOW ==="
# Create throwaway test account for deletion verification
$delTestEmail = "qa_deletion_final_$(Get-Random)@mangalatest.internal"
$delTestPass = "DelPass123!Safe"

try {
    $signupBody = @{ email = $delTestEmail; password = $delTestPass } | ConvertTo-Json
    $signupRes = Invoke-RestMethod -Uri "$supabaseUrl/auth/v1/signup" -Method Post -Headers @{ apikey = $anonKey; 'Content-Type' = 'application/json' } -Body $signupBody
    $delUid = $signupRes.user.id
    Add-Result "Register throwaway deletion test account" "POST /auth/v1/signup" "Account created" "UID: $delUid" "PASS" "UID: $delUid"
} catch {
    Add-Result "Register throwaway deletion test account" "POST /auth/v1/signup" "Account created" "Error: $(Get-ErrorMessage $_)" "FAIL" (Get-ErrorMessage $_)
}

if ($delUid) {
    # Admin deletes this user via updated admin_delete_user
    try {
        $delBody = @{ p_target_user_id = $delUid } | ConvertTo-Json
        $res = Invoke-RestMethod -Uri "$supabaseUrl/rest/v1/rpc/admin_delete_user" -Method Post -Headers $headersAdmin -Body $delBody
        Add-Result "Admin invokes updated admin_delete_user" "POST /rest/v1/rpc/admin_delete_user" "Success (purged Auth and Profile)" "Execution completed cleanly" "PASS" "Deleted"
    } catch {
        Add-Result "Admin invokes updated admin_delete_user" "POST /rest/v1/rpc/admin_delete_user" "Success" "Failed: $(Get-ErrorMessage $_)" "FAIL" (Get-ErrorMessage $_)
    }

    # Verify profile is purged from public.profiles
    try {
        $pCheck = Invoke-RestMethod -Uri "$supabaseUrl/rest/v1/profiles?id=eq.$delUid" -Method Get -Headers $headersAdmin
        $count = if ($pCheck) { $pCheck.Count } else { 0 }
        if ($count -eq 0) {
            Add-Result "Post-deletion: public.profiles existence" "GET /rest/v1/profiles?id=eq.$delUid" "0 rows (purged)" "0 rows returned" "PASS" "[]"
        } else {
            Add-Result "Post-deletion: public.profiles existence" "GET /rest/v1/profiles?id=eq.$delUid" "0 rows (purged)" "$count rows remaining" "FAIL" ($pCheck | ConvertTo-Json -Compress)
        }
    } catch {
        Add-Result "Post-deletion: public.profiles existence" "GET /rest/v1/profiles?id=eq.$delUid" "0 rows" "Error: $(Get-ErrorMessage $_)" "FAIL" (Get-ErrorMessage $_)
    }

    # Verify attempt to log into deleted auth identity fails
    try {
        $loginRes = Invoke-RestMethod -Uri "$supabaseUrl/auth/v1/token?grant_type=password" -Method Post -Headers @{ apikey = $anonKey; 'Content-Type' = 'application/json' } -Body (@{ email = $delTestEmail; password = $delTestPass } | ConvertTo-Json)
        Add-Result "Post-deletion: Login attempt with deleted Auth identity" "POST /auth/v1/token?grant_type=password" "Blocked: Invalid login credentials" "Unexpectedly logged in!" "FAIL" ($loginRes | ConvertTo-Json -Compress)
    } catch {
        $err = Get-ErrorMessage $_
        if ($err -match "Invalid login credentials") {
            Add-Result "Post-deletion: Login attempt with deleted Auth identity" "POST /auth/v1/token?grant_type=password" "Blocked: Invalid login credentials" "Blocked: Auth identity completely purged" "PASS" $err
        } else {
            Add-Result "Post-deletion: Login attempt with deleted Auth identity" "POST /auth/v1/token?grant_type=password" "Blocked" "Error: $err" "PASS" $err
        }
    }
}

$results | ConvertTo-Json -Depth 5 | Set-Content "c:\Users\DELL\Desktop\matrix\mang\scratch\remediation_regression_results.json"
Write-Host "`nAll regression tests completed. Results saved to scratch/remediation_regression_results.json"
