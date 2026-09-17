#!/usr/bin/env python3
"""
Guardian AWS Infrastructure Setup Script
Provisions all required AWS resources for the Guardian app:
  - DynamoDB tables: guardian-users, guardian-incidents, guardian-incident-events
  - SNS Topic: guardian-community-sos (for community broadcast)
  - Cognito User Pool: guardian-users (phone OTP auth)

Run this ONCE to set up your AWS backend:
  python aws/setup_aws.py

Requirements:
  - AWS CLI configured (aws configure) OR .env with AWS_ACCESS_KEY_ID/SECRET
  - pip install boto3 python-dotenv
"""

import os
import sys
import json
from pathlib import Path

# Load .env
try:
    from dotenv import load_dotenv
    env_path = Path(__file__).resolve().parent / ".env"
    if env_path.exists():
        load_dotenv(dotenv_path=env_path)
    else:
        load_dotenv()
except ImportError:
    print("⚠  python-dotenv not found. Run: pip install python-dotenv")

try:
    import boto3
    from botocore.exceptions import ClientError
except ImportError:
    print("❌ boto3 not installed. Run: pip install boto3")
    sys.exit(1)

REGION = os.environ.get("AWS_DEFAULT_REGION", "ap-south-1")
print(f"\n🚀 Guardian AWS Setup — Region: {REGION}\n")


def get_account_id():
    sts = boto3.client("sts", region_name=REGION)
    return sts.get_caller_identity()["Account"]


# ─────────────────────────────────────────────────────────────────────────────
# DYNAMODB TABLES
# ─────────────────────────────────────────────────────────────────────────────

def create_dynamodb_tables():
    dynamo = boto3.client("dynamodb", region_name=REGION)
    print("📦 Setting up DynamoDB tables...")

    tables = [
        {
            "TableName": "guardian-users",
            "KeySchema": [{"AttributeName": "user_id", "KeyType": "HASH"}],
            "AttributeDefinitions": [{"AttributeName": "user_id", "AttributeType": "S"}],
            "BillingMode": "PAY_PER_REQUEST",
            "Tags": [{"Key": "app", "Value": "guardian"}],
        },
        {
            "TableName": "guardian-incidents",
            "KeySchema": [{"AttributeName": "incident_id", "KeyType": "HASH"}],
            "AttributeDefinitions": [{"AttributeName": "incident_id", "AttributeType": "S"}],
            "BillingMode": "PAY_PER_REQUEST",
            "Tags": [{"Key": "app", "Value": "guardian"}],
        },
        {
            "TableName": "guardian-incident-events",
            "KeySchema": [
                {"AttributeName": "incident_id", "KeyType": "HASH"},
                {"AttributeName": "timestamp", "KeyType": "RANGE"},
            ],
            "AttributeDefinitions": [
                {"AttributeName": "incident_id", "AttributeType": "S"},
                {"AttributeName": "timestamp", "AttributeType": "S"},
            ],
            "BillingMode": "PAY_PER_REQUEST",
            "Tags": [{"Key": "app", "Value": "guardian"}],
        },
    ]

    created = []
    for table_def in tables:
        name = table_def["TableName"]
        try:
            dynamo.create_table(**table_def)
            print(f"  ✅ Created table: {name}")
            created.append(name)
        except ClientError as e:
            if e.response["Error"]["Code"] == "ResourceInUseException":
                print(f"  ℹ️  Table already exists: {name}")
            else:
                print(f"  ❌ Failed to create {name}: {e}")

    return created


# ─────────────────────────────────────────────────────────────────────────────
# SNS TOPICS
# ─────────────────────────────────────────────────────────────────────────────

