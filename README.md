# Terraform AWS Infrastructure Practice

## 概要

Terraformを使用してAWS上にWebサーバー環境を構築しました。

本構成では、VPC・Subnet・Internet Gateway・Route Table・Security Group・EC2・IAM Role・Systems Manager Session Manager・S3を利用し、SSHを使用せずにサーバーへ接続できる構成を実現しています。

また、Session Managerの操作ログをS3へ保存することで、監査ログの取得も可能としています。

---

## 構成図

<img width="768" height="1343" alt="Image" src="https://github.com/user-attachments/assets/6c0a273a-fd71-4988-adee-1cadfc533439" />
---

## 使用サービス

* Terraform
* Amazon VPC
* Amazon EC2
* IAM
* AWS Systems Manager
* Amazon S3

---

## 実装内容

### ネットワーク

* VPC作成
* Public Subnet作成
* Internet Gateway作成
* Route Table作成
* Route Table Association設定

### サーバー

* Amazon Linux 2023を利用
* Apache(httpd)自動インストール
* user_dataによる初期設定

### セキュリティ

* Security Groupによる通信制御
* IAM Roleによる権限管理
* Session Managerによる接続
* SSHポートを利用しない運用

### 運用

* Session ManagerログをS3へ保存
* Terraformによるコード管理

---

## 学習を通じて得た知見

* Terraformの依存関係の理解
* IAM RoleとInstance Profileの違い
* Systems Manager Session Managerの仕組み
* S3アクセス権限設計
* Terraform state管理
* Terraform planの差分確認方法

---

## 発生したトラブルと解決内容

### IAM権限不足

発生事象

* iam:CreateRole
* s3:CreateBucket

などの権限不足によりTerraform Applyが失敗

対応

* 必要なIAM権限を調査
* 最小権限の考え方を学習

### Session Manager接続失敗

発生事象

* TargetNotConnected
* AccessDenied

対応

* AmazonSSMManagedInstanceCoreを付与
* Instance Profileを設定

### S3ログ保存失敗

発生事象

* GetEncryptionConfiguration権限不足

対応

* IAMポリシーを修正
* S3ログ出力を実現

---

## 今後の改善予定

* ALB追加
* EC2複数台構成
* Auto Scaling Group
* CloudWatch監視
* Terraform Module化
* Private Subnet構成
