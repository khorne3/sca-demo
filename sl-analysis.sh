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
  echo "Pull request[$BITBUCKET_PR_ID] issued for branch[$BITBUCKET_BRANCH]"

  # Run check-analysis and save report to /tmp/check-analysis.md
  echo "Starting sl check-nnalysis..."
  sl check-analysis \
      --app "$SHIFTLEFT_APP_NAME" \
      --report \
      --report-file /tmp/check-analysis.md \
      --source "tag.branch=master" \
      --target "tag.branch=$BITBUCKET_BRANCH"
      
  BUILDRULECHECK=$?
  CHECK_ANALYSIS_OUTPUT=$(cat /tmp/check-analysis.md)
  COMMENT_BODY=$(jq -n --arg body "$CHECK_ANALYSIS_OUTPUT" '{raw: $body}')

  echo "BUILDRULECHECK=               \"$BUILDRULECHECK\""
  echo "CHECK_ANALYSIS_OUTPUT=        \"$CHECK_ANALYSIS_OUTPUT\""
  echo "COMMENT_BODY=                 \"$COMMENT_BODY\""

  # Post report as merge request comment
  echo "Posting ShiftLeft Check-Analysis Results to Bitbucket PR Comments..."

  curl "https://api.bitbucket.org/2.0/repositories/$BITBUCKET_WORKSPACE/$BITBUCKET_REPO_SLUG/pullrequests/$BITBUCKET_PR_ID/comments" \
    --verbose \
    -u "$BITBUCKET_WORKSPACE:$APPPW2" \
    -H "Content-Type: application/json" \
    -d "{\"content\": $COMMENT_BODY}" 

  echo ""

  if [ "$BUILDRULECHECK" -eq "1" ]; then
    PR_COMMENT="Build rule(s) failed..."
    echo $PR_COMMENT
    exit 1
  else
    PR_COMMENT="Build rule(s) passed..."
    echo $PR_COMMENT
    exit 0
  fi
fi