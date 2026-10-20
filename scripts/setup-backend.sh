#!/bin/bash
set -e
ENV=$1                      # dev or prod
REGION="us-east-2"
BUCKET="tf-drift-state-${ENV}-$(aws sts get-caller-identity --query Account --output text)"
TABLE="tf-drift-lock-${ENV}"

aws s3api create-bucket --bucket "$BUCKET" --region $REGION --create-bucket-configuration LocationConstraint=$REGION
aws s3api put-bucket-versioning --bucket "$BUCKET" \
  --versioning-configuration Status=Enabled
#!/bin/bash
set -e

ENV=$1
if [ -z "$ENV" ]; then
  echo "Usage: ./scripts/setup-backend.sh <dev|prod>"
  exit 1
fi

REGION="us-east-2"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET="tf-drift-state-${ENV}-${ACCOUNT_ID}"
TABLE="tf-drift-lock-${ENV}"

echo "Creating S3 bucket: $BUCKET"
aws s3api create-bucket --bucket "$BUCKET" --region $REGION --create-bucket-configuration LocationConstraint=$REGION

echo "Enabling versioning"
aws s3api put-bucket-versioning --bucket "$BUCKET" \
  --versioning-configuration Status=Enabled

echo "Enabling encryption"
aws s3api put-bucket-encryption --bucket "$BUCKET" \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

echo "Blocking public access"
aws s3api put-public-access-block --bucket "$BUCKET" \
  --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

echo "Creating DynamoDB lock table: $TABLE"
aws dynamodb create-table --table-name "$TABLE" \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST --region $REGION

echo ""
echo "Done. Use these values in backend-${ENV}.hcl:"
echo "  bucket         = \"$BUCKET\""
echo "  dynamodb_table = \"$TABLE\""
