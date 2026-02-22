#!/bin/bash
set -e

# Usage check
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <S3_BUCKET> <EMR_CLUSTER_ID>"
    exit 1
fi

BUCKET=$1
CLUSTER_ID=$2

echo "--- Using Bucket: $BUCKET ---"
echo "--- Using Cluster ID: $CLUSTER_ID ---"

# Ensure dependencies are installed
if ! python3 -c "import pandas, boto3, numpy" 2>/dev/null; then
    echo "Installing python dependencies..."
    pip install pandas boto3 numpy
fi

# Run workflows based on environment variables
if [ "$RUN_SIMPLE" == "true" ]; then
    ./scripts/simple/deploy.sh "$BUCKET" "$CLUSTER_ID"
fi

if [ "$RUN_INTENSIVE" == "true" ]; then
    ./scripts/intensive/deploy.sh "$BUCKET" "$CLUSTER_ID"
fi

if [ "$RUN_LOGS" == "true" ]; then
    ./scripts/logs/deploy.sh "$BUCKET" "$CLUSTER_ID"
fi

echo "=========================================="
echo "Workflow Submission Complete!"
echo "Cluster ID: $CLUSTER_ID"
echo "You can monitor the steps in the AWS Console or via CLI:"
echo "aws emr list-steps --cluster-id $CLUSTER_ID"
echo "=========================================="