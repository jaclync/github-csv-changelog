# Installation

## Package Control (recommended)

`gem install github-csv-changelog`

## Manual installation

Clone this repository in command line:

`git clone git://github.com/jaclync/github-csv-changelog.git`

# Generating Access Token

Github API token is required to fetch commits and pull requests. To generate an access token:

## Web
* Account Settings -> [Personal access tokens](https://github.com/settings/tokens)
* "Generate new token" under "Personal access tokens"
* For "Token description" you should give it a meaningful name, Example: commit parser
* Under "Select scopes" you can pick "repo" and "user" (these two are required for commits and pull requests)

Save the token securely (e.g. 1Password) and paste the token to [`token` option](#token).

## API
Here's a command you can run from your terminal to generate a token via curl:

    curl -v -u #{USERNAME} -X POST https://api.github.com/authorizations --data "{\"scopes\":[\"repo\", \"user\"], \"note\": \"Github commit parser.\"}"

Where USERNAME is your Github username. Save the token generated securely and paste the token to [`token` option](#token).

If 2-factor is enabled on your account (strongly recommended), this will return 401 error code, use:

    curl -v -u USERNAME -H "X-GitHub-OTP: OTPCODE" -X POST https://api.github.com/authorizations --data "{\"scopes\":[\"repo\", \"user\"], \"note\": \"Github commit parser.\"}"

Where OTPCODE is the code your authenticator app shows you.

## Follow script instruction (2-factor only)

If `token` option is not specified, the script tries generating one for you, given your input on Github username, password, and the One-Time Passcode (OTP) from 2-factor.

## Saving token

There are two recommended ways to specify token:

* Save it securely (e.g. 1Password), and paste it in [`token` option](#token)
* Set token to environment variable in `COMMIT_PARSER_API_TOKEN`:
   `export COMMIT_PARSER_API_TOKEN=#{accessToken}`

# Options

*   `"--api_token" / "TOKEN"` {#token}

    You must enter your GitHub token here, or set it in environment variable under `COMMIT_PARSER_API_TOKEN`.
    If not specified, it will prompt you to generate a token for the first time.

*   `"--repo_owner" / "REPO_OWNER"`

    Repo owner where a Github repo has path `#{repo owner}/#{repo name}`

*   `"--repo" / "REPO"`

    Repo name where a Github repo has path `#{repo owner}/#{repo name}`

*   `"--export_CSV_path" / "EXPORT_CSV_PATH"`

    Path where CSV file is generated (overwritten if it existed before).

*   `"--branch_1" / "BRANCH_1"`

    The base branch where commits start.

*   `"--branch_2" / "BRANCH_2"`

    The base branch where commits end.

*   `"--pull_request_regex_by_field" / "PR_REGEX_BY_FIELD"`

    This is probably the trickiest of all options.
    Optionally, a JSON dictionary is provided here to specify how to parse a pull request description via Regex given a CSV field. This highly depends on the extra fields you could extract usually from your Github pull request template.
    Example:
    ```
    --pull_request_regex_by_field='{"What changed": "### Description of change([^?!###]+)", "Test plan": "### Test Plan([^?!###]+)" }'
    ```
    allows the script to extra two fields ("What changed" and "Test plan") from a pull request given the following pull request template ([instruction](https://help.github.com/articles/creating-a-pull-request-template-for-your-repository/) on how to create one):
    ```
    ...
    ### Description of change

    /// what changed in this pull request

    ### Test Plan

    /// how to test changes in this pull request
    ...
    ```

# Usage

`ruby github_csv_changelog.rb --apiToken=#{your access token} --repoOwner="repo owner" --repo="repo name" --exportCSVPath="./github_commits.csv" --branch1="release-3.9" --branch2="release-3.10" --pullRequestRegexByField='{"What changed": "### Description of change([^?!###]+)", "QA plan": "### Test Plan([^?!###]+)" }'`

# Future work

More error handling, e.g.:

* Invalid branch names
* Default CSV export path
* Example usage

# Information

Source: https://github.com/jaclync/github-csv-changelog
Author: [Jaclyn Chen](https://github.com/jaclync/)
