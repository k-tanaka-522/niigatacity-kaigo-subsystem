# 基本設計・詳細設計のファイル名を日本語化するスクリプト
# 実行方法: PowerShell で scripts/rename-design-docs.ps1

$ErrorActionPreference = "Stop"

Write-Host "=== 基本設計・詳細設計ファイル名の日本語化 ===" -ForegroundColor Green
Write-Host ""

# ベースディレクトリ
$baseDir = "C:\dev2\niigatacity-kaigo-subsystem\docs\02_design"

# ファイル名変更マッピング
$renameMap = @{
    # 01_概要
    "$baseDir\基本設計\01_概要\overview.md" = "$baseDir\基本設計\01_概要\概要.md"

    # 02_アカウント構成
    "$baseDir\基本設計\02_アカウント構成\account_design.md" = "$baseDir\基本設計\02_アカウント構成\アカウント設計.md"

    # 03_ネットワーク
    "$baseDir\基本設計\03_ネットワーク\network_design.md" = "$baseDir\基本設計\03_ネットワーク\ネットワーク設計.md"
    "$baseDir\基本設計\03_ネットワーク\vpc_parameters.md" = "$baseDir\基本設計\03_ネットワーク\VPCパラメータ.md"
    "$baseDir\基本設計\03_ネットワーク\transit_gateway_parameters.md" = "$baseDir\基本設計\03_ネットワーク\TransitGatewayパラメータ.md"

    # 04_コンピューティング
    "$baseDir\基本設計\04_コンピューティング\compute_design.md" = "$baseDir\基本設計\04_コンピューティング\コンピューティング設計.md"
    "$baseDir\基本設計\04_コンピューティング\ecs_parameters.md" = "$baseDir\基本設計\04_コンピューティング\ECSパラメータ.md"
    "$baseDir\基本設計\04_コンピューティング\alb_parameters.md" = "$baseDir\基本設計\04_コンピューティング\ALBパラメータ.md"

    # 05_データベース
    "$baseDir\基本設計\05_データベース\database_design.md" = "$baseDir\基本設計\05_データベース\データベース設計.md"
    "$baseDir\基本設計\05_データベース\rds_parameters.md" = "$baseDir\基本設計\05_データベース\RDSパラメータ.md"
    "$baseDir\基本設計\05_データベース\elasticache_parameters.md" = "$baseDir\基本設計\05_データベース\ElastiCacheパラメータ.md"

    # 06_ストレージ
    "$baseDir\基本設計\06_ストレージ\storage_design.md" = "$baseDir\基本設計\06_ストレージ\ストレージ設計.md"

    # 07_セキュリティ
    "$baseDir\基本設計\07_セキュリティ\security_design.md" = "$baseDir\基本設計\07_セキュリティ\セキュリティ設計.md"
    "$baseDir\基本設計\07_セキュリティ\security_group_rules.md" = "$baseDir\基本設計\07_セキュリティ\セキュリティグループルール.md"

    # 08_監視ロギング
    "$baseDir\基本設計\08_監視ロギング\monitoring_design.md" = "$baseDir\基本設計\08_監視ロギング\監視設計.md"
    "$baseDir\基本設計\08_監視ロギング\cloudwatch_alarms.md" = "$baseDir\基本設計\08_監視ロギング\CloudWatchアラーム.md"

    # 09_バックアップDR
    "$baseDir\基本設計\09_バックアップDR\backup_dr_design.md" = "$baseDir\基本設計\09_バックアップDR\バックアップDR設計.md"

    # 詳細設計/01_VPC詳細
    "$baseDir\詳細設計\01_VPC詳細\vpc_detailed_design.md" = "$baseDir\詳細設計\01_VPC詳細\VPC詳細設計.md"
    "$baseDir\詳細設計\01_VPC詳細\subnet_allocation.md" = "$baseDir\詳細設計\01_VPC詳細\サブネット割り当て.md"
    "$baseDir\詳細設計\01_VPC詳細\route_table_config.md" = "$baseDir\詳細設計\01_VPC詳細\ルートテーブル設定.md"

    # 詳細設計/02_TransitGateway詳細
    "$baseDir\詳細設計\02_TransitGateway詳細\tgw_detailed_design.md" = "$baseDir\詳細設計\02_TransitGateway詳細\TransitGateway詳細設計.md"

    # 詳細設計/07_Cognito詳細
    "$baseDir\詳細設計\07_Cognito詳細\cognito_design.md" = "$baseDir\詳細設計\07_Cognito詳細\Cognito設計.md"
    "$baseDir\詳細設計\07_Cognito詳細\cognito_parameters.md" = "$baseDir\詳細設計\07_Cognito詳細\Cognitoパラメータ.md"

    # 詳細設計/10_CloudFormation
    "$baseDir\詳細設計\10_CloudFormation\cloudformation_design.md" = "$baseDir\詳細設計\10_CloudFormation\CloudFormation設計.md"
}

