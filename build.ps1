Function Info($msg) {
  Write-Host -ForegroundColor DarkGreen "`nINFO: $msg`n"
}

Function Error($msg) {
  Write-Host `n`n
  Write-Error $msg
  exit 1
}

Function CheckReturnCodeOfPreviousCommand($msg) {
  if(-Not $?) {
    Error "${msg}. Error code: $LastExitCode"
  }
}

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
Add-Type -AssemblyName System.IO.Compression.FileSystem

$root = Resolve-Path "$PSScriptRoot"
$buildDir = "$root/build"

Info "Find Visual Studio installation path"
$vswhereCommand = Get-Command -Name "${Env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$installationPath = & $vswhereCommand -prerelease -latest -property installationPath

Info "Open Visual Studio 2022 Developer PowerShell"
& "$installationPath\Common7\Tools\Launch-VsDevShell.ps1" -Arch amd64

Info "Remove '$buildDir' folder if it exists"
Remove-Item $buildDir -Force -Recurse -ErrorAction SilentlyContinue
New-Item $buildDir -Force -ItemType "directory" > $null

Info "Download llvm source code"
Invoke-WebRequest -Uri https://github.com/llvm/llvm-project/archive/refs/tags/llvmorg-19.1.0.zip -OutFile $buildDir/llvm.zip

Info "Extract the source code"
[System.IO.Compression.ZipFile]::ExtractToDirectory("$buildDir/llvm.zip", "$buildDir")

Info "Cmake generate cache"
cmake `
  -S $buildDir/llvm-project-llvmorg-19.1.0/llvm `
  -B $buildDir/out `
  -G "Ninja" `
  -DLLVM_TARGETS_TO_BUILD="AArch64" `
  -DLLVM_ENABLE_PROJECTS="clang" `
  -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded `
  -DCMAKE_BUILD_TYPE=Release
CheckReturnCodeOfPreviousCommand "cmake generate cache failed"

Info "Cmake build"
cmake `
  --build $buildDir/out `
  --target clang-format
CheckReturnCodeOfPreviousCommand "cmake build failed"

Info "Copy the executables to the publish directory and archive them"
New-Item $buildDir/publish -Force -ItemType "directory" > $null
Copy-Item -Path $buildDir/out/bin/clang-format.exe -Destination $buildDir/publish
Compress-Archive -Path "$buildDir/publish/*.exe" -DestinationPath $buildDir/publish/clang-format.zip
