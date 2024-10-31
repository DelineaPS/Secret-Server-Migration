# File Migration Script

This script is designed to facilitate the migration of files from one location to another. Below are the details on how to use the script, including the required arguments and examples.

## Arguments

- **SourcePath**: The path to the source directory containing the files to be migrated.
- **DestinationPath**: The path to the destination directory where the files will be moved.
- **LogFilePath**: (Optional) The path to the log file where the script's operations will be recorded.

## Usage

```powershell
.\FileMigration.ps1 -SourcePath "C:\SourceDirectory" -DestinationPath "D:\DestinationDirectory" [-LogFilePath "C:\Logs\MigrationLog.txt"]
```

## Examples

### Example 1: Basic Usage

```powershell
.\FileMigration.ps1 -SourcePath "C:\SourceDirectory" -DestinationPath "D:\DestinationDirectory"
```

### Example 2: With Log File

```powershell
.\FileMigration.ps1 -SourcePath "C:\SourceDirectory" -DestinationPath "D:\DestinationDirectory" -LogFilePath "C:\Logs\MigrationLog.txt"
```

## Notes

- Ensure that you have the necessary permissions to read from the source directory and write to the destination directory.
- If the log file path is not provided, the script will not generate a log file.