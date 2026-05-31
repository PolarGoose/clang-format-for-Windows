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

$root = Resolve-Path "$PSScriptRoot"
$buildDir = "$root/build"

Info "Find Visual Studio installation path"
$vswhereCommand = Get-Command -Name "${Env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$installationPath = & $vswhereCommand -prerelease -latest -property installationPath

Info "Remove '$buildDir' folder if it exists"
Remove-Item $buildDir -Force -Recurse -ErrorAction SilentlyContinue
New-Item $buildDir -Force -ItemType "directory" > $null

Info "Clone llvm source code"
git clone --depth 1 --branch llvmorg-22.1.6 https://github.com/llvm/llvm-project.git $buildDir
CheckReturnCodeOfPreviousCommand "git clone failed"

Info "Open Visual Studio Developer PowerShell"
& "$installationPath\Common7\Tools\Launch-VsDevShell.ps1" -SkipAutomaticLocation -Arch amd64

Info "Cmake generate cache"
cmake `
  -S $buildDir/llvm `
  -B $buildDir/out `
  -G "Ninja" `
  -D LLVM_TARGETS_TO_BUILD="AArch64" `
  -D LLVM_ENABLE_PROJECTS="clang" `
  -D CMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded `
  -D CMAKE_ASM_MASM_FLAGS="/nologo" `
  -D CMAKE_INTERPROCEDURAL_OPTIMIZATION_RELEASE=ON `
  -D CMAKE_BUILD_TYPE=Release
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
