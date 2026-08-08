# =============================================================================
# Windows PowerShell Remote Deployer for Excalidraw on AWS EC2
# Target Domain: draw.pixara.online (Elastic IP: 13.60.225.36)
# =============================================================================

param (
    [string]$ServerIP = "13.60.225.36",
    [string]$User = "ubuntu",
    [string]$KeyPath = "$env:USERPROFILE\.ssh\id_rsa_ec2"
)

Write-Host "====================================================================" -ForegroundColor Cyan
Write-Host "EXCALIDRAW REMOTE EC2 DEPLOYER (PowerShell)" -ForegroundColor Cyan
Write-Host "Target Server: $User@$ServerIP (draw.pixara.online)" -ForegroundColor Cyan
Write-Host "====================================================================" -ForegroundColor Cyan

$LocalRepoDir = "V:\projects\excalidraw\excalidraw"

if (-not (Test-Path $KeyPath)) {
    Write-Host "SSH key not found at $KeyPath. Trying default ssh command..." -ForegroundColor Yellow
    $SSHCmd = "ssh $User@$ServerIP"
    $SCPCmd = "scp -r"
} else {
    Write-Host "Using SSH Key: $KeyPath" -ForegroundColor Green
    $SSHCmd = "ssh -i `"$KeyPath`" -o StrictHostKeyChecking=no $User@$ServerIP"
    $SCPCmd = "scp -i `"$KeyPath`" -o StrictHostKeyChecking=no -r"
}

# 1. Sync local repository changes to the EC2 server directory
Write-Host "`n1. Copying updated deployment and codebase files to EC2 server ($ServerIP)..." -ForegroundColor Yellow
# We copy to the temp folder first to prevent permission issues, then move it to /opt/excalidraw/repo
Invoke-Expression "$SCPCmd `"$LocalRepoDir`" ${User}@${ServerIP}:~/"

# 2. Update the repository files and run deployment script
Write-Host "`n2. Executing deployment and container rebuild on EC2 server..." -ForegroundColor Yellow
$RemoteCommand = "sudo rm -rf /opt/excalidraw/repo.bak && " +
                 "sudo mv /opt/excalidraw/repo /opt/excalidraw/repo.bak && " +
                 "sudo mv ~/excalidraw /opt/excalidraw/repo && " +
                 "sudo chown -R ubuntu:ubuntu /opt/excalidraw/repo && " +
                 "cd /opt/excalidraw/repo && " +
                 "bash deploy/deploy.sh"

Invoke-Expression "$SSHCmd `"$RemoteCommand`""

Write-Host "`n====================================================================" -ForegroundColor Green
Write-Host "DEPLOYMENT PROCESS COMPLETE!" -ForegroundColor Green
Write-Host "Please refresh draw.pixara.online and test the shareable link!" -ForegroundColor Green
Write-Host "====================================================================" -ForegroundColor Green