def create_sns_topics():
    sns = boto3.client("sns", region_name=REGION)
    print("\n📣 Setting up SNS Topics...")

    topics = {
        "guardian-community-sos": "Community SOS broadcast topic",
        "guardian-contact-alerts": "Trusted contact emergency alerts",
    }

    arns = {}
    for name, desc in topics.items():
        try:
            resp = sns.create_topic(
                Name=name,
                Tags=[
                    {"Key": "app", "Value": "guardian"},
                    {"Key": "description", "Value": desc},
                ],
            )
            arn = resp["TopicArn"]
            arns[name] = arn
            print(f"  ✅ SNS Topic: {name}")
            print(f"     ARN: {arn}")
        except ClientError as e:
            print(f"  ❌ Failed to create topic {name}: {e}")

    return arns


# ─────────────────────────────────────────────────────────────────────────────
# COGNITO USER POOL
# ─────────────────────────────────────────────────────────────────────────────

def create_cognito_user_pool():
    cognito = boto3.client("cognito-idp", region_name=REGION)
    print("\n🔐 Setting up AWS Cognito User Pool...")

    pool_name = "guardian-users"

    # Check if pool already exists
    try:
        pools = cognito.list_user_pools(MaxResults=60)["UserPools"]
        existing = next((p for p in pools if p["Name"] == pool_name), None)
        if existing:
            pool_id = existing["Id"]
            print(f"  ℹ️  User pool already exists: {pool_id}")
        else:
            # Create User Pool with phone number sign-in
            resp = cognito.create_user_pool(
                PoolName=pool_name,
                UsernameAttributes=["phone_number"],
                AutoVerifiedAttributes=["phone_number"],
                MfaConfiguration="OPTIONAL",
                SmsAuthenticationMessage="Your Guardian verification code is {####}",
                SmsConfiguration={
                    # You need an IAM role for Cognito to send SMS via SNS
                    # Will be shown in output — create it in AWS Console if needed
                    "SnsCallerArn": f"arn:aws:iam::{get_account_id()}:role/CognitoSNSRole",
                    "ExternalId": "guardian-cognito-external",
                },
                Policies={
                    "PasswordPolicy": {
                        "MinimumLength": 8,
                        "RequireUppercase": True,
                        "RequireLowercase": True,
                        "RequireNumbers": True,
                        "RequireSymbols": True,
                        "TemporaryPasswordValidityDays": 7,
                    }
                },
                Schema=[
                    {
                        "Name": "phone_number",
                        "AttributeDataType": "String",
                        "Required": True,
                        "Mutable": True,
                    },
                    {
                        "Name": "name",
                        "AttributeDataType": "String",
                        "Required": False,
                        "Mutable": True,
                    },
                ],
                UserPoolTags={"app": "guardian"},
            )
            pool_id = resp["UserPool"]["Id"]
            print(f"  ✅ Created Cognito User Pool: {pool_id}")

        # Create App Client
        try:
            clients = cognito.list_user_pool_clients(UserPoolId=pool_id, MaxResults=60)["UserPoolClients"]
            existing_client = next((c for c in clients if c["ClientName"] == "guardian-mobile-app"), None)

            if existing_client:
                client_id = existing_client["ClientId"]
                print(f"  ℹ️  App client already exists: {client_id}")
            else:
                client_resp = cognito.create_user_pool_client(
                    UserPoolId=pool_id,
                    ClientName="guardian-mobile-app",
                    GenerateSecret=False,  # Set True if you want client secret
                    ExplicitAuthFlows=[
                        "ALLOW_CUSTOM_AUTH",
                        "ALLOW_USER_SRP_AUTH",
                        "ALLOW_REFRESH_TOKEN_AUTH",
                    ],
                    PreventUserExistenceErrors="ENABLED",
                    EnableTokenRevocation=True,
                    TokenValidityUnits={
                        "AccessToken": "hours",
                        "IdToken": "hours",
                        "RefreshToken": "days",
                    },
                    AccessTokenValidity=1,
                    IdTokenValidity=1,
                    RefreshTokenValidity=30,
                )
                client_id = client_resp["UserPoolClient"]["ClientId"]
                print(f"  ✅ Created App Client: {client_id}")

            return {"pool_id": pool_id, "client_id": client_id}

        except ClientError as e:
            print(f"  ❌ App client error: {e}")
            return {"pool_id": pool_id, "client_id": None}

    except ClientError as e:
        err = e.response["Error"]["Code"]
        if "InvalidParameter" in err and "SnsCallerArn" in str(e):
            print(f"""
  ⚠️  Cognito SMS requires an IAM role. Create it manually in AWS Console:
    1. Go to IAM → Roles → Create Role
    2. Choose: AWS Service → Cognito
    3. Name it: CognitoSNSRole
    4. Attach policy: AmazonSNSFullAccess (or SNS:Publish)
    5. Then re-run this script.
    
  Alternatively, use CUSTOM_AUTH flow with your own OTP lambda.
""")
        else:
            print(f"  ❌ Cognito error: {e}")
        return {}


