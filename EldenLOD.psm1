# EldenLOD PowerShell Module
# Common functions for working with Elden Ring LOD assets

function Timestamp {
    [DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss')
}

function Write-LogMessage {
    param(
        [string]$message,
        [string]$logFile,
        [switch]$isError
    )
    
    $ts = Timestamp
    $logMsg = if ($isError) { "[$ts] ERROR: $message" } else { "[$ts] $message" }
    
    if ($isError) {
        Write-Warning $message
    } else {
        Write-Host $message
    }
    
    if ($logFile) {
        $logMsg | Out-File -FilePath $logFile -Encoding UTF8 -Append
    }
}

function Write-VerboseLog {
    param(
        [string]$message,
        [string]$logFile
    )
    
    Write-Verbose $message
    if ($logFile) {
        $ts = Timestamp
        "[$ts] VERBOSE: $message" | Out-File -FilePath $logFile -Encoding UTF8 -Append
    }
}

function Test-TpfEmpty {
    param(
        [string]$tpfExtractDir,
        [string]$logFile
    )
    
    Write-VerboseLog -message "Checking if TPF is intentionally empty: $tpfExtractDir" -logFile $logFile
    
    if (-not (Test-Path $tpfExtractDir)) {
        return $false
    }
    
    # Look for witchy-tpf.xml (with or without underscore prefix)
    $xmlPath = Join-Path $tpfExtractDir '_witchy-tpf.xml'
    if (-not (Test-Path $xmlPath)) {
        $xmlPath = Join-Path $tpfExtractDir 'witchy-tpf.xml'
    }
    
    if (-not (Test-Path $xmlPath)) {
        Write-VerboseLog -message "No TPF XML found, cannot determine if empty" -logFile $logFile
        return $false
    }
    
    try {
        $xml = [xml](Get-Content $xmlPath)
        
        # Check various ways TPF might be empty
        if ($xml.tpf -and $xml.tpf.textures) {
            $textureCount = 0
            
            # Check Count property
            if ($xml.tpf.textures.Count -eq 0) {
                $textureCount = 0
            }
            # Check if has child nodes
            elseif (-not $xml.tpf.textures.HasChildNodes) {
                $textureCount = 0  
            }            # Check if texture children exist
            elseif ($xml.tpf.textures.texture) {
                $textureCount = $xml.tpf.textures.texture.Count
                if ($null -eq $textureCount) {
                    # Single texture case
                    $textureCount = 1
                }
            }
            
            if ($textureCount -eq 0) {
                Write-VerboseLog -message "TPF is intentionally empty (no textures in XML)" -logFile $logFile
                return $true
            }
        }
        
        Write-VerboseLog -message "TPF has textures defined in XML" -logFile $logFile
        return $false
    }
    catch {
        Write-VerboseLog -message "Error parsing TPF XML: $_" -logFile $logFile
        return $false
    }
}

function Test-TpfValid {
    param(
        [string]$tpfPath,
        [string]$expectedDir,
        [string]$logFile,
        [switch]$skipDdsCheck
    )
    
    Write-VerboseLog -message "Validating TPF: $tpfPath" -logFile $logFile
    
    # Basic path validation
    if (-not (Test-Path $tpfPath)) {
        Write-Warning "TPF file not found: $tpfPath"
        Write-VerboseLog -message "TPF validation failed: File not found" -logFile $logFile
        return $false
    }
    
    if (-not (Test-Path $expectedDir)) {
        Write-Warning "TPF extract directory not found: $expectedDir"
        Write-VerboseLog -message "TPF validation failed: Extract dir not found" -logFile $logFile
        return $false
    }

    # Check for witchy-tpf.xml
    $xmlPath = Join-Path $expectedDir '_witchy-tpf.xml'
    if (-not (Test-Path $xmlPath)) {
        Write-Warning "TPF metadata not found: $xmlPath"
        Write-VerboseLog -message "TPF validation failed: Missing witchy-tpf.xml" -logFile $logFile
        return $false
    }    # Check if TPF is intentionally empty by examining XML (try both naming conventions)
    $xmlPath = Join-Path $expectedDir '_witchy-tpf.xml'
    if (-not (Test-Path $xmlPath)) {
        $xmlPath = Join-Path $expectedDir 'witchy-tpf.xml'
    }
    
    if (Test-Path $xmlPath) {
        try {
            $xml = [xml](Get-Content $xmlPath)
            if ($xml.tpf -and $xml.tpf.textures -and $xml.tpf.textures.Count -eq 0) {
                Write-VerboseLog -message "TPF validation passed: Empty TPF (no textures defined in XML)" -logFile $logFile
                return $true
            }
            
            # Also check if textures node exists but has no children
            if ($xml.tpf -and $xml.tpf.textures -and -not $xml.tpf.textures.HasChildNodes) {
                Write-VerboseLog -message "TPF validation passed: Empty TPF (no texture children in XML)" -logFile $logFile
                return $true
            }
        }
        catch {
            Write-VerboseLog -message "Warning: Could not parse TPF XML, continuing with file checks" -logFile $logFile
        }
    }

    # Only check for DDS files if XML indicates there should be textures
    if (-not $skipDdsCheck) {
        $ddsFiles = Get-ChildItem -Path $expectedDir -Filter '*.dds' -File
        if ($ddsFiles.Count -eq 0) {
            # Double-check if this is an intentionally empty TPF before failing
            if (Test-Path $xmlPath) {
                try {
                    $xml = [xml](Get-Content $xmlPath)
                    if ($xml.tpf -and $xml.tpf.textures -and ($xml.tpf.textures.Count -eq 0 -or -not $xml.tpf.textures.HasChildNodes)) {
                        Write-VerboseLog -message "TPF validation passed: Confirmed empty TPF via XML after DDS check" -logFile $logFile
                        return $true
                    }
                }
                catch {
                    # If XML parsing fails, treat as potentially valid empty TPF
                    Write-VerboseLog -message "TPF validation passed: XML parsing failed, treating as potentially valid empty TPF" -logFile $logFile
                    return $true
                }
            }
            
            Write-Warning "No DDS files found in TPF extract: $expectedDir"
            Write-VerboseLog -message "TPF validation failed: No DDS files found and XML indicates textures should exist" -logFile $logFile
            return $false
        }
        Write-VerboseLog -message "TPF validation passed: Found $($ddsFiles.Count) DDS files" -logFile $logFile
    } else {
        Write-VerboseLog -message "TPF validation passed: DDS check skipped" -logFile $logFile
    }
    
    return $true
}

function Invoke-TpfRepack {
    param(
        [string]$tpfPath,
        [string]$tpfDir,
        [string]$logFile
    )

    Write-VerboseLog -message "Starting TPF repack: $tpfPath" -logFile $logFile
    $result = $true
    
    # Initial validation with DDS check skipped for first-time extraction
    if (-not (Test-TpfValid -tpfPath $tpfPath -expectedDir $tpfDir -logFile $logFile -skipDdsCheck)) {
        Write-VerboseLog -message "TPF validation failed, skipping repack" -logFile $logFile
        return $false
    }    # Store original location
    $originalLocation = Get-Location
    $tpfName = Split-Path $tpfPath -Leaf
      try {
        # The TPF directory should already contain the XML from extraction
        $xmlPath = Join-Path $tpfDir '_witchy-tpf.xml'
        if (-not (Test-Path $xmlPath)) {
            Write-LogMessage -message "Missing expected XML from TPF extraction: $xmlPath" -logFile $logFile -isError
            return $false
        }
        
        # Remove any existing backup files
        Get-ChildItem -Path $tpfDir -Filter "*.bak" | Remove-Item -Force
        
        # Change to TPF directory for repacking
        Set-Location $tpfDir
        Write-VerboseLog -message "Working directory for repack: $(Get-Location)" -logFile $logFile
        
        # List files in directory for debugging
        $files = Get-ChildItem -Path $tpfDir -File
        Write-VerboseLog -message "Files in TPF dir: $($files.Name -join ', ')" -logFile $logFile
        
        # Verify essential files exist
        $xmlExists = Test-Path (Join-Path $tpfDir 'witchy-tpf.xml')
        $ddsCount = (Get-ChildItem -Path $tpfDir -Filter "*.dds").Count
        Write-VerboseLog -message "XML exists: $xmlExists, DDS count: $ddsCount" -logFile $logFile
          Write-VerboseLog -message "Executing witchybnd for TPF repack from $(Get-Location)" -logFile $logFile
        
        # Change to the parent directory where the TPF is located
        Push-Location (Split-Path $tpfPath -Parent)
        
        # Use just the TPF filename since we're in its directory
        $tpfName = Split-Path $tpfPath -Leaf
        Write-VerboseLog -message "Repacking TPF: $tpfName from $(Get-Location)" -logFile $logFile
        
        $witchyOutput = & witchybnd -r $tpfName 2>&1
        
        # Return to original directory
        Pop-Location
        $witchyOutput | ForEach-Object {
            Write-VerboseLog -message "witchybnd: $_" -logFile $logFile
        }

        if ($LASTEXITCODE -ne 0) {
            Write-LogMessage -message "ERROR repacking TPF: $tpfName" -logFile $logFile -isError
            Write-LogMessage -message "witchybnd output: $($witchyOutput -join "`n")" -logFile $logFile -isError
            $result = $false
        } else {
            if (Test-Path $resolvedPath) {
                $fileSize = (Get-Item $resolvedPath).Length
                Write-LogMessage -message "Successfully repacked TPF: $tpfName (size: $fileSize bytes)" -logFile $logFile
            } else {
                Write-LogMessage -message "ERROR: TPF file not created: $resolvedPath" -logFile $logFile -isError
                $result = $false
            }
        }
        
        # Clean up working files
        Write-VerboseLog -message "Cleaning up temporary TPF files" -logFile $logFile
        Remove-Item (Join-Path $tpfDir 'witchy-tpf.xml') -Force -ErrorAction SilentlyContinue
    }
    catch {
        Write-LogMessage -message "Exception during TPF repack: $_" -logFile $logFile -isError
        $result = $false
    }
    finally {
        # Restore original location
        Set-Location $originalLocation
    }

    return $result
}

function Remove-ExtractedDir {
    param(
        [string]$path,
        [switch]$Force
    )
    
    if (Test-Path $path) {
        Write-Host "Cleaning up: $path"
        try {
            Remove-Item $path -Recurse -Force:$Force
        }
        catch {
            Write-Warning "Failed to remove: $path`nError: $_"
        }
    }
}

# Export functions that should be available to scripts
Export-ModuleMember -Function @(
    'Timestamp',
    'Write-LogMessage', 
    'Write-VerboseLog',
    'Test-TpfEmpty',
    'Test-TpfValid',
    'Invoke-TpfRepack',
    'Remove-ExtractedDir'
)
