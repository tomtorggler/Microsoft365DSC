function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateLength(1, 64)]
        [System.String]
        $Name,

        [Parameter()]
        [System.String]
        $Description,

        [Parameter()]
        [System.Boolean]
        $IsDefault,

        [Parameter()]
        [System.String[]]
        $Roles,

        [Parameter()]
        [ValidateSet('Present', 'Absent')]
        [System.String]
        $Ensure = 'Present',

        [Parameter()]
        [System.Management.Automation.PSCredential]
        $Credential,

        [Parameter()]
        [System.String]
        $ApplicationId,

        [Parameter()]
        [System.String]
        $TenantId,

        [Parameter()]
        [System.String]
        $CertificateThumbprint,

        [Parameter()]
        [System.String]
        $CertificatePath,

        [Parameter()]
        [System.Management.Automation.PSCredential]
        $CertificatePassword,

        [Parameter()]
        [Switch]
        $ManagedIdentity
    )

    Write-Verbose -Message "Getting Role Assignment Policy configuration for $Name"

    if ($Global:CurrentModeIsExport)
    {
        $ConnectionMode = New-M365DSCConnection -Workload 'ExchangeOnline' `
            -InboundParameters $PSBoundParameters `
            -SkipModuleReload $true
    }
    else
    {
        $ConnectionMode = New-M365DSCConnection -Workload 'ExchangeOnline' `
            -InboundParameters $PSBoundParameters
    }

    #Ensure the proper dependencies are installed in the current environment.
    Confirm-M365DSCDependencies

    #region Telemetry
    $ResourceName = $MyInvocation.MyCommand.ModuleName -replace 'MSFT_', ''
    $CommandName = $MyInvocation.MyCommand
    $data = Format-M365DSCTelemetryParameters -ResourceName $ResourceName `
        -CommandName $CommandName `
        -Parameters $PSBoundParameters
    Add-M365DSCTelemetryEvent -Data $data
    #endregion

    $nullReturn = $PSBoundParameters
    $nullReturn.Ensure = 'Absent'

    try
    {
        $AllRoleAssignmentPolicies = Get-RoleAssignmentPolicy -ErrorAction Stop

        $RoleAssignmentPolicy = $AllRoleAssignmentPolicies | Where-Object -FilterScript { $_.Name -eq $Name }

        if ($null -eq $RoleAssignmentPolicy)
        {
            Write-Verbose -Message "Role Assignment Policy $($Name) does not exist."
            return $nullReturn
        }
        else
        {
            $result = @{
                Name                  = $RoleAssignmentPolicy.Name
                Description           = $RoleAssignmentPolicy.Description
                IsDefault             = $RoleAssignmentPolicy.IsDefault
                Roles                 = $RoleAssignmentPolicy.AssignedRoles
                Ensure                = 'Present'
                Credential            = $Credential
                ApplicationId         = $ApplicationId
                CertificateThumbprint = $CertificateThumbprint
                CertificatePath       = $CertificatePath
                CertificatePassword   = $CertificatePassword
                Managedidentity       = $ManagedIdentity.IsPresent
                TenantId              = $TenantId
            }

            Write-Verbose -Message "Found Role Assignment Policy $($Name)"
            return $result
        }
    }
    catch
    {
        try
        {
            Write-Verbose -Message $_
            $tenantIdValue = ''
            if (-not [System.String]::IsNullOrEmpty($TenantId))
            {
                $tenantIdValue = $TenantId
            }
            elseif ($null -ne $Credential)
            {
                $tenantIdValue = $Credential.UserName.Split('@')[1]
            }
            Add-M365DSCEvent -Message $_ -EntryType 'Error' `
                -EventID 1 -Source $($MyInvocation.MyCommand.Source) `
                -TenantId $tenantIdValue
        }
        catch
        {
            Write-Verbose -Message $_
        }
        return $nullReturn
    }
}

function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateLength(1, 64)]
        [System.String]
        $Name,

        [Parameter()]
        [System.String]
        $Description,

        [Parameter()]
        [System.Boolean]
        $IsDefault,

        [Parameter()]
        [System.String[]]
        $Roles,

        [Parameter()]
        [ValidateSet('Present', 'Absent')]
        [System.String]
        $Ensure = 'Present',

        [Parameter()]
        [System.Management.Automation.PSCredential]
        $Credential,

        [Parameter()]
        [System.String]
        $ApplicationId,

        [Parameter()]
        [System.String]
        $TenantId,

        [Parameter()]
        [System.String]
        $CertificateThumbprint,

        [Parameter()]
        [System.String]
        $CertificatePath,

        [Parameter()]
        [System.Management.Automation.PSCredential]
        $CertificatePassword,

        [Parameter()]
        [Switch]
        $ManagedIdentity
    )

    Write-Verbose -Message "Setting Role Assignment Policy configuration for $Name"

    $currentRoleAssignmentPolicyConfig = Get-TargetResource @PSBoundParameters

    #Ensure the proper dependencies are installed in the current environment.
    Confirm-M365DSCDependencies

    #region Telemetry
    $ResourceName = $MyInvocation.MyCommand.ModuleName -replace 'MSFT_', ''
    $CommandName = $MyInvocation.MyCommand
    $data = Format-M365DSCTelemetryParameters -ResourceName $ResourceName `
        -CommandName $CommandName `
        -Parameters $PSBoundParameters
    Add-M365DSCTelemetryEvent -Data $data
    #endregion

    $ConnectionMode = New-M365DSCConnection -Workload 'ExchangeOnline' `
        -InboundParameters $PSBoundParameters

    $NewRoleAssignmentPolicyParams = @{
        Name        = $Name
        Description = $Description
        IsDefault   = $IsDefault
        Roles       = $Roles
        Confirm     = $false
    }

    $SetRoleAssignmentPolicyParams = @{
        Identity    = $Name
        Name        = $Name
        Description = $Description
        IsDefault   = $IsDefault
        Roles       = $Roles
        Confirm     = $false
    }

    # CASE: Role Assignment Policy doesn't exist but should;
    if ($Ensure -eq 'Present' -and $currentRoleAssignmentPolicyConfig.Ensure -eq 'Absent')
    {
        Write-Verbose -Message "Role Assignment Policy '$($Name)' does not exist but it should. Create and configure it."
        # Create Role Assignment Policy
        New-RoleAssignmentPolicy @NewRoleAssignmentPolicyParams
    }
    # CASE: Role Assignment Policy exists but it shouldn't;
    elseif ($Ensure -eq 'Absent' -and $currentRoleAssignmentPolicyConfig.Ensure -eq 'Present')
    {
        Write-Verbose -Message "Role Assignment Policy '$($Name)' exists but it shouldn't. Remove it."
        Remove-RoleAssignmentPolicy -Identity $Name -Confirm:$false
    }
    # CASE: Role Assignment Policy exists and it should, but has different values than the desired ones
    elseif ($Ensure -eq 'Present' -and $currentRoleAssignmentPolicyConfig.Ensure -eq 'Present' -and $null -eq (Compare-Object -ReferenceObject $($currentRoleAssignmentPolicyConfig.Roles) -DifferenceObject $Roles))
    {
        Write-Verbose -Message "Role Assignment Policy '$($Name)' already exists, but needs updating."
        Write-Verbose -Message "Setting Role Assignment Policy $($Name) with values: $(Convert-M365DscHashtableToString -Hashtable $SetRoleAssignmentPolicyParams)"
        $SetRoleAssignmentPolicyParams.Remove('Roles') | Out-Null
        Set-RoleAssignmentPolicy @SetRoleAssignmentPolicyParams
    }
    # CASE: Role Assignment Policy exists and it should, but Roles attribute has different values than the desired ones
    # Set-RoleAssignmentPolicy cannot change Roles attribute. Therefore we have to remove and recreate the policy if Roles attribute should be changed.
    elseif ($Ensure -eq 'Present' -and $currentRoleAssignmentPolicyConfig.Ensure -eq 'Present' -and $null -ne (Compare-Object -ReferenceObject $($currentRoleAssignmentPolicyConfig.Roles) -DifferenceObject $Roles))
    {
        Write-Verbose -Message "Role Assignment Policy '$($Name)' already exists, but roles attribute needs updating."
        $differences = Compare-Object -ReferenceObject $($currentRoleAssignmentPolicyConfig.Roles) -DifferenceObject $Roles
        foreach ($difference in $differences)
        {
            if ($difference.SideIndicator -eq '=>')
            {
                Write-Verbose -Message "Adding Role {$($difference.InputObject)} to Role Assignment Policy {$Name}"
                New-ManagementRoleAssignment -Role $($difference.InputObject) -Policy $Name
            }
            elseif ($difference.SideIndicator -eq '<=')
            {
                Write-Verbose -Message "Removing Role {$($difference.InputObject)} from Role Assignment Policy {$Name}"
                Remove-ManagementRoleAssignment -Identity "$($difference.InputObject)-$Name"
            }
        }
    }
}