# ─────────────────────────────────────────────────────────────────────────────
# WRITE .ENV
# ─────────────────────────────────────────────────────────────────────────────

def write_env_file(cognito_result, sns_arns, account_id):
    env_path = Path(__file__).resolve().parent / ".env"

    pool_id = cognito_result.get("pool_id", "CONFIGURE_IN_AWS_CONSOLE")
    client_id = cognito_result.get("client_id", "CONFIGURE_IN_AWS_CONSOLE")
    sos_arn = sns_arns.get("guardian-community-sos", "")

    existing_content = ""
    if env_path.exists():
        existing_content = env_path.read_text()

    # Only update if values are new
    new_lines = []
    if "COGNITO_USER_POOL_ID=" not in existing_content:
        new_lines.append(f"COGNITO_USER_POOL_ID={pool_id}")
    if "COGNITO_CLIENT_ID=" not in existing_content:
        new_lines.append(f"COGNITO_CLIENT_ID={client_id}")
    if "SNS_SOS_TOPIC_ARN=" not in existing_content and sos_arn:
        new_lines.append(f"SNS_SOS_TOPIC_ARN={sos_arn}")

    if new_lines:
        with open(env_path, "a") as f:
            f.write("\n# Auto-generated by setup_aws.py\n")
            for line in new_lines:
                f.write(f"{line}\n")
        print(f"\n✅ Updated {env_path} with new values")
    else:
        print(f"\nℹ️  {env_path} already configured — no changes needed")


# ─────────────────────────────────────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────────────────────────────────────

def main():
    print("=" * 60)
    print("   GUARDIAN — AWS Infrastructure Setup")
    print("=" * 60)

    try:
        account_id = get_account_id()
        print(f"✅ AWS Account ID: {account_id}")
        print(f"✅ Region: {REGION}\n")
    except Exception as e:
        print(f"❌ AWS credentials not configured: {e}")
        print("\nPlease run: aws configure")
        print("Or set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY in aws/.env")
        sys.exit(1)

    # 1. DynamoDB
    create_dynamodb_tables()

    # 2. SNS Topics
    sns_arns = create_sns_topics()

    # 3. Cognito
    cognito_result = create_cognito_user_pool()

    # 4. Update .env
    write_env_file(cognito_result, sns_arns, account_id)

    print("\n" + "=" * 60)
    print("🎉 Setup Complete!")
    print("=" * 60)
    print("""
Next Steps:
  1. Copy your Cognito Pool ID and Client ID to aws/.env
  2. For SNS push notifications:
     a) Create SNS Platform Application for Android (FCM/GCM)
     b) Create SNS Platform Application for iOS (APNS)
     c) Add SNS_FCM_PLATFORM_ARN and SNS_APNS_PLATFORM_ARN to aws/.env
  3. Start the backend:
     python aws/server.py
  4. Run Flutter:
     flutter run -d chrome --dart-define=AWS_API_ENDPOINT=http://localhost:8000

See aws/.env.example for all configuration options.
""")


if __name__ == "__main__":
    main()
