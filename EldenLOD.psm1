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

function Invoke-FileRenumbering {
    param(
        [string]$extractDir,
        [string]$expectedNumber,
        [string]$currentNumber,
        [string]$logFile,
        [switch]$Execute,
        [switch]$DryRun
    )
    
    Write-VerboseLog -message "Starting file renumbering: $extractDir ($currentNumber -> $expectedNumber)" -logFile $logFile
    $renumbered = $false
    $renamedFiles = @()
    
    # Define file patterns to renumber (excluding TPF files which should be handled separately)
    $filePatterns = @('*.flver', '*.anibnd', '*.clm2', '*.hkx', '*.hks', '*.bnk', '*.flv')
    
    foreach ($pattern in $filePatterns) {
        $files = Get-ChildItem -Path $extractDir -Filter $pattern -File
        foreach ($file in $files) {
            # Match pattern: PREFIX_CURRENTNUMBER[SUFFIX].EXTENSION
            if ($file.Name -match '^([A-Z]+_[A-Z]+)_([0-9]+)(.*)\.([a-z0-9]+)$') {
                $filePrefix = $matches[1]
                $fileCurrentNumber = $matches[2]
                $fileSuffix = $matches[3]
                $fileExtension = $matches[4]
                
                # Only rename if there's a mismatch between container and file numbers
                if ($fileCurrentNumber -ne $expectedNumber) {
                    $newFileName = "${filePrefix}_${expectedNumber}${fileSuffix}.${fileExtension}"
                    
                    if ($DryRun) {
                        Write-Host "Would renumber ${fileExtension.ToUpper()}: '$($file.Name)' -> '$newFileName'"
                        Write-Host "  Container expects: $expectedNumber, file contains: $fileCurrentNumber"
                    } else {
                        Write-Host "Container/Content mismatch - Renumbering ${fileExtension.ToUpper()}: '$($file.Name)' -> '$newFileName'"
                        Write-Host "  Container expects: $expectedNumber, file contains: $fileCurrentNumber"
                    }
                    
                    if ($Execute) {
                        $oldPath = $file.FullName
                        $newPath = Join-Path $extractDir $newFileName
                        if (Test-Path $newPath) { Remove-Item $newPath -Force }
                        Rename-Item -Path $oldPath -NewName $newFileName -Force
                        $renumbered = $true
                        $renamedFiles += @{
                            OldName = $file.Name
                            NewName = $newFileName
                        }
                        Write-VerboseLog -message "Renamed file: $($file.Name) -> $newFileName" -logFile $logFile
                    }
                } else {
                    if ($DryRun) {
                        Write-Host "${fileExtension.ToUpper()} numbering matches container - no renaming needed: '$($file.Name)'"
                    } else {
                        Write-Host "${fileExtension.ToUpper()} numbering matches container - no renaming needed: '$($file.Name)'"
                    }
                }
            }
        }
    }
    
    return @{
        Renumbered = $renumbered
        RenamedFiles = $renamedFiles
    }
}

function Invoke-DdsRenumbering {
    param(
        [string]$tpfExtractDir,
        [string]$expectedNumber,
        [string]$logFile,
        [switch]$Execute,
        [switch]$DryRun
    )
    
    Write-VerboseLog -message "Starting DDS renumbering: $tpfExtractDir (-> $expectedNumber)" -logFile $logFile
    $ddsRenamed = $false
    $renamedFiles = @()
    
    # Get DDS files in the extracted TPF directory
    $ddsFiles = Get-ChildItem -Path $tpfExtractDir -Filter '*.dds' -File
    
    # Process DDS files inside TPF - only rename if numbers don't match container
    foreach ($dds in $ddsFiles) {
        if ($dds.Name -match '^([A-Z]+_[A-Z]+)_([0-9]+)(.+\.dds)$') {
            $ddsPrefix = $matches[1]
            $ddsCurrentNumber = $matches[2]
            $ddsSuffix = $matches[3]
            
            # Only rename if there's a mismatch
            if ($ddsCurrentNumber -ne $expectedNumber) {
                $newDdsName = "${ddsPrefix}_${expectedNumber}${ddsSuffix}"
                
                if ($DryRun) {
                    Write-Host "Would renumber DDS: '$($dds.Name)' -> '$newDdsName'"
                    Write-Host "  Container expects: $expectedNumber, DDS contains: $ddsCurrentNumber"
                } else {
                    Write-Host "Container/Content mismatch - Renumbering DDS: '$($dds.Name)' -> '$newDdsName'"
                    Write-Host "  Container expects: $expectedNumber, DDS contains: $ddsCurrentNumber"
                }
                
                if ($Execute) {
                    $oldPath = $dds.FullName
                    $newPath = Join-Path $tpfExtractDir $newDdsName
                    if (Test-Path $newPath) { Remove-Item $newPath -Force }
                    Rename-Item -Path $oldPath -NewName $newDdsName -Force
                    $ddsRenamed = $true
                    $renamedFiles += @{
                        OldName = $dds.Name
                        NewName = $newDdsName
                    }
                    Write-VerboseLog -message "Renamed DDS: $($dds.Name) -> $newDdsName" -logFile $logFile
                }
            } else {
                if ($DryRun) {
                    Write-Host "DDS numbering matches container - no renaming needed: '$($dds.Name)'"
                } else {
                    Write-Host "DDS numbering matches container - no renaming needed: '$($dds.Name)'"
                }
            }
        }
    }
    
    return @{
        Renumbered = $ddsRenamed
        RenamedFiles = $renamedFiles
    }
}

