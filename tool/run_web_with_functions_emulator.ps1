param(
  [string]$ProjectId = 'equb-1e38b',
  [string]$DepositKey = '',
  [string]$WithdrawalKey = ''
)

$root = 'C:\work\Equb'
if (-not (Test-Path $root)) {
  $root = (Get-Location).Path
}

# Prefer environment variables to avoid leaking secrets into shell history.
if ($DepositKey.Trim().Length -eq 0 -and $env:FENANPAY_DEPOSIT_KEY) {
  $DepositKey = $env:FENANPAY_DEPOSIT_KEY
}
if ($WithdrawalKey.Trim().Length -eq 0 -and $env:FENANPAY_WITHDRAWAL_KEY) {
  $WithdrawalKey = $env:FENANPAY_WITHDRAWAL_KEY
}

# If still missing, prompt interactively without echoing input.
function Read-SecretPlaintext([string]$Prompt) {
  $secure = Read-Host -AsSecureString -Prompt $Prompt
  if ($null -eq $secure) { return '' }
  $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
  try {
    return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
  } finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
  }
}

if ($DepositKey.Trim().Length -eq 0) {
  $DepositKey = Read-SecretPlaintext 'Enter FENANPAY_DEPOSIT_KEY (press Enter to skip)'
}
if ($WithdrawalKey.Trim().Length -eq 0) {
  $WithdrawalKey = Read-SecretPlaintext 'Enter FENANPAY_WITHDRAWAL_KEY (press Enter to skip)'
}

# Start Functions emulator in a separate window (so it stays running).
$emuCmd = "Set-Location -Path `"$root`"; firebase emulators:start --only functions --project $ProjectId"
Start-Process -FilePath "powershell.exe" -ArgumentList "-NoExit", "-Command", $emuCmd | Out-Null

# Run Flutter web app pointing at the Functions emulator.
$flutterArgs = @(
  'run',
  '-d', 'chrome',
  '-t', 'lib/main.dart',
  '--dart-define=USE_FIREBASE_EMULATORS=true'
)

if ($DepositKey.Trim().Length -gt 0) {
  $flutterArgs += "--dart-define=FENANPAY_DEPOSIT_KEY=$DepositKey"
}

if ($WithdrawalKey.Trim().Length -gt 0) {
  $flutterArgs += "--dart-define=FENANPAY_WITHDRAWAL_KEY=$WithdrawalKey"
}

Set-Location -Path $root
flutter @flutterArgs