function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateLength(1, 64)]
        [System.String]
        $Name,

        [Parameter()]
        [System.String]
        $Description,

        [Parameter()]
        [System.Boolean]
        $IsDefault,

        [Parameter()]
        [System.String[]]
        $Roles,

        [Parameter()]
        [ValidateSet('Present', 'Absent')]
        [System.String]
        $Ensure = 'Present',

        [Parameter()]
        [System.Management.Automation.PSCredential]
        $Credential,

        [Parameter()]
        [System.String]
        $ApplicationId,

        [Parameter()]
        [System.String]
        $TenantId,

        [Parameter()]
        [System.String]
        $CertificateThumbprint,

        [Parameter()]
        [System.String]
        $CertificatePath,

        [Parameter()]
        [System.Management.Automation.PSCredential]
        $CertificatePassword,

        [Parameter()]
        [Switch]
        $ManagedIdentity
    )
    #Ensure the proper dependencies are installed in the current environment.
    Confirm-M365DSCDependencies

    #region Telemetry
    $ResourceName = $MyInvocation.MyCommand.ModuleName -replace 'MSFT_', ''
    $CommandName = $MyInvocation.MyCommand
    $data = Format-M365DSCTelemetryParameters -ResourceName $ResourceName `
        -CommandName $CommandName `
        -Parameters $PSBoundParameters
    Add-M365DSCTelemetryEvent -Data $data
    #endregion

    Write-Verbose -Message "Testing Role Assignment Policy configuration for $Name"

    $CurrentValues = Get-TargetResource @PSBoundParameters

    Write-Verbose -Message "Current Values: $(Convert-M365DscHashtableToString -Hashtable $CurrentValues)"
    Write-Verbose -Message "Target Values: $(Convert-M365DscHashtableToString -Hashtable $PSBoundParameters)"

    $ValuesToCheck = $PSBoundParameters
    $ValuesToCheck.Remove('Credential') | Out-Null
    $ValuesToCheck.Remove('ApplicationId') | Out-Null
    $ValuesToCheck.Remove('TenantId') | Out-Null
    $ValuesToCheck.Remove('CertificateThumbprint') | Out-Null
    $ValuesToCheck.Remove('CertificatePath') | Out-Null
    $ValuesToCheck.Remove('CertificatePassword') | Out-Null
    $ValuesToCheck.Remove('Managedidentity') | Out-Null

    $TestResult = Test-M365DSCParameterState -CurrentValues $CurrentValues `
        -Source $($MyInvocation.MyCommand.Source) `
        -DesiredValues $PSBoundParameters `
        -ValuesToCheck $ValuesToCheck.Keys

    Write-Verbose -Message "Test-TargetResource returned $TestResult"

    return $TestResult
}

function Export-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.String])]
    param
    (
        [Parameter()]
        [System.Management.Automation.PSCredential]
        $Credential,

        [Parameter()]
        [System.String]
        $ApplicationId,

        [Parameter()]
        [System.String]
        $TenantId,

        [Parameter()]
        [System.String]
        $CertificateThumbprint,

        [Parameter()]
        [System.String]
        $CertificatePath,

        [Parameter()]
        [System.Management.Automation.PSCredential]
        $CertificatePassword,

        [Parameter()]
        [Switch]
        $ManagedIdentity
    )
    $ConnectionMode = New-M365DSCConnection -Workload 'ExchangeOnline' `
        -InboundParameters $PSBoundParameters `
        -SkipModuleReload $true

    #Ensure the proper dependencies are installed in the current environment.
    Confirm-M365DSCDependencies

    #region Telemetry
    $ResourceName = $MyInvocation.MyCommand.ModuleName -replace 'MSFT_', ''
    $CommandName = $MyInvocation.MyCommand
    $data = Format-M365DSCTelemetryParameters -ResourceName $ResourceName `
        -CommandName $CommandName `
        -Parameters $PSBoundParameters
    Add-M365DSCTelemetryEvent -Data $data
    #endregion

    try
    {
        [array]$AllRoleAssignmentPolicies = Get-RoleAssignmentPolicy -ErrorAction Stop

        $dscContent = ''

        if ($AllRoleAssignmentPolicies.Length -eq 0)
        {
            Write-Host $Global:M365DSCEmojiGreenCheckMark
        }
        else
        {
            Write-Host "`r`n" -NoNewline
        }
        $i = 1
        foreach ($RoleAssignmentPolicy in $AllRoleAssignmentPolicies)
        {
            Write-Host "    |---[$i/$($AllRoleAssignmentPolicies.Length)] $($RoleAssignmentPolicy.Name)" -NoNewline

            $Params = @{
                Name                  = $RoleAssignmentPolicy.Name
                Credential            = $Credential
                ApplicationId         = $ApplicationId
                TenantId              = $TenantId
                CertificateThumbprint = $CertificateThumbprint
                CertificatePassword   = $CertificatePassword
                Managedidentity       = $ManagedIdentity.IsPresent
                CertificatePath       = $CertificatePath
            }
            $Results = Get-TargetResource @Params
            $Results = Update-M365DSCExportAuthenticationResults -ConnectionMode $ConnectionMode `
                -Results $Results
            $currentDSCBlock = Get-M365DSCExportContentForResource -ResourceName $ResourceName `
                -ConnectionMode $ConnectionMode `
                -ModulePath $PSScriptRoot `
                -Results $Results `
                -Credential $Credential
            $dscContent += $currentDSCBlock
            Save-M365DSCPartialExport -Content $currentDSCBlock `
                -FileName $Global:PartialExportFileName
            Write-Host $Global:M365DSCEmojiGreenCheckMark
            $i++
        }
        return $dscContent
    }
    catch
    {
        try
        {
            Write-Verbose -Message $_
            $tenantIdValue = ''
            if (-not [System.String]::IsNullOrEmpty($TenantId))
            {
                $tenantIdValue = $TenantId
            }
            elseif ($null -ne $Credential)
            {
                $tenantIdValue = $Credential.UserName.Split('@')[1]
            }
            Add-M365DSCEvent -Message $_ -EntryType 'Error' `
                -EventID 1 -Source $($MyInvocation.MyCommand.Source) `
                -TenantId $tenantIdValue
        }
        catch
        {
            Write-Verbose -Message $_
        }
        return ''
    }
}

Export-ModuleMember -Function *-TargetResource

