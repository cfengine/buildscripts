# GitHub reporting script
# Args:
#   Either:
#     $1 - where to get repos and PRs info from
#     $2 - what state to report to GitHub
#     $3 - job spec (e.g. "ci/testing-pr/PACKAGES_HUB_x86_64_linux_redhat_7")
#     $4 - description of the status
#     $5 - URL to link from the status (e.g. $JOB_URL of the jenkins job)
#   Or:
#     $1 - where to get repos and PRs info from
#     $2 - path to a JSON file ready to POST to GH
# Env:
#   $GITHUB_STATUS_TOKEN - token for GitHub authentication

PRs_file="$1"
if [ -z "$PRs_file" ]; then
    exit 1
fi

if [ $# = "2" ]; then
    # just two args, check if it is a file we can read
    if [ -r "$2" ]; then
        JSON_file="$2"
    else
        "Path to a readable JSON file or status details required!"
        exit 1
    fi
else
    state="$2"
    job_spec="$3"
    description="$4"
    job_url="$5"
    if [ -z "$job_url" ]; then
        job_url="https://ci.cfengine.com/"
    fi

    if [ -z "$state" ]    ||
       [ -z "$job_spec" ] ||
       [ -z "$GITHUB_STATUS_TOKEN" ]
    then
        exit 1
    fi
fi

function set_status() {
    # Actually set status at GitHub
    # Args:
    #   $1 - statuses API URL of the PR
    # Env:
    #   $GITHUB_STATUS_TOKEN - token for GitHub authentication

    if [ -z "$1" ] || [ -z "$GITHUB_STATUS_TOKEN" ]; then return 1; fi

    if [ -n "$JSON_file" ]; then
        curl -k -X POST -H "Authorization: token $GITHUB_STATUS_TOKEN" $1 --data "@$JSON_file"
    else
        curl -k -X POST -H "Authorization: token $GITHUB_STATUS_TOKEN" $1 --data @- <<EOF
{
  "state" : "$state",
  "target_url" : "$job_url",
  "description" : "$description",
  "context" : "$job_spec"
}
EOF
    fi
    return $?
}

while read line; do
    # the PRs file has lines in the following format:
    #   REPO_IDENTIFIER PR_ID PR_STATUS_API_URL
    STATUS_URL=$(echo "$line" | awk '{ print $3 };')
    set_status $STATUS_URL
done < $PRs_file
