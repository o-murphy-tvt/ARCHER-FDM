

# Встановіть папку-джерело, з якої потрібно копіювати файли
$sourceFolder = ".\"

# Функція для отримання всіх підключених USB-дисків
function Get-USBDrives {
    Get-WmiObject Win32_LogicalDisk | Where-Object { $_.DriveType -eq 2 }
}

# Початковий список підключених USB-дисків
$existingDrives = Get-USBDrives | ForEach-Object { $_.DeviceID }
Write-Host "Found drives: {$existingDrives}"
    
# foreach ($drive in $existingDrives) {
#     Write-Host "Flushing: $drive"
    
#     # Копіювання файлів на новий диск
#     try {
#         Copy-Item -Path "$sourceFolder\*" -Destination "$drive\" -Recurse -Force
#         Remove-Item -Path "$drive\flush.ps1" -Force
#         Write-Host "Files copied to $drive successfully."
#     } catch {
#         Write-Host "Error copying files to ${drive}: $_"
#     }
# }

# # Оновлення списку вже підключених дисків
# $existingDrives = $currentDrives

# # Очікування перед наступною перевіркою (затримка 5 секунд)
# Start-Sleep -Seconds 5

# Запуск паралельного копіювання для кожного диска
$jobs = @() # Масив для збереження Job'ів
foreach ($drive in $existingDrives) {
    Write-Host "Starting job for drive: $drive"

    # Створення нового Job'у
    $job = Start-Job -ScriptBlock {
        param ($source, $destination)

        # Перевірка на існування папки-джерела
        if (!(Test-Path -Path $source)) {
            Write-Host "Error: Source folder '$source' does not exist."
            return
        }

        Write-Host "Copying from {$source}"
        Get-ChildItem $source

        try {
            # Копіювання файлів
            Copy-Item -Path "$source\*" -Destination "$destination\" -Recurse -Force

            # Видалення скрипта з USB-диска
            Remove-Item -Path "$destination\flush.ps1" -Force -ErrorAction SilentlyContinue
            Remove-Item -Path "$destination\eject.exe" -Force -ErrorAction SilentlyContinue
            
            Write-Host "Files copied to $destination successfully."

            # Invoke-Expression "$source\eject.exe -e $destination"
            Start-Process "$source\eject.exe" -ArgumentList "-e $destination" -PassThru -Wait
        } catch {
            Write-Host "Error copying files to {$destination}: $_"
        }
    } -ArgumentList (Resolve-Path $sourceFolder).Path, $drive

    # Додавання Job'у до масиву
    $jobs += $job
}

# Очікування завершення всіх Job'ів
Write-Host "Waiting for all copy jobs to complete..."
$jobs | ForEach-Object { Receive-Job -Job $_ -Wait }
Write-Host "All jobs completed."