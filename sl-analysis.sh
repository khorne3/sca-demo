#!/bin/sh
  
echo "Got merge request $BITBUCKET_PR_ID for branch $BITBUCKET_BRANCH"

# Install NG SAST
curl https://www.shiftleft.io/download/sl-latest-linux-x64.tar.gz > /tmp/sl.tar.gz && tar -C /usr/local/bin -xzf /tmp/sl.tar.gz

APP_NAME="$BITBUCKET_REPO_SLUG-BB"
echo $APP_NAME

# Analyze your code
sl analyze \
--app "$APP_NAME" \
--version-id "$BITBUCKET_COMMIT" \
--tag branch="$BITBUCKET_BRANCH" \
--java \
--cpg \
--wait \
"$SHIFTLEFT_APP_PATH"

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
    -u "$BITBUCKET_WORKSPACE:$APP_PASSWORD_ALL" \
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