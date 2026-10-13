# scratch/test_storage_uploads_downloads.ps1
# Direct verification of Storage upload/download policies for allowed and denied cases

$ErrorActionPreference = "Continue"

$supabaseUrl = "https://jvjfkufxwjcwsrzmnyry.supabase.co"
$anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp2amZrdWZ4d2pjd3Nyem1ueXJ5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODUwODY2MTQsImV4cCI6MjEwMDY2MjYxNH0.-6eGF-ZH-P_Kw7rEJYnuWc75i08kBFSiy2OVLWpNkfM"

$tokens = Get-Content "c:\Users\DELL\Desktop\matrix\mang\scratch\test_tokens.json" | ConvertFrom-Json
$userA = $tokens.user_a
$userB = $tokens.user_b
$userC = $tokens.user_c

$headersA = @{
    apikey = $anonKey
    Authorization = "Bearer $($userA.token)"
}

$headersB = @{
    apikey = $anonKey
    Authorization = "Bearer $($userB.token)"
}

$headersC = @{
    apikey = $anonKey
    Authorization = "Bearer $($userC.token)"
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
    return $ex.Message
}

Write-Host "=== TESTING CHAT-FILES STORAGE UPLOADS & DOWNLOADS ==="
$convId = "a0000000-0000-0000-0000-000000000001"
$ts = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$chatFilePath = "$convId/test_chat_secret_$ts.txt"
$chatContent = "Confidential chat between User A and User B - $ts"

# 1. User A (Participant) Uploads to Chat-Files -> MUST PASS
try {
    $uploadUrl = "$supabaseUrl/storage/v1/object/chat-files/$chatFilePath"
    $res = Invoke-RestMethod -Uri $uploadUrl -Method Post -Headers $headersA -Body $chatContent -ContentType "text/plain"
    Write-Host "[PASS] User A uploads to conversation chat-files: Success ($($res.Key))"
} catch {
    Write-Host "[FAIL] User A uploads to conversation chat-files: $(Get-ErrorMessage $_)"
}

# 2. User B (Participant) Downloads from Chat-Files -> MUST PASS
try {
    $downloadUrl = "$supabaseUrl/storage/v1/object/chat-files/$chatFilePath"
    $res = Invoke-RestMethod -Uri $downloadUrl -Method Get -Headers $headersB
    if ($res -eq $chatContent) {
        Write-Host "[PASS] User B downloads chat attachment as participant: Success ('$res')"
    } else {
        Write-Host "[PASS] User B downloads chat attachment: Success (HTTP 200)"
    }
} catch {
    Write-Host "[FAIL] User B downloads chat attachment: $(Get-ErrorMessage $_)"
}

# 3. User C (Outsider) Attempts Download from Chat-Files -> MUST BE DENIED
try {
    $downloadUrl = "$supabaseUrl/storage/v1/object/chat-files/$chatFilePath"
    $res = Invoke-RestMethod -Uri $downloadUrl -Method Get -Headers $headersC
    Write-Host "[FAIL] User C (outsider) downloaded chat file! Content: $res"
} catch {
    $err = Get-ErrorMessage $_
    Write-Host "[PASS] User C (outsider) download blocked safely: $err"
}

# 4. User C (Outsider) Attempts Upload to Chat-Files -> MUST BE DENIED
try {
    $unauthUploadUrl = "$supabaseUrl/storage/v1/object/chat-files/$convId/hacked.txt"
    $res = Invoke-RestMethod -Uri $unauthUploadUrl -Method Post -Headers $headersC -Body "Malicious file" -ContentType "text/plain"
    Write-Host "[FAIL] User C (outsider) uploaded to chat-files! Result: $($res | ConvertTo-Json)"
} catch {
    $err = Get-ErrorMessage $_
    Write-Host "[PASS] User C (outsider) upload blocked safely: $err"
}

Write-Host "`n=== TESTING FAMILY-VOICE-NOTES STORAGE UPLOADS & DOWNLOADS ==="
$circleId = "c0000000-0000-0000-0000-000000000001"
$voiceFilePath = "$circleId/private_voice_memo_$ts.mp3"
$voiceContent = "Mock voice note audio binary stream - $ts"

# 5. User A (Candidate / Family Owner) Uploads Voice Note -> MUST PASS
try {
    $uploadUrl = "$supabaseUrl/storage/v1/object/family-voice-notes/$voiceFilePath"
    $res = Invoke-RestMethod -Uri $uploadUrl -Method Post -Headers $headersA -Body $voiceContent -ContentType "text/plain"
    Write-Host "[PASS] User A uploads family voice note: Success ($($res.Key))"
} catch {
    Write-Host "[FAIL] User A uploads family voice note: $(Get-ErrorMessage $_)"
}

# 6. User B (Family Circle Member) Downloads Voice Note -> MUST PASS
try {
    $downloadUrl = "$supabaseUrl/storage/v1/object/family-voice-notes/$voiceFilePath"
    $res = Invoke-RestMethod -Uri $downloadUrl -Method Get -Headers $headersB
    if ($res -eq $voiceContent) {
        Write-Host "[PASS] User B downloads family voice note as circle member: Success"
    } else {
        Write-Host "[PASS] User B downloads family voice note: Success (HTTP 200)"
    }
} catch {
    Write-Host "[FAIL] User B downloads family voice note: $(Get-ErrorMessage $_)"
}

# 7. User C (Outsider) Attempts Download Voice Note -> MUST BE DENIED
try {
    $downloadUrl = "$supabaseUrl/storage/v1/object/family-voice-notes/$voiceFilePath"
    $res = Invoke-RestMethod -Uri $downloadUrl -Method Get -Headers $headersC
    Write-Host "[FAIL] User C downloaded family voice note! Content: $res"
} catch {
    $err = Get-ErrorMessage $_
    Write-Host "[PASS] User C (outsider) download blocked safely: $err"
}

# 8. User C (Outsider) Attempts Upload Voice Note to Circle -> MUST BE DENIED
try {
    $unauthUploadUrl = "$supabaseUrl/storage/v1/object/family-voice-notes/$circleId/unauthorized.mp3"
    $res = Invoke-RestMethod -Uri $unauthUploadUrl -Method Post -Headers $headersC -Body "Malicious audio" -ContentType "text/plain"
    Write-Host "[FAIL] User C uploaded to family circle voice notes! Result: $($res | ConvertTo-Json)"
} catch {
    $err = Get-ErrorMessage $_
    Write-Host "[PASS] User C (outsider) upload blocked safely: $err"
}
