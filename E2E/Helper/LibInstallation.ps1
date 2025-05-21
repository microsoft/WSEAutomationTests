function ManagePythonSetup {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("install", "uninstall")]
        [string]$Action
    )

    $ScriptRoot = $PSScriptRoot
    $offlinePackagesPath = Join-Path $ScriptRoot "offline_packages"
    $pythonInstallerOfflinePath = Join-Path $offlinePackagesPath "python-3.11.5-amd64.exe"

    function TestInternetConnection {
        try {
            Invoke-WebRequest -Uri "http://www.google.com" -Method Head -TimeoutSec 5 | Out-Null
            return $true
        } catch {
            return $false
        }
    }

    function IsPythonCommandAvailable {
        $pythonCommands = @("python", "python3")
        foreach ($cmd in $pythonCommands) {
            try {
                $versionOutput = & $cmd --version 2>&1
                if ($versionOutput -match "Python\s+\d+\.\d+\.\d+") {
                    return $true
                }
            } catch {}
        }
        return $false
    }

    function IsPythonExecutablePresent {
        $possiblePaths = @(
            "$env:LOCALAPPDATA\Programs\Python\Python3*\python.exe",
            "C:\Python3*\python.exe",
            "C:\Program Files\Python3*\python.exe",
            "C:\Program Files (x86)\Python3*\python.exe"
        )
        foreach ($pathPattern in $possiblePaths) {
            $matches = Get-ChildItem -Path $pathPattern -ErrorAction SilentlyContinue
            if ($matches) { return $true }
        }
        return $false
    }

    function IsPythonRegisteredInRegistry {
        $regPaths = @(
            "HKLM:\Software\Python\PythonCore",
            "HKLM:\Software\WOW6432Node\Python\PythonCore"
        )
        foreach ($regPath in $regPaths) {
            if (Test-Path $regPath) {
                $versions = Get-ChildItem $regPath -ErrorAction SilentlyContinue
                if ($versions) { return $true }
            }
        }
        return $false
    }

    function IsPythonInstalled {
        return (IsPythonCommandAvailable -and IsPythonExecutablePresent -and IsPythonRegisteredInRegistry)
    }

    function TestPythonModuleInstalled($moduleName) {
        try {
            & python -c "import $moduleName" 2>$null
            return ($LASTEXITCODE -eq 0)
        } catch {
            return $false
        }
    }

    function RefreshPythonPath {
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::Machine)
    }

    function InstallPythonOffline {
        if (-Not (Test-Path $pythonInstallerOfflinePath)) {
            Write-Host "Python installer not found in offline folder: $pythonInstallerOfflinePath"
            return $false
        }
        Write-Host "Installing Python from offline package..."
        Start-Process -FilePath $pythonInstallerOfflinePath -ArgumentList "/quiet InstallAllUsers=1 PrependPath=1 Include_pip=1" -Wait
        RefreshPythonPath
        Start-Sleep -Seconds 5
        return $true
    }

    function InstallPythonOnline {
        $pythonUrl = "https://www.python.org/ftp/python/3.11.5/python-3.11.5-amd64.exe"
        $tempInstallerPath = Join-Path $env:TEMP "python-latest.exe"

        Write-Host "Downloading Python installer..."
        Invoke-WebRequest -Uri $pythonUrl -OutFile $tempInstallerPath -UseBasicParsing

        Write-Host "Installing Python..."
        Start-Process -FilePath $tempInstallerPath -ArgumentList "/quiet InstallAllUsers=1 PrependPath=1 Include_pip=1" -Wait

        RefreshPythonPath
        Start-Sleep -Seconds 5
        return $true
    }

    function InstallMissingLibrariesOffline {
        $modules = @("pandas", "pywinauto", "openpyxl")
        foreach ($module in $modules) {
            if (-not (TestPythonModuleInstalled $module)) {
                $whl = Get-ChildItem -Path $offlinePackagesPath -Filter "$module*.whl" | Select-Object -First 1
                if ($whl) {
                    Write-Host "Installing $module from offline wheel..."
                    & python -m pip install $whl.FullName
                } else {
                    Write-Host "Offline wheel for $module not found."
                }
            } else {
                Write-Host "$module already installed."
            }
        }
    }

    function InstallMissingLibrariesOnline {
        Write-Host "Upgrading pip and installing missing packages online..."
        & python -m pip install --upgrade pip

        $modules = @("pandas", "pywinauto", "openpyxl")
        foreach ($module in $modules) {
            if (-not (TestPythonModuleInstalled $module)) {
                Write-Host "Installing $module online..."
                & python -m pip install $module
            } else {
                Write-Host "$module already installed."
            }
        }
    }

    function UninstallPython {
        Write-Host "`n=== Uninstalling Python and related libraries ===" -ForegroundColor Cyan

        if (Get-Command python -ErrorAction SilentlyContinue) {
            Write-Host "Uninstalling Python libraries..." -ForegroundColor Yellow
            & python -m pip uninstall -y pandas pywinauto openpyxl
        }

        $registryPaths = @(
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
            "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
            "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
        )

        foreach ($path in $registryPaths) {
            Get-ItemProperty $path -ErrorAction SilentlyContinue |
                Where-Object { $_.DisplayName -like "*Python*" -and $_.UninstallString } |
                ForEach-Object {
                    Write-Host "Attempting to uninstall: $($_.DisplayName)" -ForegroundColor Yellow
                    $uninstallCmd = $_.UninstallString
                    try {
                        if ($uninstallCmd -match "msiexec") {
                            if ($uninstallCmd -notmatch "/qn") { $uninstallCmd += " /qn" }
                            Start-Process -FilePath "cmd.exe" -ArgumentList "/c", $uninstallCmd -Wait
                        } else {
                            $exe, $args = $uninstallCmd -split ' (?=(?:[^"]*"[^"]*")*[^"]*$)', 2
                            if ($args -notmatch "/S" -and $args -notmatch "/silent" -and $args -notmatch "/quiet") {
                                $args += " /S"
                            }
                            Start-Process -FilePath $exe -ArgumentList $args -Wait
                        }
                        Write-Host "Successfully uninstalled $($_.DisplayName)" -ForegroundColor Green
                    } catch {
                        Write-Host "Failed to uninstall $($_.DisplayName). Removing registry entry..." -ForegroundColor Red
                        try {
                            Remove-Item -Path $_.PSPath -Force
                            Write-Host "Removed registry entry: $($_.PSPath)" -ForegroundColor Green
                        } catch {
                            Write-Host "Failed to remove registry entry: $($_.PSPath)" -ForegroundColor Red
                        }
                    }
                }
        }

        function Remove-PythonFromPath($path) {
            $paths = $path -split ';' | Where-Object { $_ -notmatch "Python" }
            return ($paths -join ';')
        }

        Write-Host "Cleaning Python from PATH environment variables..." -ForegroundColor Cyan
        $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
        $sysPath = [Environment]::GetEnvironmentVariable("Path", "Machine")

        [Environment]::SetEnvironmentVariable("Path", (Remove-PythonFromPath $userPath), "User")
        [Environment]::SetEnvironmentVariable("Path", (Remove-PythonFromPath $sysPath), "Machine")

        Start-Sleep -Seconds 3

        try {
            python --version
        } catch {
            Write-Host "Python is no longer available on the system." -ForegroundColor Green
        }
    }

    # --- Dispatcher logic based on updated requirement ---
    if ($Action -eq "install") {
        if (-not (TestInternetConnection)) {
            Write-Host "`n=== Offline Installation Requested ===" -ForegroundColor Cyan
            UninstallPython
            $pythonInstalled = InstallPythonOffline
            if ($pythonInstalled) {
                InstallMissingLibrariesOffline
            }
        } else {
            Write-Host "`n=== Online Installation Requested ===" -ForegroundColor Cyan
            if (-not (IsPythonInstalled)) {
                Write-Host "Python not installed or corrupted. Reinstalling online..." -ForegroundColor Yellow
                UninstallPython
                $pythonInstalled = InstallPythonOnline
                if ($pythonInstalled) {
                    InstallMissingLibrariesOnline
                }
            } else {
                Write-Host "Python installation is valid. Checking for missing libraries..." -ForegroundColor Green
                InstallMissingLibrariesOnline
            }
        }
    }

    if ($Action -eq "uninstall") {
        UninstallPython
    }
}