# 削除対象ファイル
$deleteFiles = @(
    "$baseDir\基本設計\02_アカウント構成\account_diagram.md"
    "$baseDir\基本設計\03_ネットワーク\network_diagram.md"
    "$baseDir\基本設計\08_監視ロギング\monitoring_flow.md"
    "$baseDir\基本設計\09_バックアップDR\backup_flow.md"
    "$baseDir\基本設計\09_バックアップDR\dr_procedure.md"
    "$baseDir\基本設計\10_architecture_diagrams\README.md"
    "$baseDir\基本設計\10_architecture_diagrams\overall_architecture.md"
    "$baseDir\基本設計\10_architecture_diagrams\network_diagram.md"
    "$baseDir\基本設計\10_architecture_diagrams\dataflow_diagram.md"
)

# ファイル名変更処理
Write-Host "1. ファイル名を変更中..." -ForegroundColor Cyan
$renameCount = 0

foreach ($key in $renameMap.Keys) {
    $oldPath = $key
    $newPath = $renameMap[$key]

    if (Test-Path $oldPath) {
        try {
            Move-Item -Path $oldPath -Destination $newPath -Force
            Write-Host "  ✓ $oldPath" -ForegroundColor Green
            Write-Host "    → $newPath" -ForegroundColor Green
            $renameCount++
        }
        catch {
            Write-Host "  ✗ エラー: $oldPath" -ForegroundColor Red
            Write-Host "    $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    else {
        Write-Host "  - スキップ（ファイルが存在しません）: $oldPath" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "2. 不要なファイルを削除中..." -ForegroundColor Cyan
$deleteCount = 0

foreach ($file in $deleteFiles) {
    if (Test-Path $file) {
        try {
            Remove-Item -Path $file -Force
            Write-Host "  ✓ 削除: $file" -ForegroundColor Green
            $deleteCount++
        }
        catch {
            Write-Host "  ✗ エラー: $file" -ForegroundColor Red
            Write-Host "    $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    else {
        Write-Host "  - スキップ（ファイルが存在しません）: $file" -ForegroundColor Yellow
    }
}

# 10_architecture_diagrams ディレクトリの削除
$archDiagramsDir = "$baseDir\基本設計\10_architecture_diagrams"
if (Test-Path $archDiagramsDir) {
    try {
        Remove-Item -Path $archDiagramsDir -Recurse -Force
        Write-Host "  ✓ ディレクトリ削除: $archDiagramsDir" -ForegroundColor Green
    }
    catch {
        Write-Host "  ✗ エラー: $archDiagramsDir" -ForegroundColor Red
        Write-Host "    $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "=== 完了 ===" -ForegroundColor Green
Write-Host "変更したファイル数: $renameCount" -ForegroundColor Cyan
Write-Host "削除したファイル数: $deleteCount" -ForegroundColor Cyan
Write-Host ""
Write-Host "次のステップ:" -ForegroundColor Yellow
Write-Host "1. draw.io図を作成してください（docs/02_design/基本設計/01_概要/draw.io図作成ガイド.md 参照）" -ForegroundColor Yellow
Write-Host "2. 作成した図を各ディレクトリに配置してください" -ForegroundColor Yellow