function Update-BndXmlReferences {
    param(
        [string]$bndXmlFile,
        [array]$renamedFiles,
        [string]$logFile,
        [switch]$Execute,
        [switch]$DryRun
    )
    
    if (-not (Test-Path $bndXmlFile)) {
        Write-VerboseLog -message "BND XML file not found: $bndXmlFile" -logFile $logFile
        return $false
    }
    
    if ($renamedFiles.Count -eq 0) {
        Write-VerboseLog -message "No files were renamed, skipping BND XML update" -logFile $logFile
        return $false
    }
    
    $bndXmlContent = Get-Content $bndXmlFile -Raw
    $newBndXml = $bndXmlContent
    $hasChanges = $false
    
    foreach ($renamedFile in $renamedFiles) {
        $oldName = $renamedFile.OldName
        $newName = $renamedFile.NewName
        
        $updatedXml = $newBndXml -replace [regex]::Escape($oldName), $newName
        if ($updatedXml -ne $newBndXml) {
            $hasChanges = $true
            $newBndXml = $updatedXml
            
            if ($DryRun) {
                Write-Host "Would update BND4 XML reference: '$oldName' -> '$newName'"
            } else {
                Write-Host "Updating BND4 XML references: '$oldName' -> '$newName'"
            }
            Write-VerboseLog -message "Updated BND XML reference: $oldName -> $newName" -logFile $logFile
        }
    }
    
    if ($hasChanges -and $Execute) {
        $newBndXml | Set-Content -Path $bndXmlFile -Encoding UTF8 -NoNewline
        Write-VerboseLog -message "Updated BND XML file: $bndXmlFile" -logFile $logFile
    }
    
    return $hasChanges
}

function Update-TpfXmlReferences {
    param(
        [string]$tpfExtractDir,
        [array]$renamedFiles,
        [string]$expectedNumber,
        [string]$logFile,
        [switch]$Execute,
        [switch]$DryRun
    )
    
    if ($renamedFiles.Count -eq 0) {
        return $false
    }
    
    # Find XML files in TPF directory
    $xmlFiles = Get-ChildItem -Path $tpfExtractDir -Filter '*-tpf.xml' -File
    if ($xmlFiles.Count -eq 0) {
        $xmlFiles = Get-ChildItem -Path $tpfExtractDir -Filter 'witchy-tpf.xml' -File
    }
    if ($xmlFiles.Count -eq 0) {
        $xmlFiles = Get-ChildItem -Path $tpfExtractDir -Filter '_witchy-tpf.xml' -File
    }
    
    $hasChanges = $false
    foreach ($xml in $xmlFiles) {
        $xmlContent = Get-Content $xml.FullName -Raw
        
        # Update XML references to match the new DDS filenames
        $newXml = $xmlContent -replace '<n>([A-Z]+_[A-Z]+)_[0-9]+([^<>]+\.dds)<\/n>', "<n>`$1_${expectedNumber}`$2</n>"
        
        if ($newXml -ne $xmlContent) {
            $hasChanges = $true
            if ($DryRun) {
                Write-Host "Would update XML references: '$($xml.Name)' (updating DDS references to $expectedNumber)"
            } else {
                Write-Host "Updating XML references: '$($xml.Name)' (updating DDS references to $expectedNumber)"
            }
            Write-VerboseLog -message "TPF XML update: $($xml.Name) (Number: $expectedNumber)" -logFile $logFile
            
            if ($Execute) {
                $newXml | Set-Content -Path $xml.FullName -Encoding UTF8 -NoNewline
            }        } else {
            if (-not $DryRun) {
                Write-Host "XML file '$($xml.Name)' already has correct references"
            }
        }
    }
    
    return $hasChanges
}

# Export functions that should be available to scripts
Export-ModuleMember -Function @(
    'Timestamp',
    'Write-LogMessage', 
    'Write-VerboseLog',
    'Test-TpfEmpty',
    'Test-TpfValid',
    'Invoke-TpfRepack',
    'Remove-ExtractedDir',
    'Invoke-FileRenumbering',
    'Invoke-DdsRenumbering',
    'Update-BndXmlReferences',
    'Update-TpfXmlReferences'
)
