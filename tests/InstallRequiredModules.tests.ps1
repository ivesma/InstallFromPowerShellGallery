$scriptFile = Join-Path (Split-Path -Parent $PSCommandPath) ("..\DevOpsProjects\{0}" -f ((Split-Path -Leaf $PSCommandPath) -replace '\.tests\.','.')) -Resolve
. ($scriptFile)
Describe -Tag "Unit" "Test of $scriptFile" {
    Context "Test Get-NuGetPath" {
        It "Error no env variable found" {
            {Get-NugetPath} | Should -Throw "Running locally, AGENT_HOMEDIRECTORY not found"
        }
        Mock Get-ChildItem -ParameterFilter {$Path -eq "env:"} -Verifiable {
            Write-Verbose "[Mocked] Get-ChildItem $Path"
            $envObj = New-Object psobject
            $envObj | Add-Member -MemberType NoteProperty -Name 'Name'  -Value 'AGENT_HOMEDIRECTORY'
            $envObj | Add-Member -MemberType NoteProperty -Name 'Value' -Value 'TestDrive:\'
            return $envObj
        }
        Mock Get-ChildItem -ParameterFilter {$Path -ne "env:"} -Verifiable {
            Write-Verbose "[Mocked] Get-ChildItem $Path"
            return (New-Item -ItemType File -Path (Join-Path $Path "nuget.exe"))
        }
        It "Returns a path to TestDrive" {
            Test-Path (Get-NugetPath) -PathType Leaf | Should -Not -BeNullOrEmpty
        }
        Assert-VerifiableMock
        Assert-MockCalled Get-ChildItem -ParameterFilter {$Path -eq "env:"} -Times 1
        Assert-MockCalled Get-ChildItem -ParameterFilter {$Path -ne "env:"} -Times 1
    }
    Context "Test Invoke-NuGet" {
        It "Throws Error on null ExePath" {
            {Invoke-NuGet -ExePath $null} | Should -Throw "Cannot validate argument on parameter 'ExePath'. Cannot bind argument to parameter 'Path' because it is an empty string."
        }
        It "Throws Error on empty ExePath" {
            {Invoke-NuGet -ExePath [string]::Empty} | Should -Throw 'Cannot validate argument on parameter ''ExePath''. The "Test-Path $_ -PathType Leaf" validation script for the argument with value "[string]::Empty" did not return a result of True. Determine why the validation script failed, and then try the command again.'
        }

        $testParams = @{
            "ExePath" = (New-Item -ItemType File -Path "TestDrive:\nuget.exe")
        }

        It "Throws Error on null Command" {
            {Invoke-NuGet @testParams -Command $null} | Should -Throw 'Cannot validate argument on parameter ''Command''. The argument "" does not belong to the set "sources" specified by the ValidateSet attribute. Supply an argument that is in the set and then try the command again.'
        }
        It "Throws Error on empty Command" {
            {Invoke-NuGet @testParams -Command ""} | Should -Throw 'Cannot validate argument on parameter ''Command''. The argument "" does not belong to the set "sources" specified by the ValidateSet attribute. Supply an argument that is in the set and then try the command again.'
        }
        $testParams.Add("Command","sources")

        It "Throws Error on null CliArgs" {
            {Invoke-NuGet @testParams -CliArgs $null} | Should -Throw 'Cannot validate argument on parameter ''CliArgs''. The argument is null or empty. Provide an argument that is not null or empty, and then try the command again.'
        }
        It "Throws Error on empty CliArgs" {
            {Invoke-NuGet @testParams -CliArgs ""} | Should -Throw 'Cannot validate argument on parameter ''CliArgs''. The argument is null or empty. Provide an argument that is not null or empty, and then try the command again.'
        }
        Mock New-TemporaryFile -Verifiable {
            $tempFile = (New-Item -Path ("TestDrive:\Temp_{0:yyyyMMdd_hhmmssffffff}" -f (Get-Date))).FullName
            Write-Verbose "[Mocked: New-TemporaryFile] $($tempFile.FullName)"
            return $tempFile
        }
        Mock Start-Process -Verifiable {
            if ($ArgumentList.Count -gt 1) {
                switch ($ArgumentList[1]) {
                    'P1' {
                        Write-Verbose '[Mocked: Start-Process] Write to standard error'
                        Add-Content $RedirectStandardError -Value "Error in Start-Process"
                    }
                    'P2' {
                        Write-Verbose '[Mocked: Start-Process] Write to standard out'
                        Add-Content $RedirectStandardOutput -Value "Start-Process called ok"
                    }
                    Default {
                        Write-Verbose '[Mocked: Start-Process] Unhandled 1st Argument after command'
                        Add-Content $RedirectStandardError -Value "Unhandled 1st Argument after command"
                    }
                }
            }
        }
        It "Handles when rows are output to StandardError" {
            {Invoke-NuGet @testParams -CliArgs @('P1')} | Should -Throw 'Error in Start-Process'
        }
        It "Returns true when nuget succeeds" {
            Invoke-NuGet @testParams -CliArgs @('P2') -Verbose | Should -Be $true
        }
        Assert-VerifiableMock
        Assert-MockCalled New-TemporaryFile -Times 4
        Assert-MockCalled Start-Process -Times 2
    }
    Context "Test a full call" {
        Mock Get-ChildItem -ParameterFilter {$Path -eq "env:"} -Verifiable {
            Write-Verbose "[Mocked] Get-ChildItem $Path"
            $envObj = New-Object psobject
            $envObj | Add-Member -MemberType NoteProperty -Name 'Name'  -Value 'AGENT_HOMEDIRECTORY'
            $envObj | Add-Member -MemberType NoteProperty -Name 'Value' -Value 'TestDrive:\'
            return $envObj
        }
        Mock Get-ChildItem -ParameterFilter {$Path -ne "env:"} -Verifiable {
            Write-Verbose "[Mocked] Get-ChildItem $Path"
            return (New-Item -ItemType File -Path (Join-Path $Path "nuget.exe") -Force)
        }
        Mock Start-Process -Verifiable {
            if ($ArgumentList.Count -gt 1) {
                Write-Verbose "[Mocked: Start-Process] Commnd: $Command"
                switch ($ArgumentList[0]) {
                    'Command' {
                        Add-Content $RedirectStandardOutput -Value "Start-Process called to add sources"
                    }
                    Default {
                        Write-Verbose '[Mocked: Start-Process] Unhandled command'
                        Add-Content $RedirectStandardError -Value "Unhandled 1st Argument after command"
                    }
                }
            }
        }
        It "Ensure all steps are called" {

        }
        Assert-VerifiableMock
    }
}
