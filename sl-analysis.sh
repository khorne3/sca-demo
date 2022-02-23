#!/bin/sh
  
echo "Got merge request $BITBUCKET_PR_ID for branch $BITBUCKET_BRANCH"

# Install NG SAST
curl https://www.shiftleft.io/download/sl-latest-linux-x64.tar.gz > /tmp/sl.tar.gz && tar -C /usr/local/bin -xzf /tmp/sl.tar.gz

APP_NAME="$BITBUCKET_REPO_SLUG-BB"
echo $APP_NAME

# Analyze your code
sl analyze --version-id "$BITBUCKET_COMMIT" --tag branch="$BITBUCKET_BRANCH" --app "$APP_NAME" --java --cpg --wait target/<path-to-your-app>.war

# Run the build rules check 
URL="https://www.shiftleft.io/findingsSummary/$APP_NAME?apps=$APP_NAME&isApp=1"
BUILDRULECHECK=$(sl check-analysis --app "$APP_NAME" --config ~/shiftleft.yml --report --report-file /tmp/check-analysis.md)

# Set up comment body for the merge request
COMMENT_BODY='{"raw":""}'
COMMENT_BODY=$(echo "$COMMENT_BODY" | jq '.raw += "## NG SAST Analysis Findings \n "')

NEW_FINDINGS=$(curl -H "Authorization: Bearer $SHIFTLEFT_ACCESS_TOKEN" "https://www.shiftleft.io/api/v4/orgs/$SHIFTLEFT_ORG_ID/apps/$APP_NAME/scans/compare?source=tag.branch=$BITBUCKET_BRANCH&target=tag.branch=$BITBUCKET_BRANCH" | jq -c -r '.response.common | .? | .[] | "* [ID " + .id + "](https://www.shiftleft.io/findingDetail/" + .app + "/" + .id + "): " + "["+.severity+"] " + .title')

echo $NEW_FINDINGS

COMMENT_BODY=$(echo "$COMMENT_BODY" | jq ".raw += \"### New findings \n  \n \"")
COMMENT_BODY=$(echo "$COMMENT_BODY" | jq ".raw += \"$NEW_FINDINGS \n  \n \"")

echo "COMMENT_BODY: $COMMENT_BODY"
if [ -n "$BUILDRULECHECK" ]; then
    PR_COMMENT="Build rule failed, click here for vulnerability list - $URL\n\n"  
    echo $PR_COMMENT
    curl -XPOST "https://api.bitbucket.org/2.0/repositories/$BITBUCKET_WORKSPACE/$BITBUCKET_REPO_SLUG/pullrequests/$BITBUCKET_PR_ID/comments" \
      -u "$BITBUCKET_WORKSPACE:$APPPW2" \
      -H "Content-Type: application/json" \
      -d "{\"content\": $COMMENT_BODY}" 
    exit 1
else
    PR_COMMENT="Build rule succeeded, click here for vulnerability list! - $URL\n\n" 
    echo $PR_COMMENT
    curl -XPOST "https://api.bitbucket.org/2.0/repositories/$BITBUCKET_WORKSPACE/$BITBUCKET_REPO_SLUG/pullrequests/$BITBUCKET_PR_ID/comments" \
      -u "$BITBUCKET_WORKSPACE:$APPPW2" \
      -H "Content-Type: application/json" \
      -d "{\"content\": $COMMENT_BODY}"  
    exit 0
fi

fi
