# Cleanup_duplicate_Secrets.ps1

## Overview
`Cleanup_duplicate_Secrets.ps1` is a PowerShell script designed to identify and clean up duplicate secrets in your Secret Server environment.

## Prerequisites
- PowerShell 7 or later
- Secret Server Powershell Module
- Secret Server API access
- Appropriate permissions to read and delete secrets

## Usage
1. Run the script:
    ```sh
    .\Cleanup_duplicate_Secrets.ps1
    ```

## Parameters
- `-ApiUrl`: The URL of the Secret Server API.
- `-Username`: The username for API authentication.
- `-Password`: The password for API authentication.

Example:
```sh
.\Cleanup_duplicate_Secrets.ps1 -ApiUrl "https://your-secret-server/api" -Username "admin" -Password "password"
```

## Notes
- Ensure you have a backup of your secrets before running the script.
- Test the script in a development environment before using it in production.

## License
This project is licensed under the MIT License.

## Contributing
Contributions are welcome! Please submit a pull request or open an issue to discuss your changes.
