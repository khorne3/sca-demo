#!/bin/sh

#### Review script environment variables and set defaults
if [ ! -n "$SHIFTLEFT_APP_NAME" ]; then
  SHIFTLEFT_APP_NAME="$BITBUCKET_REPO_SLUG-ML-PR"
fi

if [ ! -n "$SHIFTLEFT_APP_PATH" ]; then
  echo "Missing Environment Variable: \$SHIFTLEFT_APP_PATH"
  exit 1
fi

echo "BITBUCKET_COMMIT=        \"$BITBUCKET_COMMIT\""
echo "BITBUCKET_BRANCH=        \"$BITBUCKET_BRANCH\""
echo "BITBUCKET_PR_ID=         \"$BITBUCKET_PR_ID\""
echo "BITBUCKET_REPO_FULL_NAME=\"$BITBUCKET_REPO_FULL_NAME\""
echo "BITBUCKET_REPO_SLUG=     \"$BITBUCKET_REPO_SLUG\""
echo "BITBUCKET_WORKSPACE=     \"$BITBUCKET_WORKSPACE\""
echo "SHIFTLEFT_APP_NAME=      \"$SHIFTLEFT_APP_NAME\""
echo "SHIFTLEFT_APP_PATH=      \"$SHIFTLEFT_APP_PATH\""

SHIFTLEFT_ORG_ID="d64f2e4d-0d32-4c0b-bdae-891f693e2399"

#### Analyze code
echo "Starting NG SAST..."

sl analyze \
  --app "$SHIFTLEFT_APP_NAME" \
  --version-id "$BITBUCKET_COMMIT" \
  --tag branch="$BITBUCKET_BRANCH" \
  --java \
  "$SHIFTLEFT_APP_PATH"

#### Run build rules
# Check if this is running in a merge request
if [ -n "$BITBUCKET_PR_ID" ]; then
  echo "Pull request $BITBUCKET_PR_ID issued for branch $BITBUCKET_BRANCH"

# Run the build rules check 
URL="https://www.shiftleft.io/findingsSummary/$SHIFTLEFT_APP_NAME?apps=$SHIFTLEFT_APP_NAME&isApp=1"
BUILDRULECHECK=$(sl check-analysis --app "$SHIFTLEFT_APP_NAME" --config ~/shiftleft.yml --report --report-file /tmp/check-analysis.md)

# Set up comment body for the merge request
COMMENT_BODY='{"raw":""}'
COMMENT_BODY=$(echo "$COMMENT_BODY" | jq '.raw += "## NG SAST Analysis Findings \n "')

NEW_FINDINGS=$(curl -H "Authorization: Bearer $SHIFTLEFT_ACCESS_TOKEN" "https://www.shiftleft.io/api/v4/orgs/$SHIFTLEFT_ORG_ID/apps/$SHIFTLEFT_APP_NAME/scans/compare | jq -c -r '.response.common | .? | .[] | "* [ID " + .id + "](https://www.shiftleft.io/findingDetail/" + .app + "/" + .id + "): " + "["+.severity+"] " + .title')

echo "New findings..."
echo $NEW_FINDINGS

COMMENT_BODY=$(echo "$COMMENT_BODY" | jq ".raw += \"### New findings \n  \n \"")
COMMENT_BODY=$(echo "$COMMENT_BODY" | jq ".raw += \"$NEW_FINDINGS \n  \n \"")

echo "COMMENT_BODY: $COMMENT_BODY"
if [ -n "$BUILDRULECHECK" ]; then
    COMMENT_BODY="Build rule failed; for vulnerability list, go to $URL \n\n" 
    echo $COMMENT_BODY
    curl -XPOST "https://api.bitbucket.org/2.0/repositories/$BITBUCKET_WORKSPACE/$BITBUCKET_REPO_SLUG/pullrequests/$BITBUCKET_PR_ID/comments" \
      -u "$BITBUCKET_WORKSPACE: $APPPW2" \
      -H "Content-Type: application/json" \
      -d "{\"content\": $COMMENT_BODY}" 
    exit 1
else
    COMMENT_BODY="Build rule succeeded; for vulnerability list, go to $URL \n\n" 
    echo $COMMENT_BODY
    curl -XPOST "https://api.bitbucket.org/2.0/repositories/$BITBUCKET_WORKSPACE/$BITBUCKET_REPO_SLUG/pullrequests/$BITBUCKET_PR_ID/comments" \
      -u "$BITBUCKET_WORKSPACE:$APP_PASSWORD" \
      -H "Content-Type: application/json" \
      -d "{\"content\": $COMMENT_BODY}"  
    exit 0
fi

fi