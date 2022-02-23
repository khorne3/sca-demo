#!/bin/sh

# Review script environment variables and set defaults
if [ ! -n "$SHIFTLEFT_APP_NAME" ]; then
  SHIFTLEFT_APP_NAME="$YOUR-APPLICATION"
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

# Analyze code
echo "Starting ShiftLeft CORE..."

sl analyze \
  --app "$SHIFTLEFT_APP_NAME" \
  --version-id "$BITBUCKET_COMMIT" \
  --tag branch="$BITBUCKET_BRANCH" \
  --force \
  --java \
  "$SHIFTLEFT_APP_PATH"

# Check if this script is running in a pull request
if [ -n "$BITBUCKET_PR_ID" ]; then
  echo "Pull request[$BITBUCKET_PR_ID] issued for branch[$BITBUCKET_BRANCH]"

  # Run build rules (sl check-analysis)
  echo "Starting ShiftLeft Check-Analysis..."
  sl check-analysis \
      --app "$SHIFTLEFT_APP_NAME" \
      --report \
      --report-file check-analysis.md \
      --source "tag.branch=master" \
      --target "tag.branch=$BITBUCKET_BRANCH"
      
  BUILDRULECHECK=$?

  # Get new findings info from the ShiftLeft API
  NEW_FINDINGS=$(curl -H "Authorization: Bearer $SHIFTLEFT_ACCESS_TOKEN" "https://www.shiftleft.io/api/v4/orgs/$SHIFTLEFT_ORG_ID/apps/$APP_NAME/scans/compare?source=tag.branch=master&target=tag.branch=$BITBUCKET_BRANCH" | jq -c -r '.response.common | .? | .[] | "* [ID " + .id + "](https://www.shiftleft.io/findingDetail/" + .app + "/" + .id + "): " + "["+.severity+"] " + .title')

  # Format comment body for the pull request
  COMMENT_BODY=$(jq -n --arg body "$CHECK_ANALYSIS_OUTPUT" '{raw: $body}')
  COMMENT_BODY=$(echo "$COMMENT_BODY" | jq ".raw += \"$NEW_FINDINGS \n  \n \"")

  echo "BUILDRULECHECK=               \"$BUILDRULECHECK\""
  echo "CHECK_ANALYSIS_OUTPUT=        \"$CHECK_ANALYSIS_OUTPUT\""
  echo "COMMENT_BODY=                 \"$COMMENT_BODY\""

  # Post report as pull request comment
  echo "Posting ShiftLeft results as a Bitbucket PR comment..."

  curl "https://api.bitbucket.org/2.0/repositories/$BITBUCKET_WORKSPACE/$BITBUCKET_REPO_SLUG/pullrequests/$BITBUCKET_PR_ID/comments" \
    --verbose \
    -u "$BITBUCKET_WORKSPACE:$APPPW2" \
    -H "Content-Type: application/json" \
    -d "{\"content\": $COMMENT_BODY}" 

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